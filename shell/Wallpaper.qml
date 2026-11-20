// 桌布輪換（取代 swaybg＋niri 專案 scripts/wallpaper 的 daemon）：決定每個螢幕現在顯示哪張圖。
// 畫圖的是 WallpaperWindow（每個螢幕一個）；設定在 Config.appearance.wallpaper。沒設定圖片目錄時沒有圖，只有官方漸層色背景。
// IPC：qs ipc call wallpaper next|pause|resume|status（niri 專案的 wp 腳本呼叫這裡）。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var cfg: Config.appearance.wallpaper
    readonly property var dirs: cfg.dirs.map(d => String(d).replace(/^~(?=\/|$)/, Quickshell.env("HOME")))
    readonly property string order: oneOf(cfg.order, ["shuffle", "sequential"], "order")
    readonly property bool sameOnAll: oneOf(cfg.perOutput, ["different", "same"], "perOutput") === "same"
    readonly property int fillMode: ({
            crop: Image.PreserveAspectCrop,
            fit: Image.PreserveAspectFit,
            stretch: Image.Stretch
        })[oneOf(cfg.fill, ["crop", "fit", "stretch"], "fill")]
    readonly property string transition: oneOf(cfg.transition.type, ["fade", "slide", "wipe", "random", "none"],
        "transition.type")
    readonly property int duration: Math.max(0, cfg.transition.duration)

    // 螢幕名稱（connector，例如 eDP-1）→ 圖檔路徑。鎖定畫面也可以從這裡拿目前的圖。
    readonly property var images: JSON.parse(persist.images)
    readonly property bool paused: persist.paused
    // 有設定圖片目錄（主選單的桌布方塊只在這時出現）。
    readonly property bool available: dirs.length > 0

    // 熱重載時保留目前的圖、佇列和暫停狀態，不然每次存 QML 檔桌布就換一次。登出就清掉（跟原本的腳本一樣）。
    // 物件和陣列存成 JSON 字串：var 屬性裡的 JS 物件屬於舊的 QML 引擎，重載後會變成 undefined。
    PersistentProperties {
        id: persist
        reloadableId: "wallpaper"

        property string images: "{}"
        property string queue: "[]"
        property bool paused: false
        // 圖片來源（目錄＋順序）；跟目前設定不同就重新掃描並立刻換圖。
        property string sourceKey: ""
    }

    // 目錄裡所有圖（掃描結果）；佇列用完時從這裡重新排一輪。
    property var pool: []
    property bool scanned: false
    // 掃描完成前就要換圖（剛啟動、改了目錄）時先記著。
    property bool changePending: false

    readonly property string sourceKey: JSON.stringify([dirs, order])
    onSourceKeyChanged: sourceChanged()
    readonly property bool configReady: Config.ready
    onConfigReadyChanged: sourceChanged()

    function sourceChanged() {
        if (!Config.ready)
            return;
        const changed = persist.sourceKey !== sourceKey;
        persist.sourceKey = sourceKey;
        if (changed) {
            persist.queue = "[]";
            changePending = true;
        }
        // 沒有目錄時不掃描（find 沒給路徑會掃目前目錄），清掉舊圖讓背景露出來。
        if (dirs.length === 0) {
            pool = [];
            scanned = true;
            changePending = false;
            persist.images = "{}";
            return;
        }
        scan();
    }

    function oneOf(value, allowed, name) {
        if (allowed.includes(value))
            return value;
        console.warn("Wallpaper: wallpaper." + name + " must be one of", allowed.join("/") + "; got", value);
        return allowed[0];
    }

    Process {
        id: scanner
        // 跟原本的腳本一樣只看第一層；檔名有換行的圖會被拆壞，不處理。
        command: ["find", ...root.dirs, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname",
            "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.pool = text.split("\n").filter(l => l !== "").sort();
                root.scanned = true;
                if (root.pool.length === 0)
                    Config.notify(I18n.tr("桌布目錄裡沒有圖：%1", root.dirs.join(I18n.tr("、"))));
                if (root.changePending)
                    root.change();
                else
                    root.fillMissing();
            }
        }
    }

    function scan() {
        if (dirs.length > 0 && !scanner.running)
            scanner.running = true;
    }

    // 從佇列取下一張；佇列空了就從 pool 重新排一輪，並重新掃描（新加的圖下一輪出現）。
    function take() {
        let q = JSON.parse(persist.queue);
        if (q.length === 0) {
            q = pool.slice();
            if (order === "shuffle")
                for (let i = q.length - 1; i > 0; i--) {
                    const j = Math.floor(Math.random() * (i + 1));
                    [q[i], q[j]] = [q[j], q[i]];
                }
            scan();
        }
        const img = q.shift() ?? "";
        persist.queue = JSON.stringify(q);
        return img;
    }

    // 所有螢幕都換一張。
    function change() {
        if (!scanned || pool.length === 0) {
            changePending = true;
            return;
        }
        changePending = false;
        const imgs = {};
        const shared = sameOnAll ? take() : "";
        for (const s of Quickshell.screens)
            imgs[s.name] = sameOnAll ? shared : take();
        persist.images = JSON.stringify(imgs);
    }

    // 新接上的螢幕（或剛啟動）還沒有圖的補一張，其他螢幕不動。
    function fillMissing() {
        if (pool.length === 0)
            return;
        const imgs = JSON.parse(persist.images);
        const first = Object.values(imgs)[0];
        let added = false;
        for (const s of Quickshell.screens)
            if (!imgs[s.name]) {
                imgs[s.name] = sameOnAll && first ? first : take();
                added = true;
            }
        if (added)
            persist.images = JSON.stringify(imgs);
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.fillMissing();
        }
    }

    Timer {
        id: timer
        interval: Math.max(10, root.cfg.interval) * 1000
        repeat: true
        running: root.cfg.rotate && !root.paused && Config.ready
        onTriggered: root.change()
    }

    // 立刻換圖，計時從頭開始；暫停中也可以用（跟原本的腳本一樣）。
    function next() {
        change();
        // restart() 會讓停著的計時器也開始跑，所以只在跑著時重設。
        if (timer.running)
            timer.restart();
    }
    function setPaused(value) {
        persist.paused = value;
    }

    IpcHandler {
        target: "wallpaper"

        function next(): void {
            root.next();
        }
        function pause(): void {
            root.setPaused(true);
        }
        function resume(): void {
            root.setPaused(false);
        }
        function status(): string {
            return JSON.stringify({
                rotate: root.cfg.rotate,
                paused: root.paused,
                images: root.images
            });
        }
    }
}
