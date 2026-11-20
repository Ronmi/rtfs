// modal 遮罩右下角的螢幕鍵盤開關：遮罩蓋住了狀態列上的按鈕，所以另放一顆（osk.modalButton 決定何時出現）。
// 放角落而不是卡片下方：平板模式雙手端著時拇指只碰得到邊緣；右邊離 Enter、方向鍵近。
// 沒有「只在觸控螢幕上」：niri IPC 查不到觸控裝置對應哪個螢幕，用螢幕名稱猜遇到外接觸控螢幕就會錯。
import QtQuick
import Quickshell

Rectangle {
    id: root

    // 鍵盤開著沒有、按了做什麼。預設是一般的螢幕鍵盤；鎖定畫面有自己的鍵盤（見 LockContent）。
    property bool active: Osk.shown
    property var action: () => Osk.toggle()

    visible: {
        switch (Config.osk.modalButton) {
        case "always": return true;
        case "tablet": return ShellState.tabletMode;
        default: return false;
        }
    }
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 24
    width: 56
    height: 40
    radius: 10
    // 鍵盤開著時用強調色，看得出按了會關掉。
    readonly property color fill: active ? Theme.dialogDark.accent : Theme.dialogDark.surface
    color: area.containsMouse ? Qt.lighter(fill, 1.15) : fill

    Text {
        anchors.centerIn: parent
        text: "" // keyboard-o
        color: root.active ? Theme.dialogDark.accentFg : Theme.dialogDark.fg
        font.family: "FontAwesome"
        font.pixelSize: Theme.fontPx(18)
    }
    // 也吃掉點擊，免得穿透到遮罩被當成取消。
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.action()
    }
}
