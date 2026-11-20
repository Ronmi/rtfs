// 使用者設定：~/.config/rtfs/config.yaml（每台機器各自一份，不在專案裡；範例見專案的 config.example.yaml）。
// QuickShell 只會讀 JSON，所以用 python3-yaml 轉成 JSON 再讀。存檔後立即重讀。
// 每一項都有預設值：檔案不存在、YAML 寫錯、某一項型別不對時，用預設值並發通知，shell 照常運作。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "ConfigSchema.js" as ConfigSchema

Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
        + "/rtfs/config.yaml"

    // 有哪些設定、型別、預設值都在 ConfigSchema.js（設定視窗也用它）。標籤與說明在這裡換成介面語言。
    readonly property var schema: translated(ConfigSchema.schema)
    readonly property var defaults: defaultsOf(schema)

    // 合併後的設定；讀完第一次之前是預設值。
    property var data: defaults
    readonly property var appearance: data.appearance
    readonly property var bar: data.bar
    readonly property var notifications: data.notifications
    readonly property var lock: data.lock
    readonly property var launcher: data.launcher
    readonly property var osk: data.osk
    readonly property var user: data.user
    // 第一次讀取（含檔案不存在）完成了沒；桌布等這個再決定要不要換圖，避免先用預設值換一次。
    property bool ready: false

    FileView {
        id: file
        path: root.path
        watchChanges: true
        // 檔案不存在是正常情況（全部用預設值）。
        printErrors: false
        onFileChanged: reload()
        onLoaded: parser.parse()
        onLoadFailed: {
            root.data = root.defaults;
            root.ready = true;
        }
    }

    Process {
        id: parser

        property bool again: false

        function parse() {
            if (running)
                again = true;
            else
                running = true;
        }

        command: ["python3", "-c", `
import json, sys, yaml
try:
    with open(sys.argv[1]) as f:
        d = yaml.safe_load(f)
    print(json.dumps({"ok": True, "data": d}, default=str))
except Exception as e:
    print(json.dumps({"ok": False, "error": str(e)}))
`, root.path]
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
        onExited: if (again) {
            again = false;
            running = true;
        }
    }

    function apply(text) {
        let r;
        try {
            r = JSON.parse(text);
        } catch (e) {
            r = {
                ok: false,
                error: I18n.tr("無法解析轉換結果")
            };
        }
        if (!r.ok) {
            // 寫到一半存檔很常見，保留上一次的設定比退回預設值好。
            notify(I18n.tr("設定檔格式錯誤，沿用目前的設定：%1", r.error));
            ready = true;
            return;
        }
        const problems = [];
        data = merge(schema, r.data ?? {}, "", problems);
        if (problems.length > 0)
            notify(I18n.tr("設定檔有問題，這些項目用預設值：\n%1", problems.join("\n")));
        ready = true;
    }

    function translated(nodes) {
        const out = {};
        for (const k in nodes) {
            const n = Object.assign({}, nodes[k]);
            if (n.label)
                n.label = I18n.tr(n.label);
            if (n.desc)
                n.desc = I18n.tr(n.desc);
            if (n.choices)
                n.choices = n.choices.map(c => Object.assign({}, c, { label: I18n.tr(c.label) }));
            if (n.items)
                n.items = translated(n.items);
            out[k] = n;
        }
        return out;
    }

    function defaultsOf(nodes) {
        const out = {};
        for (const k in nodes)
            out[k] = nodes[k].items ? defaultsOf(nodes[k].items) : nodes[k].default;
        return out;
    }

    // 依 schema 檢查一個設定項，不合格時回傳原因。
    function invalid(item, u) {
        switch (item.type) {
        case "bool":
            return typeof u === "boolean" ? "" : I18n.tr("應該是 true 或 false");
        case "int":
        case "number":
            if (typeof u !== "number" || (item.type === "int" && !Number.isInteger(u)))
                return item.type === "int" ? I18n.tr("應該是整數") : I18n.tr("應該是數字");
            if ((item.min !== undefined && u < item.min) || (item.max !== undefined && u > item.max))
                return I18n.tr("應該在 %1～%2 之間", item.min, item.max);
            return "";
        case "enum":
            return item.choices.some(c => c.value === u) ? ""
                : I18n.tr("應該是 %1 其中之一", item.choices.map(c => c.value).join(I18n.tr("／")));
        case "list":
            return Array.isArray(u) && u.every(x => typeof x === "string") ? "" : I18n.tr("應該是文字清單");
        default: // string、output
            return typeof u === "string" ? "" : I18n.tr("應該是文字");
        }
    }

    // 以 schema 為準逐項合併：分組往下遞迴，設定項不合格或不認得的鍵記進 problems。
    function merge(nodes, user, prefix, problems) {
        if (typeof user !== "object" || user === null || Array.isArray(user)) {
            problems.push(I18n.tr("%1：應該是一組設定", prefix || I18n.tr("（整個檔案）")));
            return defaultsOf(nodes);
        }
        const out = {};
        for (const k in nodes) {
            const name = prefix ? prefix + "." + k : k;
            const node = nodes[k];
            const u = user[k];
            if (u === undefined || u === null)
                out[k] = node.items ? defaultsOf(node.items) : node.default;
            else if (node.items)
                out[k] = merge(node.items, u, name, problems);
            else {
                const why = invalid(node, u);
                out[k] = why ? (problems.push(I18n.tr("%1：%2", name, why)), node.default) : u;
            }
        }
        for (const k in user)
            if (!(k in nodes))
                problems.push(I18n.tr("%1：不認得的設定", prefix ? prefix + "." + k : k));
        return out;
    }

    // 設定視窗存檔：只寫跟預設值不同的項目（沒寫的就是預設值），原本的註解不保留。
    // 寫完後照平常的流程重讀。
    function save(values) {
        writer.payload = JSON.stringify(diff(defaults, values) ?? {});
        writer.running = true;
    }
    function diff(def, val) {
        if (typeof def === "object" && def !== null && !Array.isArray(def)) {
            const out = {};
            for (const k in def) {
                const d = diff(def[k], val[k]);
                if (d !== undefined)
                    out[k] = d;
            }
            return Object.keys(out).length > 0 ? out : undefined;
        }
        return JSON.stringify(def) === JSON.stringify(val) ? undefined : val;
    }

    Process {
        id: writer

        property string payload: ""

        // 寫完就關掉 stdin，python 才讀得到結尾；下次存檔前再打開。
        stdinEnabled: true
        onStarted: {
            write(payload);
            stdinEnabled = false;
        }
        // 檔案原本不存在時 FileView 沒在監看，所以寫完一律主動重讀（有在監看時多讀一次也無妨）。
        onExited: {
            stdinEnabled = true;
            file.reload();
        }
        command: ["python3", "-c", `
import json, os, sys, yaml
d = json.load(sys.stdin)
path = sys.argv[1]
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path + ".tmp", "w") as f:
    f.write("# " + sys.argv[2] + "\\n")
    if d:
        yaml.safe_dump(d, f, allow_unicode=True, sort_keys=False)
os.replace(path + ".tmp", path)
`, root.path, I18n.tr("由 rtfs 設定視窗寫入。沒寫的項目用預設值；所有項目與說明見專案的 config.example.yaml。")]
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                root.notify(I18n.tr("無法寫入設定檔：%1", text.trim()))
        }
    }

    // shell 自己就是通知服務，透過 D-Bus 送給自己，跟其他程式的通知走同一條路。
    function notify(message) {
        console.warn("Config:", message);
        notifier.command = ["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.Notify", "--",
            "rtfs", "0", "preferences-system", I18n.tr("rtfs 設定"), message, "[]", "{}", "-1"];
        notifier.running = true;
    }

    Process {
        id: notifier
    }
}
