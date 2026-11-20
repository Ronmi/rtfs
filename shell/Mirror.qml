// 螢幕鏡像（簡報投影用）：把筆電內建螢幕的畫面全螢幕顯示在外接螢幕上。
// niri 26.04 沒有內建鏡像，跟 niri 專案的 scripts/mirror-toggle 一樣交給 wl-mirror。
// 狀態看 niri 的視窗清單裡有沒有 wl-mirror 的視窗，所以用 mirror-toggle 開的也算；
// wl-mirror 是分離執行的，qs 重新載入不會中斷鏡像。
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string appId: "at.yrlf.wl_mirror"

    // 內建面板（eDP／LVDS／DSI 開頭）；桌機沒有內建面板就不提供鏡像。
    readonly property var source: Quickshell.screens.find(s => /^(eDP|LVDS|DSI)-/.test(s.name)) ?? null
    readonly property var targets: source ? Quickshell.screens.filter(s => s !== source) : []
    readonly property bool available: targets.length > 0
    readonly property bool active: Niri.windows.some(w => w.app_id === appId)

    function start(target) {
        if (!source || active)
            return;
        Quickshell.execDetached(["wl-mirror", "--fullscreen-output", target.name, source.name]);
    }

    function stop() {
        Quickshell.execDetached(["pkill", "-x", "wl-mirror"]);
    }

    // 螢幕的顯示名稱：型號（讀不到時用接頭名稱）。
    function label(screen) {
        return screen.model ? I18n.tr("%1（%2）", screen.model, screen.name) : screen.name;
    }
}
