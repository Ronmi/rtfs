// 整個 shell 共用的狀態：平板模式（FW12 反折後鍵盤、觸控板會停用）、狀態列所在的螢幕。
// 平板模式由 niri 的 switch-events 通知：先把狀態寫進 $XDG_RUNTIME_DIR/rtfs-tablet-mode，
// 再呼叫 qs ipc call shell setTabletMode true|false。
// 寫檔是為了 qs 晚於 niri 啟動或 qs 重啟時，也能從檔案得知目前狀態（niri 開機時的事件可能早於 qs）。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool tabletMode: false

    // 螢幕被 AutoLock 關掉了（鎖定中閒置），有輸入時 niri 會自己打開。
    // 用來暫停螢幕關著時沒意義的輪詢（例如 Privacy 讀 EC）。
    property bool screensOff: false

    // 狀態列所在的螢幕（bar.output）：通知、平板模式按鈕也放這裡，OSD、對話框找不到聚焦螢幕時也用它。
    // 沒設定或設定的螢幕沒接上時用第一個螢幕，不然桌機（沒有 eDP-1）上就沒有狀態列。
    readonly property ShellScreen barScreen: Quickshell.screens.find(s => s.name === Config.bar.output)
        ?? Quickshell.screens[0] ?? null

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/rtfs-tablet-mode"
        // 沒反折過時檔案不存在，是正常情況。
        printErrors: false
        onLoaded: root.tabletMode = text().trim() === "1"
    }

    IpcHandler {
        target: "shell"

        function setTabletMode(on: bool): void {
            root.tabletMode = on;
        }
        function getTabletMode(): bool {
            return root.tabletMode;
        }
    }
}
