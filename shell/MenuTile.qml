// 開關方塊（GNOME 快速設定那種）：開著時用強調色；寬度由使用的地方給（通常是選單一半寬）。
// 給了 action（圖示）時右邊多一顆單次動作的按鈕（actionClicked），跟開關本身分開。
// toggleEnabled 為 false 時開關變暗、不能按，右邊按鈕照常可用。
import QtQuick

Rectangle {
    id: tile
    property string icon
    property string label
    property bool checked: false
    property string action
    property bool toggleEnabled: true
    signal clicked
    signal actionClicked

    height: 44
    radius: 22
    color: checked ? (tileArea.containsMouse ? Qt.lighter(Colors.accent, 1.1) : Colors.accent)
         : tileArea.containsMouse ? Qt.lighter(Colors.panelRaised, 1.4) : Colors.panelRaised

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        opacity: tile.toggleEnabled ? 1 : 0.5
        MenuIcon {
            text: tile.icon
            color: tile.checked ? Colors.accentFg : Colors.shellFg
        }
        MenuLabel {
            text: tile.label
            color: tile.checked ? Colors.accentFg : Colors.shellFg
            font.bold: tile.checked
        }
    }
    MouseArea {
        id: tileArea
        anchors.left: parent.left
        anchors.right: actionButton.visible ? actionButton.left : parent.right
        height: parent.height
        enabled: tile.toggleEnabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }

    // 右邊的動作按鈕：用一條細線跟開關隔開，hover 時只亮這一半。
    Rectangle {
        id: actionButton
        visible: tile.action !== ""
        anchors.right: parent.right
        width: 44
        height: parent.height
        radius: tile.radius
        color: actionArea.containsMouse ? Qt.lighter(tile.color, 1.2) : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: parent.height - 16
            color: tile.checked ? Colors.accentFg : Colors.shellDim
            opacity: 0.4
        }
        MenuIcon {
            anchors.centerIn: parent
            text: tile.action
            color: tile.checked ? Colors.accentFg : Colors.shellFg
        }
        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.actionClicked()
        }
    }
}
