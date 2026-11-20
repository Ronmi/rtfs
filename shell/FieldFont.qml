// 字型選擇 field（yad --font／FN；zenity、kdialog 沒有）。
// spec：family、size（px，預設 14）、bold、italic、preview（預覽文字）。
// 值：{ family, size, bold, italic }（輸出格式由轉接層處理）。
// 直接組合清單、數字、核取方塊 field，外觀和操作跟它們一致。
import QtQuick
import QtQuick.Layouts

DialogField {
    id: root

    readonly property var families: Qt.fontFamilies()
    readonly property var familySelected: familyList.value ? familyList.value.selected : []
    readonly property string family: families[familySelected[0] ?? -1] ?? (field.family ?? Theme.uiFontFamily)

    // spec 的 family 可能是英文名稱，Qt.fontFamilies() 列的卻可能是在地化名稱（例如「芫荽」），
    // 所以先讓 Qt 解析成實際使用的字型（fontInfo.family），再用它找清單位置。
    readonly property int initialIndex: {
        const want = field.family ?? Theme.uiFontFamily;
        for (const name of [probe.fontInfo.family, want]) {
            const i = families.findIndex(f => f.toLowerCase() === String(name).toLowerCase());
            if (i >= 0)
                return i;
        }
        return 0;
    }
    Text {
        id: probe
        visible: false
        text: "x" // 沒有文字時 fontInfo 會回傳預設字型，不是解析結果
        font.family: root.field.family ?? Theme.uiFontFamily
    }

    value: ({
        family: family,
        size: sizeField.value ?? 14,
        bold: !!boldField.value,
        italic: !!italicField.value
    })
    expand: true
    focusTarget: familyList.focusTarget
    implicitWidth: 420
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: 12

        FieldList {
            id: familyList
            body: root.body
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: implicitHeight
            field: ({
                rows: root.families.map(f => [f]),
                mode: "single",
                visibleRows: 6,
                selected: [root.initialIndex]
            })
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            FieldNumber {
                id: sizeField
                body: root.body
                Layout.preferredWidth: 160
                Layout.preferredHeight: implicitHeight
                field: ({ value: root.field.size ?? 14, min: 4, max: 200 })
            }
            FieldCheck {
                id: boldField
                body: root.body
                Layout.preferredHeight: implicitHeight
                Layout.preferredWidth: implicitWidth
                field: ({ label: I18n.tr("粗體"), checked: !!root.field.bold })
            }
            FieldCheck {
                id: italicField
                body: root.body
                Layout.preferredHeight: implicitHeight
                Layout.preferredWidth: implicitWidth
                field: ({ label: I18n.tr("斜體"), checked: !!root.field.italic })
            }
        }

        // 預覽
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(56, preview.implicitHeight + 24)
            radius: 10
            color: theme.surface
            clip: true

            Text {
                id: preview
                anchors.fill: parent
                anchors.margins: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: root.field.preview ?? I18n.tr("TWICE 字型預覽 AaBbCc 0123")
                color: theme.fg
                font.family: root.family
                font.pixelSize: root.value.size
                font.bold: root.value.bold
                font.italic: root.value.italic
            }
        }
    }
}
