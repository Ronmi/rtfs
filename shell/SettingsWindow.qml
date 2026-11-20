// 設定視窗：左邊是分組（schema 的第一層），右邊是該組的設定項。欄位就是對話框的 Field*.qml（用 DialogBody 排版），
// 依 ConfigSchema.js 產生，所以新增設定只要改 schema。按「儲存」才寫入設定檔，之後由 Config 照平常的流程重讀、檢查。
// 一般視窗（niri 管理、淺色），跟 rtfs-ui 的 window 容器一樣。由 Settings 建立，關掉就銷毀，下次打開重新讀目前的值。
import QtQuick
import QtQuick.Layouts
import Quickshell

FloatingWindow {
    id: root

    readonly property var theme: Theme.dialogLight
    readonly property var groups: Object.keys(Config.schema)
    property int current: 0

    // 打開時的設定值。建立時先用 binding 算一次（fields 建立時就要用），之後自己賦值一次把 binding 拆掉：
    // 編輯中 Config 重讀（例如手動改了檔案）也不會把畫面上的值換掉。
    property var initial: JSON.parse(JSON.stringify(Config.data))
    Component.onCompleted: initial = initial

    signal done

    title: I18n.tr("rtfs 設定")
    implicitWidth: 820
    implicitHeight: 640
    minimumSize: Qt.size(560, 360)
    color: theme.bg
    visible: true

    onClosed: done()

    function get(obj, path) {
        return path.split(".").reduce((o, k) => o?.[k], obj);
    }
    function set(obj, path, value) {
        const keys = path.split(".");
        const last = keys.pop();
        keys.reduce((o, k) => o[k], obj)[last] = value;
    }

    // 一個分組的 fields：子分組變成粗體小標（說明用 hint 樣式的標籤），每一項的說明放在 field 的 hint。
    function fieldsFor(items, prefix) {
        const out = [];
        for (const k in items) {
            const node = items[k];
            const path = prefix + "." + k;
            if (node.items) {
                out.push({ type: "label", text: "<b>" + node.label + "</b>", markup: true });
                if (node.desc)
                    out.push({ type: "label", tone: "hint", text: node.desc });
                out.push(...fieldsFor(node.items, path));
                continue;
            }
            const field = fieldFor(node, path, get(initial, path));
            if (node.desc)
                field.hint = node.desc;
            out.push(field);
        }
        return out;
    }
    function fieldFor(node, path, value) {
        switch (node.type) {
        case "bool":
            return { type: "check", id: path, label: node.label, checked: value };
        case "int":
        case "number":
            return { type: "number", id: path, label: node.label, value: value,
                     min: node.min, max: node.max, digits: node.digits ?? 0 };
        case "enum":
            return { type: "entry", id: path, label: node.label, editable: false,
                     text: node.choices.find(c => c.value === value)?.label ?? value,
                     choices: node.choices.map(c => c.label) };
        case "list":
            return { type: "text", id: path, label: node.label, editable: true, text: value.join("\n") };
        case "output": {
            // 沒接上的螢幕也留在候選裡，免得打開設定就看不到原本的值。
            const names = Quickshell.screens.map(s => s.name);
            return { type: "entry", id: path, label: node.label, text: value,
                     choices: names.includes(value) ? names : names.concat([value]) };
        }
        default:
            return { type: "entry", id: path, label: node.label, text: value };
        }
    }
    // field 的值換回設定值（enum 從顯示文字換回 value、清單一行一個）。
    function valueFrom(node, v) {
        switch (node.type) {
        case "enum":
            return node.choices.find(c => c.label === v)?.value ?? v;
        case "list":
            return v.split("\n").map(s => s.trim()).filter(s => s !== "");
        default:
            return v;
        }
    }

    function save() {
        const values = JSON.parse(JSON.stringify(initial));
        for (let i = 0; i < pages.count; i++) {
            const v = pages.itemAt(i).body.values();
            for (const path in v)
                set(values, path, valueFrom(get(Config.schema, path.split(".").join(".items.")), v[path]));
        }
        Config.save(values);
        done();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // 分組清單
            Column {
                Layout.preferredWidth: 160
                Layout.alignment: Qt.AlignTop
                spacing: 2

                Repeater {
                    model: root.groups

                    Rectangle {
                        id: entry
                        required property string modelData
                        required property int index
                        readonly property bool selected: index === root.current

                        width: parent.width
                        height: 40
                        radius: 10
                        color: selected ? root.theme.accent : area.containsMouse ? root.theme.surface : "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 14
                            text: Config.schema[entry.modelData].label
                            color: entry.selected ? root.theme.accentFg : root.theme.fg
                            font.family: Theme.uiFontFamily
                            font.pixelSize: Theme.fontPx(15)
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.current = entry.index
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: root.theme.line
            }

            // 每組一頁，全部同時存在（切換分組不會丟掉改到一半的值），只顯示目前那頁。
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Repeater {
                    id: pages
                    model: root.groups

                    Item {
                        id: page
                        required property string modelData
                        required property int index
                        readonly property alias body: body

                        anchors.fill: parent
                        visible: index === root.current

                        // Tab 移到捲出畫面的欄位時，捲到看得到的位置。
                        readonly property Item focused: Window.activeFocusItem
                        onFocusedChanged: {
                            let p = focused;
                            while (p && p !== body)
                                p = p.parent;
                            // 打開時拿到焦點的是整頁的 DialogBody 本身（比畫面高），不能拿來捲，否則會捲到底。
                            if (!p || !visible || focused === body)
                                return;
                            const y = focused.mapToItem(flick.contentItem, 0, 0).y;
                            if (y < flick.contentY)
                                flick.contentY = Math.max(0, y - 8);
                            else if (y + focused.height > flick.contentY + flick.height)
                                flick.contentY = Math.min(flick.contentHeight - flick.height,
                                                          y + focused.height - flick.height + 8);
                        }

                        Flickable {
                            id: flick
                            anchors.fill: parent
                            anchors.rightMargin: 14
                            contentHeight: body.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            DialogBody {
                                id: body
                                width: flick.width
                                theme: root.theme
                                spec: ({ buttons: [] })
                                fieldSpecs: root.fieldsFor(Config.schema[page.modelData].items, page.modelData)
                                // Esc（DialogBody 自己處理）等於取消。
                                onFinished: root.done()
                            }
                        }
                        DialogScrollBar {
                            theme: root.theme
                            flickable: flick
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 12

            DialogButton {
                theme: root.theme
                text: I18n.tr("取消")
                onClicked: root.done()
            }
            DialogButton {
                theme: root.theme
                text: I18n.tr("儲存")
                fill: root.theme.accent
                textColor: root.theme.accentFg
                onClicked: root.save()
            }
        }
    }
}
