// 核取方塊 field（zenity text-info 的 --checkbox、kdialog 的 dontagain、yad 的 CHK）。
// spec：label、checked。值：true／false。空白鍵或點擊切換。
import QtQuick

DialogField {
    id: root

    property bool checked: false

    value: checked
    ownsLabel: true
    implicitWidth: row.implicitWidth
    implicitHeight: 32

    // 只在 spec 的 checked 改變時更新，update 換掉其他屬性時不會蓋掉使用者的勾選。
    property var specChecked: undefined
    property bool ready: false
    onFieldChanged: {
        if (ready && field.checked !== specChecked) {
            specChecked = field.checked;
            checked = !!field.checked;
        }
    }
    Component.onCompleted: {
        ready = true;
        specChecked = field.checked;
        checked = !!field.checked;
    }

    activeFocusOnTab: true
    Keys.onSpacePressed: checked = !checked

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        DialogCheckBox {
            theme: root.theme
            anchors.verticalCenter: parent.verticalCenter
            checked: root.checked
            focused: root.activeFocus
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.field.label ?? ""
            color: theme.fg
            font.family: Theme.uiFontFamily
            font.pixelSize: Theme.fontPx(15)
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked;
            root.forceActiveFocus();
        }
    }
}
