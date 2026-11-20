// 對話框按鈕（所有對話框共用，改外觀只改這裡）。
// fill／textColor 決定注意力等級：一般用 panelRaised，確認用娜璉色，危險動作用彩瑛紅。
// isDefault：按 Enter 會觸發的按鈕，畫一圈外框提示。
import QtQuick

Rectangle {
    id: root

    // 配色（Theme.dialogDark／dialogLight），由使用的地方傳入；預設深色。
    property var theme: Theme.dialogDark

    property alias text: label.text
    property color fill: theme.surface
    property color textColor: theme.fg
    property bool isDefault: false
    signal clicked

    implicitWidth: Math.max(96, label.implicitWidth + 32)
    implicitHeight: 40
    radius: 10
    color: area.containsMouse ? Qt.lighter(fill, 1.15) : fill
    border.width: isDefault ? 2 : 0
    border.color: theme.fg

    Text {
        id: label
        anchors.centerIn: parent
        color: root.textColor
        font.family: Theme.uiFontFamily
        font.pixelSize: Theme.fontPx(15)
        font.bold: true
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
