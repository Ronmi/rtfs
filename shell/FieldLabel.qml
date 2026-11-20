// 純文字標籤 field（表單中的說明文字、yad 的 LBL）。spec：text、markup、tone（"error"：前面加紅色錯誤圖示、
// 文字加粗，例如 pinentry 的「密碼錯誤」；"hint"：次要說明，淡色小字，例如設定視窗每一項底下的說明）。沒有值。
// 錯誤不用紅字：深色對話框底上 err 色當文字對比不到 4.5，圖形只需要 3:1。
import QtQuick

DialogField {
    id: root

    readonly property bool isError: field.tone === "error"
    readonly property bool isHint: field.tone === "hint"

    hasValue: false
    implicitWidth: (isError ? glyph.implicitWidth + 8 : 0) + label.implicitWidth
    implicitHeight: Math.max(label.implicitHeight, isError ? glyph.implicitHeight : 0)

    Text {
        id: glyph
        visible: root.isError
        text: ""
        color: theme.err
        font.family: "FontAwesome"
        font.pixelSize: Theme.fontPx(18)
    }
    Text {
        id: label
        x: root.isError ? glyph.implicitWidth + 8 : 0
        width: parent.width - x
        wrapMode: Text.Wrap
        textFormat: root.field.markup ? Text.StyledText : Text.PlainText
        text: root.field.text ?? ""
        color: root.isHint ? theme.dim : theme.fg
        font.family: Theme.uiFontFamily
        font.pixelSize: Theme.fontPx(root.isHint ? 13 : 15)
        font.bold: root.isError
        onLinkActivated: link => Qt.openUrlExternally(link)
    }
}
