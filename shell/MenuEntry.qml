// 選單清單的一列：圖示＋文字（＋可選的右側圖示 trailing），hover 時加底色。
import QtQuick

Rectangle {
    id: entry
    property string icon
    property string label
    property string trailing
    property real leftPadding: 0
    property color hoverColor: Colors.panelRaised
    signal clicked

    height: 36
    radius: 8
    color: entryArea.containsMouse ? hoverColor : "transparent"

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12 + entry.leftPadding
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        MenuIcon {
            width: 20
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            text: entry.icon
        }
        MenuLabel {
            width: parent.width - 20 - parent.spacing - (entry.trailing ? 20 + parent.spacing : 0)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: entry.label
        }
        MenuIcon {
            visible: entry.trailing !== ""
            width: 20
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            text: entry.trailing
        }
    }
    MouseArea {
        id: entryArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: entry.clicked()
    }
}
