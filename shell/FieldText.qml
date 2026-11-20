// 多行文字 field（zenity --text-info、kdialog --textbox／--textinputbox、詳細資訊）。
// spec：text、editable（值才會放進結果）、monospace、font（{family, size, bold, italic}）、
// html（Qt rich text 子集，不跑 JS、不載入外部資源）、wrap（預設 true）、autoScroll（追加時捲到最後）、
// collapsed（先收合，點標題列展開；collapseLabel 是標題文字）。
// append(str)：從 update 的 { fields: { id: { append } } } 呼叫，持續追加文字（例如 stdin 串流）。
// 可編輯時 Enter 是換行，Ctrl+Enter 才觸發預設按鈕。
import QtQuick
import QtQuick.Layouts

DialogField {
    id: root

    readonly property bool editable: !!field.editable
    property bool collapsed: !!field.collapsed

    value: edit.text
    hasValue: editable
    expand: !collapsed
    focusTarget: editable ? edit : null
    implicitWidth: 400
    implicitHeight: (field.collapseLabel !== undefined ? toggle.height + 6 : 0) + (collapsed ? 0 : 220)

    function append(str) {
        edit.insert(edit.length, str);
        if (field.autoScroll)
            flick.contentY = Math.max(0, flick.contentHeight - flick.height);
    }

    // 同 FieldEntry：spec 的 text 只在它本身改變時才寫入，不覆蓋使用者的編輯。
    property var specText: undefined
    property bool ready: false
    onFieldChanged: {
        if (ready && field.text !== specText) {
            specText = field.text;
            edit.text = field.text ?? "";
        }
    }
    Component.onCompleted: {
        ready = true;
        specText = field.text;
        edit.text = field.text ?? "";
    }

    // 收合標題列（有 collapseLabel 才顯示）
    Rectangle {
        id: toggle
        visible: root.field.collapseLabel !== undefined
        width: parent.width
        height: visible ? 32 : 0
        radius: 8
        color: toggleArea.containsMouse ? theme.surface : "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: (root.collapsed ? "  " : "  ") // angle-right / angle-down
            color: theme.dim
            font.family: "FontAwesome"
            font.pixelSize: Theme.fontPx(15)

            Text {
                anchors.left: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.field.collapseLabel ?? ""
                color: theme.fg
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(14)
                font.bold: true
            }
        }
        MouseArea {
            id: toggleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.collapsed = !root.collapsed
        }
    }

    Rectangle {
        visible: !root.collapsed
        anchors.top: toggle.bottom
        anchors.topMargin: toggle.visible ? 6 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        radius: 10
        color: theme.surface
        border.width: edit.activeFocus ? 2 : 0
        border.color: theme.accent

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 12
            anchors.rightMargin: 18
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: edit.implicitHeight

            // 游標移動時捲到看得到的位置（編輯、方向鍵）。
            function ensureVisible(r) {
                if (contentY >= r.y)
                    contentY = r.y;
                else if (contentY + height <= r.y + r.height)
                    contentY = r.y + r.height - height;
            }

            TextEdit {
                id: edit
                width: flick.width
                readOnly: !root.editable
                activeFocusOnTab: true
                selectByMouse: true
                persistentSelection: true
                wrapMode: root.field.wrap === false ? TextEdit.NoWrap : TextEdit.Wrap
                textFormat: root.field.html ? TextEdit.RichText : TextEdit.PlainText
                color: theme.fg
                selectionColor: theme.accent
                selectedTextColor: theme.accentFg
                font.family: root.field.font?.family ?? (root.field.monospace ? "monospace" : Theme.uiFontFamily)
                font.pixelSize: root.field.font?.size ?? 14
                font.bold: !!root.field.font?.bold
                font.italic: !!root.field.font?.italic
                onCursorRectangleChanged: if (activeFocus) flick.ensureVisible(cursorRectangle)
                onLinkActivated: link => Qt.openUrlExternally(link)

                Keys.onPressed: event => {
                    // TextEdit 預設把 Tab 當成字元輸入；這裡跟其他欄位一樣用來移動焦點（表單裡幾乎不會需要輸入 Tab 字元）。
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        const next = edit.nextItemInFocusChain(event.key === Qt.Key_Tab);
                        if (next)
                            next.forceActiveFocus(event.key === Qt.Key_Tab ? Qt.TabFocusReason : Qt.BacktabFocusReason);
                        event.accepted = true;
                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            && (event.modifiers & Qt.ControlModifier || !root.editable)) {
                        root.body.accept();
                        event.accepted = true;
                    }
                }
            }
        }
        DialogScrollBar {
            theme: root.theme
            flickable: flick
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 6
        }
    }
}
