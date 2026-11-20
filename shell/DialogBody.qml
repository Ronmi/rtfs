// 對話框內容：圖示＋標題＋內文、依序排列的 fields、按鈕列。容器（DialogModal／DialogWindow）只負責外框。
// spec 格式見 scripts/rtfs-ui 開頭的說明。
//
// fields 在建立時固定（fieldSpecs），之後的 update 只修改既有 field 的屬性；
// spec 本身（標題、內文、按鈕）可以整個換掉。
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

ColumnLayout {
    id: body

    property var spec: ({})
    // 配色（Theme.dialogDark／dialogLight），由容器決定。
    property var theme: Theme.dialogDark
    property var fieldSpecs: []

    // 一個請求只會有一個最終結果。
    property bool done: false
    signal finished(var payload)
    signal event(var payload)

    readonly property var defaultButtons: [
        { id: "cancel", label: I18n.tr("取消") },
        { id: "ok", label: I18n.tr("確定"), role: "accept", default: true }
    ]
    readonly property var buttons: spec.buttons ?? defaultButtons

    // 標準圖示用 FontAwesome 加注意力等級配色，跟 shell 其他地方一致；其他字串當成圖示主題名稱或圖檔路徑。
    readonly property var iconKinds: ({
        info: { glyph: Theme.iconGlyphs.info, color: theme.info },
        question: { glyph: Theme.iconGlyphs.question, color: theme.info },
        warning: { glyph: Theme.iconGlyphs.warning, color: theme.warn },
        error: { glyph: Theme.iconGlyphs.error, color: theme.err }
    })
    readonly property var iconKind: iconKinds[spec.icon] ?? null
    readonly property string iconSource: {
        const icon = spec.icon ?? "";
        if (icon === "" || iconKind !== null)
            return "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        return Quickshell.hasThemeIcon(icon) ? Quickshell.iconPath(icon) : "";
    }
    readonly property bool hasIcon: iconKind !== null || iconSource !== ""

    // 已建立的 field 物件，順序同 fieldSpecs（Loader 載入後填入）。
    property var fieldItems: []

    function fieldId(i) {
        return fieldSpecs[i]?.id ?? ("f" + i);
    }
    function fieldIndex(id) {
        for (let i = 0; i < fieldSpecs.length; i++)
            if (fieldId(i) === id)
                return i;
        return -1;
    }
    function fieldUrl(type) {
        return Qt.resolvedUrl("Field" + type.charAt(0).toUpperCase() + type.slice(1) + ".qml");
    }

    function values() {
        const v = {};
        fieldItems.forEach((item, i) => {
            if (item && item.hasValue)
                v[fieldId(i)] = item.value;
        });
        return v;
    }

    function finish(button, reason) {
        if (done)
            return;
        done = true;
        finished({ button: button ? button.id : null, reason: reason, values: values() });
    }
    function emitEvent(name, index, data) {
        if (!done)
            event({ event: name, field: fieldId(index), value: data });
    }

    // requires：指定的 field 值為真才能按（例如 text-info 的「我已閱讀並同意」）。
    function buttonEnabled(b) {
        if (b.disabled)
            return false;
        if (b.requires !== undefined) {
            const i = fieldIndex(b.requires);
            return i >= 0 && !!fieldItems[i]?.value;
        }
        return true;
    }
    function accept() {
        const b = buttons.find(b => b.default);
        if (b && buttonEnabled(b))
            finish(b, "button");
    }

    // 輸入框等 field 會把自己沒處理的按鍵轉來這裡。
    function handleKey(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            accept();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            finish(null, "dismiss");
            event.accepted = true;
        }
    }

    function focusFirst() {
        const item = fieldItems.find(it => it && it.focusTarget && it.visible);
        if (item)
            item.focusTarget.forceActiveFocus();
        else
            body.forceActiveFocus();
    }

    // update：title／text／icon／markup／buttons／timeout 直接取代；fields 依 id 合併屬性，
    // append 交給 field 的 append()（多行文字持續追加）。
    function applyPatch(patch) {
        const s = Object.assign({}, spec);
        for (const k of ["title", "text", "icon", "markup", "wrap", "buttons", "timeout"])
            if (k in patch)
                s[k] = patch[k];
        spec = s;
        for (const id in (patch.fields ?? {})) {
            const i = fieldIndex(id);
            const item = fieldItems[i];
            if (!item)
                continue;
            const fp = Object.assign({}, patch.fields[id]);
            if ("append" in fp) {
                if (item.append)
                    item.append(fp.append);
                delete fp.append;
            }
            item.field = Object.assign({}, item.field, fp);
        }
    }

    focus: true
    Keys.onPressed: event => handleKey(event)
    spacing: 16

    Timer {
        running: (body.spec.timeout ?? 0) > 0
        interval: (body.spec.timeout ?? 0) * 1000
        onTriggered: body.finish(null, "timeout")
    }

    // 圖示 + 標題 + 內文
    RowLayout {
        visible: body.hasIcon || title.text !== "" || message.text !== ""
        Layout.fillWidth: true
        spacing: 16

        Item {
            visible: body.hasIcon
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignTop

            Text {
                visible: body.iconKind !== null
                anchors.centerIn: parent
                text: body.iconKind?.glyph ?? ""
                color: body.iconKind?.color ?? "transparent"
                font.family: "FontAwesome"
                font.pixelSize: Theme.fontPx(36)
            }
            IconImage {
                visible: body.iconSource !== ""
                anchors.fill: parent
                source: body.iconSource
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 8

            Text {
                id: title
                visible: text !== ""
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: body.spec.title ?? ""
                color: theme.fg
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(20)
                font.bold: true
            }
            Text {
                id: message
                visible: text !== ""
                Layout.fillWidth: true
                // wrap: false 時不換行，對話框跟著變寬；ellipsize 時超出寬度的部份用「…」省略。
                wrapMode: body.spec.wrap === false || body.spec.ellipsize ? Text.NoWrap : Text.Wrap
                elide: body.spec.ellipsize ? Text.ElideRight : Text.ElideNone
                // markup：Qt StyledText，大致相容 Pango 的 <b>/<i>/<u>/<br>/<span>。
                textFormat: body.spec.markup ? Text.StyledText : Text.PlainText
                text: body.spec.text ?? ""
                color: theme.fg
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(15)
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
        }
    }

    // 每個 field：上方的標籤（spec 的 label；核取方塊、按鈕這類自己顯示 label 的 field 除外）＋ field 本身＋下方的 hint。
    Repeater {
        model: body.fieldSpecs.length

        ColumnLayout {
            id: slot
            required property int index
            readonly property var fieldSpec: body.fieldSpecs[index]
            readonly property var item: loader.item
            readonly property string label: (item ? item.field.label : fieldSpec.label) ?? ""

            Layout.fillWidth: true
            Layout.fillHeight: item?.expand ?? false
            visible: !(item ? item.field.hidden : fieldSpec.hidden)
            spacing: 6

            Text {
                visible: slot.label !== "" && !(slot.item?.ownsLabel ?? false)
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: slot.label
                color: theme.dim
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(13)
                font.bold: true
            }

            Loader {
                id: loader
                Layout.fillWidth: true
                Layout.fillHeight: item?.expand ?? false
                Layout.preferredHeight: item ? item.implicitHeight : 0
                Layout.preferredWidth: item ? item.implicitWidth : 0

                Component.onCompleted: setSource(body.fieldUrl(slot.fieldSpec.type ?? ""), {
                    field: slot.fieldSpec,
                    body: body,
                    index: slot.index
                })
                onLoaded: {
                    const items = body.fieldItems.slice();
                    items[slot.index] = item;
                    body.fieldItems = items;
                }
            }

            // hint：field 底下的淡色小字說明（例如設定視窗每一項的說明）。
            Text {
                readonly property string hint: (slot.item ? slot.item.field.hint : slot.fieldSpec.hint) ?? ""
                visible: hint !== ""
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: hint
                color: theme.dim
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(13)
            }
        }
    }

    // 按鈕：平分整列寬度。accept 用娜璉色、destructive 用彩瑛紅，其他是一般按鈕。
    RowLayout {
        visible: body.buttons.length > 0
        Layout.fillWidth: true
        spacing: 12

        Repeater {
            model: body.buttons
            DialogButton {
                theme: body.theme
                required property var modelData
                readonly property bool usable: body.buttonEnabled(modelData)
                Layout.fillWidth: true
                Layout.preferredWidth: 1 // 平分：大家的偏好寬度相同，多的空間平均分配
                text: modelData.label ?? modelData.id
                isDefault: !!modelData.default
                opacity: usable ? 1 : 0.4
                fill: modelData.role === "destructive" ? theme.danger
                    : modelData.role === "accept" ? theme.accent : theme.surface
                textColor: modelData.role === "destructive" ? theme.dangerFg
                         : modelData.role === "accept" ? theme.accentFg : theme.fg
                onClicked: if (usable) body.finish(modelData, "button")
            }
        }
    }
}
