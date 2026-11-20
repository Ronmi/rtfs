// niri overview 開著時蓋在 bar 時鐘位置的「所有程式」按鈕：點了在同一個螢幕開 launcher。
// 平板模式（FW12 反折）鍵盤、觸控板都停用，這是不用 Mod+D 也能開 launcher 的觸控入口；
// 什麼時候出現由設定 launcher.overviewButton 決定。
// overview 期間 bar 仍顯示在最上面，所以直接蓋在置中的時鐘位置；尺寸固定、比時鐘稍大，不用跟著時鐘寬度計算。
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    // 每個螢幕一個（shell.qml 的 Variants），都在同一個位置。
    required property ShellScreen modelData
    screen: modelData
    // launcher.overviewButton：never 不顯示、tablet 只在平板模式、always 一律顯示（都要 overview 開著）。
    visible: Niri.overviewOpen
             && (Config.launcher.overviewButton === "always"
                 || (Config.launcher.overviewButton === "tablet" && ShellState.tabletMode))

    // 只錨定 bar 所在的那一邊：layer-shell 會把它水平置中，剛好對齊置中的時鐘。
    anchors.top: !Theme.barAtBottom
    anchors.bottom: Theme.barAtBottom
    // 不理會 bar 的保留區，直接貼齊螢幕邊緣蓋住時鐘；與 bar 一樣扣掉 2px 漸層線後垂直置中。
    // 漸層線在 bar 靠螢幕內側那邊，所以上下兩種位置離螢幕邊緣的距離相同。
    exclusionMode: ExclusionMode.Ignore
    margins.top: (Theme.barHeight - 2 - implicitHeight) / 2
    margins.bottom: (Theme.barHeight - 2 - implicitHeight) / 2
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "rtfs-overview-button"

    implicitWidth: 260
    implicitHeight: 34
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 12
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Colors.officialFrom }
            GradientStop { position: 1; color: Colors.officialTo }
        }
        // 按下時稍微變暗，觸控時看得出有按到。
        opacity: area.pressed ? 0.8 : 1

        Row {
            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "" // th（格狀）
                color: Colors.inkDark
                font.family: "FontAwesome"
                font.pixelSize: Theme.fontPx(18)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("所有程式")
                color: Colors.inkDark
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(17)
                font.bold: true
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            onClicked: Launcher.open(root.modelData)
        }
    }
}
