// 對話框共用的單行輸入框：圓角底、placeholder、可選的左側 FontAwesome 圖示。
// keyHandler(event)：輸入框先把按鍵交給它（例如清單的上下鍵、Enter 觸發預設按鈕），沒接受的才自己處理。
import QtQuick

Rectangle {
    id: root

    // 配色（Theme.dialogDark／dialogLight），由使用的地方傳入；預設深色。
    property var theme: Theme.dialogDark

    property alias text: input.text
    property alias input: input
    property string placeholder
    property string glyph: ""
    property bool password: false
    property bool readOnly: false
    property var keyHandler: null

    implicitWidth: 240
    implicitHeight: 42
    radius: 10
    color: theme.surface
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? theme.accent : theme.line

    Text {
        visible: root.glyph !== ""
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyph
        color: theme.dim
        font.family: "FontAwesome"
        font.pixelSize: Theme.fontPx(15)
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: root.glyph !== "" ? 40 : 14
        anchors.rightMargin: 14
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        readOnly: root.readOnly
        // 讓 Tab／Shift+Tab 能在對話框的欄位之間移動（核取方塊、清單等 field 自己也有設）。
        activeFocusOnTab: true
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        color: theme.fg
        selectionColor: theme.accent
        selectedTextColor: theme.accentFg
        selectByMouse: true
        font.family: Theme.uiFontFamily
        font.pixelSize: Theme.fontPx(16)
        Keys.onPressed: event => {
            if (root.keyHandler)
                root.keyHandler(event);
        }

        Text {
            visible: input.text === "" && !input.inputMethodComposing
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: theme.dim
            font: input.font
        }
    }
}
