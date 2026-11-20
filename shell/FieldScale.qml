// 滑桿 field（zenity --scale、kdialog --slider、yad --scale／SCL）。
// spec：value、min（預設 0）、max（預設 100）、step（預設 1）、hideValue（不顯示目前數值）、
// partial（拖動時送 "change" 事件，給 zenity 的 --print-partial）、vertical（直的，高 200）、
// marks（[{value, label}] 刻度標記）。值：數字。
// 鍵盤：左右（直的是上下）鍵一格、PageUp／PageDown 十格、Home／End 到兩端。
import QtQuick

DialogField {
    id: root

    readonly property real min: field.min ?? 0
    readonly property real max: field.max ?? 100
    readonly property real step: Math.max(field.step ?? 1, 1e-9)
    readonly property bool vertical: !!field.vertical
    readonly property var marks: field.marks ?? []
    property real number: 0

    value: number
    focusTarget: root
    activeFocusOnTab: true
    implicitWidth: vertical ? 80 : 300
    implicitHeight: vertical ? 200 : 40 + (marks.length > 0 ? 18 : 0)

    // 對齊到 step，限制在範圍內。
    function snap(v) {
        const n = Math.round((v - min) / step);
        const digits = (String(step).split(".")[1] ?? "").length;
        return Math.max(min, Math.min(max, Number((min + n * step).toFixed(digits))));
    }
    function setNumber(v) {
        const n = snap(v);
        if (n === number)
            return;
        number = n;
        if (field.partial)
            emitEvent("change", n);
    }
    // 軌道上的位置（0–1）
    function ratioOf(v) {
        return max > min ? (v - min) / (max - min) : 0;
    }

    property var specValue: undefined
    property bool ready: false
    onFieldChanged: {
        if (ready && field.value !== specValue) {
            specValue = field.value;
            number = snap(field.value ?? min);
        }
    }
    Component.onCompleted: {
        ready = true;
        specValue = field.value;
        number = snap(field.value ?? min);
    }

    Keys.onPressed: event => {
        const big = Math.max(step, (max - min) / 10);
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_Down:
            setNumber(number - step);
            break;
        case Qt.Key_Right:
        case Qt.Key_Up:
            setNumber(number + step);
            break;
        case Qt.Key_PageDown:
            setNumber(number - big);
            break;
        case Qt.Key_PageUp:
            setNumber(number + big);
            break;
        case Qt.Key_Home:
            setNumber(min);
            break;
        case Qt.Key_End:
            setNumber(max);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // 數值顯示（橫的放右邊、直的放上面）
    Text {
        id: valueText
        visible: !root.field.hideValue
        x: root.vertical ? (parent.width - width) / 2 : parent.width - width
        y: root.vertical ? 0 : (40 - height) / 2
        width: root.vertical ? implicitWidth : Math.max(48, implicitWidth)
        horizontalAlignment: Text.AlignRight
        text: String(root.number)
        color: theme.fg
        font.family: Theme.uiFontFamily
        font.pixelSize: Theme.fontPx(15)
        font.bold: true
    }

    // 軌道區域（可點擊、拖曳）
    Item {
        id: track
        x: root.vertical ? (parent.width - 24) / 2 : 0
        y: root.vertical ? (valueText.visible ? valueText.height + 8 : 0) : 8
        width: root.vertical ? 24 : parent.width - (valueText.visible ? valueText.width + 16 : 0)
        height: root.vertical ? parent.height - y : 24

        readonly property real length: root.vertical ? height - 20 : width - 20

        Rectangle {
            // 底軌
            x: root.vertical ? (parent.width - width) / 2 : 10
            y: root.vertical ? 10 : (parent.height - height) / 2
            width: root.vertical ? 6 : track.length
            height: root.vertical ? track.length : 6
            radius: 3
            color: theme.track

            // 已填滿的部份（直的從下往上）
            Rectangle {
                x: 0
                y: root.vertical ? parent.height - height : 0
                width: root.vertical ? parent.width : parent.width * root.ratioOf(root.number)
                height: root.vertical ? parent.height * root.ratioOf(root.number) : parent.height
                radius: 3
                color: theme.accent
            }
        }

        // 刻度
        Repeater {
            model: root.marks
            Text {
                required property var modelData
                readonly property real pos: 10 + track.length * root.ratioOf(modelData.value ?? 0)
                x: root.vertical ? track.width + 6 : pos - width / 2
                y: root.vertical ? 10 + track.length - pos + 10 - height / 2 : track.height + 2
                text: modelData.label ?? String(modelData.value)
                color: theme.dim
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(12)
            }
        }

        // 把手
        Rectangle {
            readonly property real pos: track.length * root.ratioOf(root.number)
            x: root.vertical ? (parent.width - width) / 2 : pos + 10 - width / 2
            y: root.vertical ? parent.height - 10 - pos - height / 2 : (parent.height - height) / 2
            width: 20
            height: 20
            radius: 10
            color: theme.bg
            border.width: 2
            border.color: root.activeFocus ? theme.accent : theme.dim
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            function apply(mouse) {
                const p = root.vertical ? (track.height - 10 - (mouse.y - 6)) : (mouse.x - 6 - 10);
                root.setNumber(root.min + Math.max(0, Math.min(1, p / track.length)) * (root.max - root.min));
            }
            onPressed: mouse => {
                root.forceActiveFocus();
                apply(mouse);
            }
            onPositionChanged: mouse => apply(mouse)
            onWheel: wheel => root.setNumber(root.number + (wheel.angleDelta.y > 0 ? root.step : -root.step))
        }
    }
}
