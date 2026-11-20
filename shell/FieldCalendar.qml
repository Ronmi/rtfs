// 日曆 field（zenity --calendar、kdialog --calendar、yad --calendar／DT）。
// spec：year、month（1–12）、day，省略的部份用今天。值："YYYY-MM-DD"（輸出格式由轉接層處理）。
// 雙擊日期觸發預設按鈕；方向鍵移動一天／一週，PageUp／PageDown 換月。
import QtQuick

DialogField {
    id: root

    property date picked: new Date()

    function pad(n) {
        return String(n).padStart(2, "0");
    }
    function move(days) {
        const d = new Date(picked.getFullYear(), picked.getMonth(), picked.getDate() + days);
        setDate(d);
    }
    function moveMonth(delta) {
        const d = new Date(picked.getFullYear(), picked.getMonth() + delta, 1);
        // 月底的日子在短月份收到最後一天。
        const last = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
        setDate(new Date(d.getFullYear(), d.getMonth(), Math.min(picked.getDate(), last)));
    }
    function setDate(d) {
        picked = d;
        month.selected = d;
        month.showDate(d);
    }

    value: picked.getFullYear() + "-" + pad(picked.getMonth() + 1) + "-" + pad(picked.getDate())
    focusTarget: root
    activeFocusOnTab: true
    implicitWidth: month.implicitWidth
    implicitHeight: month.implicitHeight + 8

    Component.onCompleted: {
        const now = new Date();
        setDate(new Date(field.year ?? now.getFullYear(), (field.month ?? now.getMonth() + 1) - 1, field.day ?? now.getDate()));
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
            move(-1);
            break;
        case Qt.Key_Right:
            move(1);
            break;
        case Qt.Key_Up:
            move(-7);
            break;
        case Qt.Key_Down:
            move(7);
            break;
        case Qt.Key_PageUp:
            moveMonth(-1);
            break;
        case Qt.Key_PageDown:
            moveMonth(1);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // 有焦點時外框提示（鍵盤可操作）。
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: theme.accent
    }

    MonthView {
        id: month
        x: (parent.width - width) / 2
        y: 4
        theme: root.theme
        selectable: true
        onPicked: day => {
            root.picked = day;
            root.forceActiveFocus();
        }
        // 雙擊日期 = 按預設按鈕。
        onActivated: root.body.accept()
    }

}
