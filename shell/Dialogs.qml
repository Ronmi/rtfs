// 給 shell 以外的程式用的通用 UI 元件（IPC target "ui"），前端是本專案的 scripts/rtfs-ui。
// 每個請求用 spec（JSON）描述：容器（modal 或一般視窗）、標題、內文、圖示、按鈕、依序排列的 fields。
// zenity／yad／kdialog 等相容程式只負責把自己的參數翻成 spec，這裡不認得任何前端。
// 協定見 scripts/rtfs-ui 開頭的說明。
//
// modal 會整個桌面變暗、獨佔鍵盤，所以同時只顯示一個，其他的排隊；一般視窗則可以同時開好幾個。
// file（檔案選擇）見 DialogFile.qml。
// osd 交給 Osd 單例（shell 自己的音量提示等也用它），新的直接取代舊的，被取代的請求以 reason "replaced" 結束。
// 結果與中途事件先放進該請求的信箱，再用 ready signal 通知「<id> 有東西了」；前端用 qs ipc listen 收通知，
// 再呼叫 take(id, token) 取回內容。內容不走 signal：signal 會送給所有 listen 的人，輸入的密碼不能這樣廣播；
// function 的回傳值只會給呼叫的那一方。
// 但 id 是廣播出去的，所以取件還要 token：第一次 ping 時由這裡產生、用回傳值私下交給前端，
// 每次 take 都換新的。token 不能由前端提供，因為 qs ipc call 的參數別的程式能從 /proc 讀到；
// 讀到的也只會是用過的 token。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // 顯示中的請求：id → 容器物件（DialogModal／DialogWindow）。
    property var active: ({})
    // 排隊中的 modal：[{ id, spec }]
    property var modalQueue: []
    property string modalShown: ""

    readonly property var fieldTypes: [
        "entry", "number", "text", "label", "check", "list", "scale", "calendar", "color",
        "font", "progress", "image", "icons", "drop", "button"
    ]

    // 每次載入設定（啟動、重新載入）都不同；ping 回應和 reload 通知都帶著它。
    readonly property string generation: Date.now().toString(36)

    // 信箱：id → { time, token, messages: [payload...] }，由 take() 取走。
    property var outbox: ({})

    // 沒有密碼學等級的亂數可用；Math.random（QRandomGenerator）別人觀察不到輸出，足以防搶答。
    function newToken() {
        let t = "";
        for (let i = 0; i < 4; i++)
            t += Math.floor(Math.random() * 0x100000000).toString(16).padStart(8, "0");
        return t;
    }

    function send(id, payload) {
        // 沒 ping 過的 id（token 空字串）收到的東西誰都取不走，放到過期為止。
        const box = outbox[id] ?? { token: "", messages: [] };
        box.time = Date.now();
        box.messages.push(payload);
        outbox[id] = box;
        ipc.ready(id);
    }

    // 前端中途消失（被 kill -9 等）時沒人取的信箱，放久了就丟掉，免得內容（可能是密碼）一直留在記憶體裡。
    // 畫面還開著的不丟：信箱裡有它的 token，丟了前端就再也取不到結果。
    Timer {
        running: true
        repeat: true
        interval: 60000
        onTriggered: {
            const limit = Date.now() - 120000;
            for (const id in root.outbox)
                if (root.outbox[id].time < limit && !root.active[id] && Osd.owner !== id
                        && !root.modalQueue.some(r => r.id === id))
                    delete root.outbox[id];
        }
    }

    function validate(spec) {
        if (typeof spec !== "object" || spec === null || Array.isArray(spec))
            return "spec must be an object";
        if (spec.container !== undefined && !["modal", "window", "osd", "file"].includes(spec.container))
            return "unknown container: " + spec.container;
        if (spec.fields !== undefined && !Array.isArray(spec.fields))
            return "fields must be an array";
        for (const f of spec.fields ?? []) {
            if (!fieldTypes.includes(f?.type))
                return "unknown field type: " + f?.type;
            if (f.type === "list" && !Array.isArray(f.rows))
                return "list field needs rows";
        }
        return "";
    }

    function create(id, spec) {
        const comp = spec.container === "modal" ? modalComponent
            : spec.container === "file" ? fileComponent : windowComponent;
        const c = comp.createObject(root, { spec: spec });
        if (c === null) {
            send(id, { error: "failed to create dialog" });
            return;
        }
        c.finished.connect(payload => root.finish(id, payload));
        c.event.connect(payload => root.send(id, payload));
        active[id] = c;
        c.show();
    }

    function showNextModal() {
        if (modalShown !== "" || modalQueue.length === 0)
            return;
        const next = modalQueue[0];
        modalQueue = modalQueue.slice(1);
        modalShown = next.id;
        create(next.id, next.spec);
    }

    // 收掉容器；modal 的話晚一拍再開下一個，讓舊的先消失。
    function remove(id) {
        const c = active[id];
        if (!c)
            return;
        delete active[id];
        // 先標成已完成：藏起視窗會觸發 DialogWindow 的 onClosed，不能再送一次結果。
        if (c.body) {
            c.body.done = true;
            c.visible = false;
        } else {
            c.done = true; // DialogFile
        }
        c.destroy();
        if (modalShown === id) {
            modalShown = "";
            Qt.callLater(showNextModal);
        }
    }

    function finish(id, payload) {
        remove(id);
        send(id, payload);
    }

    // 要等載入完成：IpcHandler 的 signal 在載入完成後才接上（onCompleted、reloadCompleted 加
    // Qt.callLater 都還太早，listen 收不到；2026-11-06 實測 500ms 可以）。
    // 前端只在 generation 跟自己 ping 到的不同時才放棄，所以剛啟動時開的對話框不受影響。
    Timer {
        running: true
        interval: 500
        onTriggered: ipc.ready("* " + root.generation)
    }

    IpcHandler {
        id: ipc
        target: "ui"

        // 內容是「<id>」（該請求的信箱有新內容），或「* <generation>」（重新載入了設定）。
        signal ready(payload: string)

        // 取走並清空 id 的信箱：{"token": 下次用的 token, "messages": [...]}，messages 依序是
        // ping 回應、錯誤、中途事件、最終結果。token 不對時回傳 {"denied": true}。
        function take(id: string, token: string): string {
            const box = root.outbox[id];
            if (!box || box.token === "" || box.token !== token)
                return JSON.stringify({ denied: true });
            const messages = box.messages;
            box.messages = [];
            box.token = root.newToken();
            box.time = Date.now();
            return JSON.stringify({ token: box.token, messages: messages });
        }

        // 前端先開 qs ipc listen，再呼叫 ping 確認 listen 已經在收，才送出 open（避免漏掉結果）。
        // 第一次 ping 這個 id 時回傳取件用的 token；之後（重試、或別人拿廣播的 id 來 ping）回傳空字串。
        function ping(id: string): string {
            let token = "";
            if (!root.outbox[id]) {
                token = root.newToken();
                root.outbox[id] = { time: Date.now(), token: token, messages: [] };
            }
            root.send(id, { ping: true, generation: root.generation });
            return token;
        }
        function open(id: string, spec: string): void {
            let parsed;
            try {
                parsed = JSON.parse(spec);
            } catch (e) {
                root.send(id, { error: "invalid spec JSON: " + e.message });
                return;
            }
            const err = root.validate(parsed);
            if (err !== "") {
                root.send(id, { error: err });
                return;
            }
            if (parsed.container === "osd") {
                Osd.show(parsed, id);
            } else if (parsed.container === "modal") {
                root.modalQueue = root.modalQueue.concat([{ id: id, spec: parsed }]);
                root.showNextModal();
            } else {
                root.create(id, parsed);
            }
        }
        // 修改顯示中的對話框（進度、追加文字、換按鈕等）；格式見 DialogBody.applyPatch。
        // 還在排隊的 modal 不處理：它還沒有 field 物件可以合併。
        function update(id: string, patch: string): void {
            const c = root.active[id];
            if (!c && Osd.owner !== id)
                return;
            try {
                if (c)
                    c.body.applyPatch(JSON.parse(patch));
                else
                    Osd.update(id, JSON.parse(patch));
            } catch (e) {
                // 不是致命錯誤：對話框還在，前端印出警告就好。
                root.send(id, { warning: "invalid patch: " + e.message });
            }
        }
        // 前端要求關閉（被中斷、或 progress 的 auto-close 等）；不送結果。
        function close(id: string): void {
            if (root.active[id])
                root.remove(id);
            else if (Osd.owner === id)
                Osd.hide(id);
            else
                root.modalQueue = root.modalQueue.filter(r => r.id !== id);
        }
    }

    Connections {
        target: Osd
        function onEnded(owner, reason) {
            root.send(owner, { button: null, reason: reason, values: {} });
        }
    }

    Component {
        id: modalComponent
        DialogModal {}
    }
    Component {
        id: windowComponent
        DialogWindow {}
    }
    Component {
        id: fileComponent
        DialogFile {}
    }
}
