// 螢幕鍵盤的狀態與送鍵（畫面在 OskWindow.qml）。IPC target osk：toggle/open/close。
// 按鍵經由 scripts/rtfs-vkbd（virtual-keyboard 協定）送出；它只在鍵盤顯示時執行，
// 收起時結束，compositor 會自動放開還按著的鍵，不會留下卡住的 Ctrl。
//
// 修飾鍵（送出「按下」後保持，狀態記在 mods）：
//   點一下：黏滯（latched），下一個一般鍵放開後一起放開；
//   點兩下（doubleTapMs 內）：鎖定（locked，鍵上亮小燈），再點一次才放開；
//   按住不放同時打其他鍵：真的長按（held），手指離開就放開。
// 送的都是真的按鍵事件，所以 niri 快捷鍵與 fcitx5（Ctrl+Space 切輸入法）都看得到。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool shown: false
    // 半透明模式（鍵盤蓋住不會縮的東西時，例如固定高度的 kitty quick-access-terminal，可以看到下面）。
    property bool translucent: false
    // 顯示在螢幕頂部。預設浮在上面不佔保留區（見 OskWindow），所以順便打開半透明，可以再用按鍵關掉。
    property bool atTop: false
    // 開著的 modal 對話框數（DialogFrame 維護）。遮罩會蓋住 OskWindow，所以這時改由對話框自己畫鍵盤。
    property int modals: 0
    onAtTopChanged: if (atTop && !Config.osk.topReserve && Config.osk.topTranslucent) translucent = true
    // 按著的修飾鍵：keycode → { state: "held" | "latched" | "locked", used, at }。
    // 每次改變都換一個新物件，畫面的綁定才會更新。
    property var mods: ({})
    readonly property int doubleTapMs: 400

    function toggle() {
        shown = !shown;
    }

    onShownChanged: {
        mods = {};
        helper.running = shown;
    }

    function send(action, code) {
        if (helper.running)
            helper.write(action + " " + code + "\n");
    }

    function updateMods(change) {
        const next = Object.assign({}, mods);
        change(next);
        mods = next;
    }

    // 一般鍵：按下就送，手指放開才放開（長按的重複由程式自己處理）。
    function pressKey(code) {
        send("press", code);
        // 修飾鍵按著時打了別的鍵：這次是真的長按，放開修飾鍵時不要變成黏滯。
        updateMods(m => {
            for (const c in m)
                if (m[c].state === "held")
                    m[c] = Object.assign({}, m[c], { used: true });
        });
    }
    function releaseKey(code) {
        send("release", code);
        updateMods(m => {
            for (const c in m)
                if (m[c].state === "latched") {
                    send("release", c);
                    delete m[c];
                }
        });
    }

    function modifierDown(code) {
        updateMods(m => {
            const s = m[code];
            if (!s) {
                send("press", code);
                m[code] = { state: "held", used: false };
            } else if (s.state === "latched" && Date.now() - s.at < doubleTapMs) {
                m[code] = { state: "locked" };
            } else {
                send("release", code);
                delete m[code];
            }
        });
    }
    function modifierUp(code) {
        updateMods(m => {
            const s = m[code];
            if (!s || s.state !== "held")
                return;
            if (s.used) {
                send("release", code);
                delete m[code];
            } else {
                m[code] = { state: "latched", at: Date.now() };
            }
        });
    }

    Process {
        id: helper
        command: [Quickshell.shellDir + "/../scripts/rtfs-vkbd"]
        stdinEnabled: true
        stderr: SplitParser {
            onRead: line => console.warn("Osk:", line)
        }
        onExited: code => {
            if (root.shown) {
                console.warn("Osk: rtfs-vkbd exited with", code);
                root.shown = false;
            }
        }
    }

    IpcHandler {
        target: "osk"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.shown = true;
        }
        function close(): void {
            root.shown = false;
        }
    }
}
