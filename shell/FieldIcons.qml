// 圖示格 field（yad --icons、yad --app／kdialog 沒有的程式選擇、kdialog --geticon）。
// spec：items（[{id, label, icon}]；icon 是圖示主題名稱或圖檔絕對路徑）、
// apps（true：項目改用已安裝的程式，id 是 desktop entry 的 id）、selected（一開始選取的 id）、
// search（打字篩選，預設 true）、iconSize（預設 48）、activate（雙擊／Enter："accept"（預設）或 "event"）。
// 值：選取項目的 id（沒有選取時為 null）。
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

DialogField {
    id: root

    readonly property int iconSize: field.iconSize ?? 48
    readonly property int cellWidth: Math.max(96, iconSize + 48)
    readonly property int cellHeight: iconSize + 56

    // 程式清單跟 Launcher 一樣：不顯示 NoDisplay，依名稱排序（中文依台灣習慣）。
    readonly property var items: field.apps
        ? DesktopEntries.applications.values
            .filter(e => !e.noDisplay)
            .sort((a, b) => a.name.localeCompare(b.name, "zh-TW"))
            .map(e => ({ id: e.id, label: e.name, icon: e.icon, keywords: [e.genericName, e.id].concat(e.keywords) }))
        : JSON.parse(JSON.stringify(field.items ?? []))

    property string query: ""
    readonly property var shown: {
        const q = query.trim().toLowerCase();
        return items.filter(it => q === "" || [it.label, it.id].concat(it.keywords ?? [])
            .some(s => s && String(s).toLowerCase().includes(q)));
    }
    property int cursor: 0
    onShownChanged: cursor = Math.max(0, Math.min(cursor, shown.length - 1))
    onCursorChanged: grid.positionViewAtIndex(cursor, GridView.Contain)

    value: shown[cursor]?.id ?? null
    expand: true
    focusTarget: field.search !== false ? search.input : grid
    implicitWidth: cellWidth * 4 + 12
    implicitHeight: (field.search !== false ? 50 : 0) + cellHeight * Math.min(3, Math.max(1, Math.ceil(shown.length / 4)))

    Component.onCompleted: {
        const i = items.findIndex(it => it.id === field.selected);
        if (i >= 0)
            Qt.callLater(() => cursor = shown.indexOf(items[i]));
    }

    function iconUrl(icon) {
        const s = String(icon ?? "");
        if (s === "")
            return Quickshell.iconPath("application-x-executable");
        return s.startsWith("/") ? "file://" + s : Quickshell.iconPath(s, "application-x-executable");
    }
    function activate() {
        if (shown.length === 0)
            return;
        if (field.activate === "event")
            emitEvent("activate", shown[cursor].id);
        else
            root.body.accept();
    }
    function handleKey(event, fromSearch) {
        const cols = Math.max(1, Math.floor(grid.width / cellWidth));
        switch (event.key) {
        case Qt.Key_Left:
            if (fromSearch)
                return;
            cursor = Math.max(0, cursor - 1);
            break;
        case Qt.Key_Right:
            if (fromSearch)
                return;
            cursor = Math.min(shown.length - 1, cursor + 1);
            break;
        case Qt.Key_Up:
            cursor = Math.max(0, cursor - cols);
            break;
        case Qt.Key_Down:
            cursor = Math.min(shown.length - 1, cursor + cols);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activate();
            break;
        default:
            if (fromSearch || field.search === false || event.text === "" || event.text < " "
                    || event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
                return;
            search.text += event.text;
            search.input.forceActiveFocus();
        }
        event.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        DialogInput {
            id: search
            theme: root.theme
            visible: root.field.search !== false
            Layout.fillWidth: true
            placeholder: I18n.tr("輸入文字篩選")
            glyph: "" // search
            keyHandler: event => root.handleKey(event, true)
            onTextChanged: root.query = text
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            model: root.shown.length
            activeFocusOnTab: true
            Keys.onPressed: event => root.handleKey(event, false)

            Text {
                visible: root.shown.length === 0
                anchors.centerIn: parent
                text: I18n.tr("沒有符合的項目")
                color: theme.dim
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(15)
            }

            delegate: Item {
                id: cell
                required property int index
                readonly property var item: root.shown[index] ?? ({})
                readonly property bool selected: index === root.cursor
                width: root.cellWidth
                height: root.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 12
                    color: cell.selected ? theme.accent : cellArea.containsMouse ? theme.surface : "transparent"
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: root.iconSize
                        source: root.iconUrl(cell.item.icon)
                    }
                    Text {
                        width: root.cellWidth - 16
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.item.label ?? cell.item.id ?? ""
                        color: cell.selected ? theme.accentFg : theme.fg
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        font.family: Theme.uiFontFamily
                        font.pixelSize: Theme.fontPx(13)
                    }
                }
                MouseArea {
                    id: cellArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cursor = cell.index
                    onDoubleClicked: {
                        root.cursor = cell.index;
                        root.activate();
                    }
                }
            }
        }
    }

    DialogScrollBar {
        theme: root.theme
        flickable: grid
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: grid.height
    }
}
