// 單行輸入框 field。
// spec：text（預設內容）、password、placeholder、choices（候選清單，可下拉選取）、editable（預設 true；
// false 時只能從 choices 選）。值：輸入框內容。
// 候選清單在輸入框下方展開（不另開彈出視窗，免得被視窗邊緣切掉）；上下鍵直接切換候選。
import QtQuick
import QtQuick.Layouts

DialogField {
    id: root

    readonly property var choices: field.choices ?? []
    readonly property bool editable: field.editable ?? true
    property bool listOpen: false

    value: input.text
    focusTarget: input.input
    implicitWidth: 240
    implicitHeight: column.implicitHeight

    // spec 的 text 只在它本身改變時寫入輸入框；用 binding 的話，任何 update 換掉 field 都會蓋掉使用者輸入。
    // （Loader 建立時就會設定 field，那時子項目可能還沒建好，所以等 onCompleted 之後才處理。）
    property var specText: undefined
    property bool ready: false
    onFieldChanged: {
        if (ready && field.text !== specText) {
            specText = field.text;
            input.text = field.text ?? "";
        }
    }
    Component.onCompleted: {
        ready = true;
        specText = field.text;
        input.text = field.text ?? "";
    }

    function pick(i) {
        if (choices.length === 0)
            return;
        input.text = String(choices[(i + choices.length) % choices.length]);
        listOpen = false;
    }

    function handleKey(event) {
        if (choices.length > 0 && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            const cur = choices.map(String).indexOf(input.text);
            pick(cur < 0 ? 0 : cur + (event.key === Qt.Key_Down ? 1 : -1));
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape && listOpen) {
            listOpen = false;
            event.accepted = true;
        } else {
            root.body.handleKey(event);
        }
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        DialogInput {
            theme: root.theme
            id: input
            Layout.fillWidth: true
            placeholder: root.field.placeholder ?? ""
            password: !!root.field.password
            readOnly: !root.editable
            keyHandler: root.handleKey

            // 不可編輯時，點輸入框就是打開候選清單。
            MouseArea {
                visible: !root.editable
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.listOpen = !root.listOpen
            }

            // 下拉箭頭
            Text {
                visible: root.choices.length > 0
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: root.listOpen ? "" : "" // angle-up / angle-down
                color: theme.dim
                font.family: "FontAwesome"
                font.pixelSize: Theme.fontPx(16)

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.listOpen = !root.listOpen
                }
            }
        }

        Rectangle {
            visible: root.listOpen
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(root.choices.length, 6) * 34 + 8
            radius: 10
            color: theme.surface

            ListView {
                id: choiceList
                anchors.fill: parent
                anchors.margins: 4
                anchors.rightMargin: 14
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.choices.length

                delegate: Rectangle {
                    required property int index
                    width: choiceList.width
                    height: 34
                    radius: 8
                    color: String(root.choices[index]) === input.text ? theme.accent
                         : choiceArea.containsMouse ? theme.bg : "transparent"

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: String(root.choices[parent.index])
                        color: String(root.choices[parent.index]) === input.text ? theme.accentFg : theme.fg
                        font.family: Theme.uiFontFamily
                        font.pixelSize: Theme.fontPx(15)
                    }
                    MouseArea {
                        id: choiceArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(parent.index)
                    }
                }
            }
            DialogScrollBar {
                theme: root.theme
                flickable: choiceList
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 4
            }
        }
    }
}
