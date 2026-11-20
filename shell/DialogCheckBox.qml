// 對話框共用的核取方塊／單選圓點外觀（只負責畫，點擊由使用的地方處理）。
// radio: true 時畫成圓形單選鈕。
import QtQuick

Rectangle {
    id: root

    // 配色（Theme.dialogDark／dialogLight），由使用的地方傳入；預設深色。
    property var theme: Theme.dialogDark

    property bool checked: false
    property bool radio: false
    property bool focused: false

    implicitWidth: 20
    implicitHeight: 20
    radius: radio ? 10 : 5
    color: checked ? theme.accent : "transparent"
    border.width: checked ? 0 : 2
    border.color: focused ? theme.accent : theme.dim

    Text {
        visible: root.checked && !root.radio
        anchors.centerIn: parent
        text: "" // check
        color: theme.accentFg
        font.family: "FontAwesome"
        font.pixelSize: Theme.fontPx(13)
    }
    Rectangle {
        visible: root.checked && root.radio
        anchors.centerIn: parent
        width: 8
        height: 8
        radius: 4
        color: theme.accentFg
    }
    // 有焦點又已勾選時，外面再加一圈。
    Rectangle {
        visible: root.focused && root.checked
        anchors.centerIn: parent
        width: parent.width + 6
        height: parent.height + 6
        radius: parent.radius + 3
        color: "transparent"
        border.width: 2
        border.color: theme.accent
    }
}
