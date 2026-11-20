// 表單裡的按鈕 field（yad 的 BTN／FBTN）：按下不關閉對話框，只送一個 "click" 事件，由前端決定做什麼
// （例如執行指令）。spec：label、role（同對話框按鈕：accept／destructive／一般）。沒有值。
import QtQuick

DialogField {
    id: root

    hasValue: false
    ownsLabel: true
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    DialogButton {
        id: button
        theme: root.theme
        width: Math.min(parent.width, implicitWidth)
        text: root.field.label ?? ""
        fill: root.field.role === "destructive" ? theme.danger : root.field.role === "accept" ? theme.accent : theme.surface
        textColor: root.field.role === "destructive" ? theme.dangerFg : root.field.role === "accept" ? theme.accentFg : theme.fg
        onClicked: root.emitEvent("click", null)
    }
}
