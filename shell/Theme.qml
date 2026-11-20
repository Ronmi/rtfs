// 手寫的共用樣式（字型、色塊外觀、bar 位置；可調的部份來自 Config）。顏色不在這裡，見 Colors.qml（由 theme-gen 產生）。
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // bar 的位置；漸層線、面板展開方向都跟著它。
    readonly property bool barAtBottom: Config.bar.position === "bottom"
    readonly property int barHeight: 40
    // bar 所在螢幕太窄（內建螢幕轉直是 960）時色塊省略次要內容：SSID、年份、網速與溫度的圖示。
    // 看寬度而不是平板模式：橫拿的平板塞得下，窄的外接螢幕也要省。
    readonly property bool barCompact: (ShellState.barScreen?.width ?? 0) < 1200

    // 預設是通用名稱 sans-serif，由 fontconfig 挑系統裡有的字型，不必相依特定字型套件。
    // 指定字型時用英文名稱，避免 CJK 字型名稱在某些環境下比對失敗。
    // bar 色塊上的文字（作者自己用芫荽：在 bar 上好看，但當一般介面文字不好讀）。
    readonly property string barFontFamily: Config.appearance.fonts.barFamily
    // 一般介面文字（tooltip、面板、選單、對話框）。
    readonly property string uiFontFamily: Config.appearance.fonts.uiFamily

    // 介面文字的大小：元件裡寫的是預設字級 14 時的 px，依設定的字級等比例縮放。
    function fontPx(px) {
        return Math.round(px * Config.appearance.fonts.uiSize / 14);
    }

    // 對話框元件（Dialog*.qml、Field*.qml）的配色。元件只認這些角色，由容器決定用哪一組：
    // shell 的一部份（modal、確認、polkit）用深色；一般視窗（rtfs-ui 的 window）跟其他程式一樣用淺色
    // （TWICE 配色原則：程式淺色、shell 深色）。
    //   bg 底色、surface 輸入框／按鈕／hover、track 進度條等的軌道、fg 文字、dim 次要文字、line 淺色時的框線、
    //   accent／accentFg 選取與確認按鈕、danger／dangerFg 危險動作、info／warn／err 訊息圖示（畫在 bg 上的前景色）
    readonly property var dialogDark: ({
        bg: Colors.panelBg,
        surface: Colors.panelRaised,
        track: Qt.lighter(Colors.panelRaised, 1.5),
        fg: Colors.shellFg,
        dim: Colors.shellDim,
        line: "transparent",
        accent: Colors.accent,
        accentFg: Colors.accentFg,
        danger: Colors.chaeyoung,
        dangerFg: Colors.inkLight,
        info: Colors.accent,
        warn: Colors.warn,
        err: Colors.err
    })
    // 淺色時成員色當前景對比不夠，圖示改用 *Text 的深色版本。
    readonly property var dialogLight: ({
        bg: Colors.bg,
        surface: Colors.button,
        track: Colors.line,
        fg: Colors.fg,
        dim: Colors.dim,
        line: Colors.line,
        accent: Colors.accent,
        accentFg: Colors.accentFg,
        danger: Colors.chaeyoung,
        dangerFg: Colors.inkLight,
        info: Colors.accentText,
        warn: Colors.warnText,
        err: Colors.errText
    })

    // 標準訊息圖示（FontAwesome），對話框與 OSD 共用；顏色由各自決定。
    readonly property var iconGlyphs: ({
        info: "\uf05a",
        question: "\uf059",
        warning: "\uf071",
        error: "\uf057"
    })

    // OSD（Osd.qml）的配色：半透明官方漸層（左桃右粉，水平），刻意跟通知卡片（不透明成員色）、面板（深藍）不同。
    // 半透明時背後是什麼無法預測，沒有一種前景色在所有背景上都有 4.5 的對比；
    // 背後多半是淺色的程式，所以用深色字（漸層兩端都是深色字較好）。2026-11-07 使用者試過娜璉色 0.5→0.7，再換成漸層。
    // 不透明度由使用者實際看過後決定：桃色端 0.7（深色字在任何背景上 ≥ 5.15），較暗的粉紅端 0.8
    // （疊在白色上 6.8、深色上 3.7–4.2）。不透明時兩端都 ≥ 5.57。
    readonly property var osd: ({
        bgFrom: Qt.rgba(Colors.officialFrom.r, Colors.officialFrom.g, Colors.officialFrom.b, 0.7),
        bgTo: Qt.rgba(Colors.officialTo.r, Colors.officialTo.g, Colors.officialTo.b, 0.8),
        fg: Colors.inkDark,
        track: Qt.rgba(Colors.inkDark.r, Colors.inkDark.g, Colors.inkDark.b, 0.25)
    })

    // bar 上每個色塊共用的外觀。
    readonly property int blockHeight: 24
    readonly property int blockRadius: 8
    readonly property int blockPadding: 10
    readonly property font blockFont: Qt.font({
        family: barFontFamily,
        pixelSize: Config.appearance.fonts.barSize,
        bold: true
    })
}
