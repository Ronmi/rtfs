// 數字 field（yad 的 NUM、kdialog 沒有）：輸入框加 −／＋ 按鈕，上下鍵也能調整。
// spec：value（預設 min 或 0）、min、max、step（預設 1）、digits（小數位數，預設 0）。值：數字。
import QtQuick
import QtQuick.Layouts

DialogField {
    id: root

    readonly property real min: field.min ?? -1e9
    readonly property real max: field.max ?? 1e9
    readonly property real step: field.step ?? 1
    readonly property int digits: field.digits ?? 0
    property real number: 0

    // 還沒按 Enter、沒離開輸入框就直接用滑鼠按按鈕時，打到一半的數字也要算進結果
    // （點按鈕不會讓輸入框失去焦點，editingFinished 不會發生）。
    value: {
        const v = parseFloat(input.text);
        return isNaN(v) ? number : clamp(v);
    }
    focusTarget: input.input
    implicitWidth: 200
    implicitHeight: 42

    function clamp(v) {
        return Math.max(min, Math.min(max, Number(v.toFixed(digits))));
    }
    function setNumber(v) {
        number = clamp(v);
        input.text = number.toFixed(digits);
    }
    // 輸入框的文字只在離開或按 Enter 時套用；打到一半（例如只有「-」）不要被改掉。
    function commitText() {
        const v = parseFloat(input.text);
        setNumber(isNaN(v) ? number : v);
    }

    // 同 FieldEntry：spec 的 value 只在它本身改變時才寫入。
    property var specValue: undefined
    property bool ready: false
    onFieldChanged: {
        if (ready && field.value !== specValue) {
            specValue = field.value;
            setNumber(field.value ?? number);
        }
    }
    Component.onCompleted: {
        ready = true;
        specValue = field.value;
        setNumber(field.value ?? Math.max(min, Math.min(max, 0)));
    }

    Connections {
        target: input.input
        function onEditingFinished() {
            root.commitText();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        DialogInput {
            id: input
            theme: root.theme
            Layout.fillWidth: true
            Layout.fillHeight: true
            input.validator: DoubleValidator {
                decimals: root.digits
            }
            keyHandler: event => {
                if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    root.commitText();
                    root.setNumber(root.number + (event.key === Qt.Key_Up ? root.step : -root.step));
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.commitText();
                    root.body.handleKey(event);
                } else {
                    root.body.handleKey(event);
                }
            }
        }
        DialogButton {
            theme: root.theme
            implicitWidth: 42
            Layout.fillHeight: true
            text: "−"
            onClicked: root.setNumber(root.number - root.step)
        }
        DialogButton {
            theme: root.theme
            implicitWidth: 42
            Layout.fillHeight: true
            text: "+"
            onClicked: root.setNumber(root.number + root.step)
        }
    }
}
