// 狀態列的螢幕鍵盤按鈕（MOMO 色底）：切換 shell 自己的螢幕鍵盤（Osk.qml）。
import QtQuick
import Quickshell

Rectangle {
    id: root

    implicitWidth: icon.implicitWidth + 2 * Theme.blockPadding
    implicitHeight: Theme.blockHeight
    radius: Theme.blockRadius
    color: Colors.momo

    Text {
        id: icon
        anchors.centerIn: parent
        text: "" // keyboard-o
        color: Colors.inkDark
        font.family: "FontAwesome"
        font.pixelSize: Theme.blockFont.pixelSize
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Osk.toggle()
    }

    Tooltip {
        anchorItem: root
        shown: hover.containsMouse

        Text {
            text: I18n.tr("螢幕鍵盤")
            color: Colors.shellFg
            font.family: Theme.uiFontFamily
            font.pixelSize: Theme.fontPx(14)
        }
    }
}
