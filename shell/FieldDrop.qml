// 拖放區 field（yad --dnd）：把檔案或文字拖進來，每次放下送一個 "drop" 事件，
// 值是放下的 URL 陣列（檔案是 file:// URL），沒有 URL 時是 [文字]。spec：text（區域內的提示文字）、height（預設 160）。
// 這個 field 只送事件，沒有最終值。
import QtQuick

DialogField {
    id: root

    hasValue: false
    expand: true
    implicitWidth: 360
    implicitHeight: field.height ?? 160

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: drop.containsDrag ? theme.surface : "transparent"
        border.width: 2
        border.color: drop.containsDrag ? theme.accent : theme.dim

        Column {
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "" // download
                color: drop.containsDrag ? theme.accent : theme.dim
                font.family: "FontAwesome"
                font.pixelSize: Theme.fontPx(32)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.field.text ?? I18n.tr("把檔案或文字拖到這裡")
                color: theme.dim
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(15)
            }
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        onDropped: event => {
            const urls = event.hasUrls ? event.urls.map(String) : [];
            root.emitEvent("drop", urls.length > 0 ? urls : [event.text ?? ""]);
            event.acceptProposedAction();
        }
    }
}
