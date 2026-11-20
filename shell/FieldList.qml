// 清單 field（zenity --list、kdialog --menu／--checklist／--radiolist、yad --list）。
// spec：
//   columns    欄位標題                rows      [[cell, ...], ...]
//   types      每欄型別：text（預設）| number（靠右）| image（圖示名稱或圖檔路徑）| progress（0–100 的進度條）
//   mode       single（預設，單選）| multiple（Ctrl／Shift 多選）| check（核取欄）| radio（單選欄）| none（只顯示）
//   checked    check／radio 一開始勾選的列號    selected  一開始選取的列號
//   search     打字篩選（預設 true）      hideHeader  隱藏欄位標題    visibleRows  沒有多餘空間時顯示幾列（預設 8）
//   editable   可以編輯文字欄（雙擊或 F2）  activate  雙擊／Enter 的行為："accept"（預設，觸發預設按鈕）或 "event"
//   update 的 append 可以追加列，見 append()。
// 值：{ selected: [列號...] }（check／radio 是勾選的列，其他是選取的列；列號是 rows 的原始位置），
//     editable 時另有 rows（編輯後的內容）。
// 鍵盤：上下鍵移動、空白鍵勾選／切換、直接打字就是篩選（中文請點搜尋框輸入）。
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

DialogField {
    id: root

    readonly property string mode: field.mode ?? "single"
    readonly property bool marker: mode === "check" || mode === "radio"
    readonly property var types: field.types ?? []
    readonly property var columns: field.columns ?? []
    readonly property int columnCount: rows.reduce((n, r) => Math.max(n, r.length), Math.max(columns.length, 1))
    readonly property bool searchable: field.search !== false && mode !== "none"
    readonly property int rowHeight: 36

    // 可編輯時的內容複本；一般情況就是 spec 的 rows。
    property var rows: []
    // check／radio 的勾選、multiple 的選取：列號 → true（重新指定物件才會觸發 binding）。
    property var marked: ({})
    property var picked: ({})

    property string query: ""
    readonly property var shown: {
        const q = query.trim().toLowerCase();
        const out = [];
        rows.forEach((row, i) => {
            if (q === "" || row.some((c, k) => typeOf(k) !== "image" && String(c).toLowerCase().includes(q)))
                out.push(i);
        });
        return out;
    }
    // 游標在 shown 裡的位置；搜尋結果一變就回到第一列（跟 fuzzel 一樣，直接 Enter 選最符合的）。
    property int cursor: 0
    property int rangeAnchor: 0
    // 搜尋文字一變就回到第一列；串流追加列時只確保游標還在範圍內，不打斷使用者的選取。
    onQueryChanged: cursor = 0
    onShownChanged: cursor = Math.max(0, Math.min(cursor, shown.length - 1))
    onCursorChanged: view.positionViewAtIndex(cursor, ListView.Contain)

    // 編輯中的儲存格（原始列號、欄號）。
    property int editRow: -1
    property int editCol: -1

    function typeOf(k) {
        return types[k] ?? "text";
    }
    function keysOf(obj) {
        return Object.keys(obj).filter(k => obj[k]).map(Number).sort((a, b) => a - b);
    }

    value: {
        let selected;
        if (marker)
            selected = keysOf(marked);
        else if (mode === "multiple")
            selected = keysOf(picked);
        else if (mode === "single")
            selected = shown.length > 0 ? [shown[cursor]] : [];
        else
            selected = [];
        const v = { selected: selected };
        if (field.editable)
            v.rows = rows;
        return v;
    }
    expand: true
    focusTarget: searchable && (mode === "single" || mode === "none") ? search.input : view
    implicitWidth: 400
    implicitHeight: column.implicitHeight

    Component.onCompleted: {
        // 經過 Loader 傳進來的巢狀陣列是 Qt 的序列型別（Array.isArray 為 false），先轉成一般 JS 陣列。
        rows = JSON.parse(JSON.stringify(field.rows ?? [])).map(r => (Array.isArray(r) ? r : [r]).map(c => c === null ? "" : c));
        const m = {};
        for (const i of field.checked ?? [])
            m[i] = true;
        marked = m;
        const p = {};
        for (const i of field.selected ?? [])
            p[i] = true;
        picked = p;
        const first = (field.selected ?? [])[0];
        if (first !== undefined)
            Qt.callLater(() => cursor = Math.max(0, shown.indexOf(first)));
    }

    // update 的 append：追加列（串流讀入資料時）。參數是列的陣列，或 { rows, checked }
    // （checked 是這批裡要勾選的列號，從 0 起算）。
    function append(x) {
        const batch = JSON.parse(JSON.stringify(Array.isArray(x) ? x : (x.rows ?? [])));
        const base = rows.length;
        rows = rows.concat(batch.map(r => (Array.isArray(r) ? r : [r]).map(c => c === null ? "" : c)));
        const checked = Array.isArray(x) ? [] : (x.checked ?? []);
        if (checked.length > 0) {
            const m = mode === "radio" ? {} : Object.assign({}, marked);
            for (const i of checked)
                m[base + i] = true;
            marked = m;
        }
    }

    function moveCursor(pos, extend) {
        if (shown.length === 0)
            return;
        cursor = Math.max(0, Math.min(shown.length - 1, pos));
        if (mode === "multiple") {
            if (extend)
                selectRange(rangeAnchor, cursor);
            else {
                rangeAnchor = cursor;
                const p = {};
                p[shown[cursor]] = true;
                picked = p;
            }
        }
    }
    function selectRange(a, b) {
        const p = {};
        for (let k = Math.min(a, b); k <= Math.max(a, b); k++)
            p[shown[k]] = true;
        picked = p;
    }
    function toggle(pos) {
        if (pos < 0 || pos >= shown.length)
            return;
        const i = shown[pos];
        if (mode === "check") {
            const m = Object.assign({}, marked);
            m[i] = !m[i];
            marked = m;
        } else if (mode === "radio") {
            const m = {};
            m[i] = true;
            marked = m;
        } else if (mode === "multiple") {
            const p = Object.assign({}, picked);
            p[i] = !p[i];
            picked = p;
        }
    }
    function clickRow(pos, modifiers) {
        if (mode === "none")
            return;
        if (mode === "multiple" && modifiers & Qt.ShiftModifier) {
            cursor = pos;
            selectRange(rangeAnchor, pos);
        } else if (mode === "multiple" && modifiers & Qt.ControlModifier) {
            cursor = pos;
            rangeAnchor = pos;
            toggle(pos);
        } else if (marker) {
            cursor = pos;
            toggle(pos);
        } else {
            moveCursor(pos, false);
        }
    }
    function activate() {
        if (shown.length === 0 && mode === "single")
            return root.body.accept();
        if (field.activate === "event")
            emitEvent("activate", shown.length > 0 ? shown[cursor] : -1);
        else
            root.body.accept();
    }

    function startEdit() {
        if (!field.editable || shown.length === 0)
            return;
        const col = [...Array(columnCount).keys()].find(k => typeOf(k) === "text" || typeOf(k) === "number");
        if (col === undefined)
            return;
        editRow = shown[cursor];
        editCol = col;
    }
    function commitEdit(text) {
        const r = rows.slice();
        r[editRow] = r[editRow].slice();
        r[editRow][editCol] = text;
        rows = r;
        editRow = -1;
        editCol = -1;
        view.forceActiveFocus();
    }
    function cancelEdit() {
        editRow = -1;
        editCol = -1;
        view.forceActiveFocus();
    }

    // fromSearch：從搜尋框轉來的按鍵（打字、退格交給搜尋框自己處理）。
    function handleKey(event, fromSearch) {
        const extend = !!(event.modifiers & Qt.ShiftModifier);
        const page = Math.max(1, Math.floor(view.height / rowHeight) - 1);
        switch (event.key) {
        case Qt.Key_Up:
            moveCursor(cursor - 1, extend);
            break;
        case Qt.Key_Down:
            moveCursor(cursor + 1, extend);
            break;
        case Qt.Key_PageUp:
            moveCursor(cursor - page, extend);
            break;
        case Qt.Key_PageDown:
            moveCursor(cursor + page, extend);
            break;
        case Qt.Key_Home:
            if (fromSearch)
                return;
            moveCursor(0, extend);
            break;
        case Qt.Key_End:
            if (fromSearch)
                return;
            moveCursor(shown.length - 1, extend);
            break;
        case Qt.Key_Space:
            if (fromSearch)
                return;
            toggle(cursor);
            break;
        case Qt.Key_F2:
            startEdit();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activate();
            break;
        case Qt.Key_Backspace:
            if (fromSearch || search.text === "")
                return;
            search.text = search.text.slice(0, -1);
            break;
        default:
            // 清單有焦點時直接打字：轉給搜尋框（像 GTK 的 typeahead）。
            if (fromSearch || !searchable || event.text === "" || event.text < " "
                    || event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
                return;
            search.text += event.text;
        }
        event.accepted = true;
    }

    // 欄寬：圖示欄固定，其他欄平分剩下的寬度。
    readonly property int markerWidth: marker ? 36 : 0
    readonly property int imageWidth: 40
    readonly property int imageCount: [...Array(columnCount).keys()].filter(k => typeOf(k) === "image").length
    function columnWidth(k, total) {
        if (typeOf(k) === "image")
            return imageWidth;
        const flex = columnCount - imageCount;
        return flex > 0 ? (total - markerWidth - imageCount * imageWidth) / flex : 0;
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 8

        DialogInput {
            theme: root.theme
            id: search
            visible: root.searchable
            Layout.fillWidth: true
            placeholder: I18n.tr("輸入文字篩選")
            glyph: "" // search
            keyHandler: event => root.handleKey(event, true)
            onTextChanged: root.query = text
        }

        // 欄位標題
        Row {
            visible: !root.field.hideHeader && root.columns.length > 0
            Layout.fillWidth: true
            leftPadding: root.markerWidth

            Repeater {
                model: root.columnCount
                Text {
                    required property int index
                    width: root.columnWidth(index, view.width)
                    leftPadding: 12
                    rightPadding: 8
                    elide: Text.ElideRight
                    horizontalAlignment: root.typeOf(index) === "number" ? Text.AlignRight : Text.AlignLeft
                    text: root.columns[index] ?? ""
                    color: theme.dim
                    font.family: Theme.uiFontFamily
                    font.pixelSize: Theme.fontPx(13)
                    font.bold: true
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.max(1, Math.min(root.shown.length, root.field.visibleRows ?? 8)) * root.rowHeight
            Layout.minimumHeight: root.rowHeight * Math.min(3, Math.max(1, root.shown.length))

            ListView {
                id: view
                anchors.fill: parent
                anchors.rightMargin: 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.shown.length
                activeFocusOnTab: true
                Keys.onPressed: event => root.handleKey(event, false)

                Text {
                    visible: root.shown.length === 0
                    anchors.centerIn: parent
                    text: root.rows.length === 0 ? I18n.tr("沒有項目") : I18n.tr("沒有符合的項目")
                    color: theme.dim
                    font.family: Theme.uiFontFamily
                    font.pixelSize: Theme.fontPx(15)
                }

                delegate: Rectangle {
                    id: rowItem
                    required property int index
                    readonly property int rowIndex: root.shown[index] ?? -1
                    readonly property var cells: root.rows[rowIndex] ?? []
                    readonly property bool isCursor: index === root.cursor
                    readonly property bool isSelected: root.mode === "single" ? isCursor
                        : root.mode === "multiple" ? !!root.picked[rowIndex] : false

                    width: view.width
                    height: root.rowHeight
                    radius: 8
                    color: isSelected ? theme.accent
                         : rowArea.containsMouse || (isCursor && root.mode !== "none") ? theme.surface
                         : "transparent"
                    // 多選／核取時，游標所在列加外框（選取色已經用掉了填色）。
                    border.width: isCursor && !isSelected && view.activeFocus ? 2 : 0
                    border.color: theme.accent

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.mode === "none" ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: mouse => {
                            root.clickRow(rowItem.index, mouse.modifiers);
                            if (!(root.focusTarget === search.input && search.input.activeFocus))
                                view.forceActiveFocus();
                        }
                        onDoubleClicked: mouse => {
                            if (root.field.editable) {
                                root.cursor = rowItem.index;
                                const col = Math.max(0, cellRow.childAt(mouse.x, 0)?.column ?? -1);
                                if (root.typeOf(col) === "text" || root.typeOf(col) === "number") {
                                    root.editRow = rowItem.rowIndex;
                                    root.editCol = col;
                                }
                            } else if (!root.marker) {
                                root.activate();
                            }
                        }
                    }

                    Row {
                        id: cellRow
                        anchors.fill: parent

                        Item {
                            visible: root.marker
                            width: root.markerWidth
                            height: parent.height
                            DialogCheckBox {
                                theme: root.theme
                                anchors.centerIn: parent
                                radio: root.mode === "radio"
                                checked: !!root.marked[rowItem.rowIndex]
                            }
                        }

                        Repeater {
                            model: root.columnCount

                            Item {
                                id: cell
                                required property int index
                                readonly property int column: index
                                readonly property var cellData: rowItem.cells[index] ?? ""
                                readonly property string type: root.typeOf(index)
                                readonly property bool editing: root.editRow === rowItem.rowIndex && root.editCol === index
                                readonly property color fg: rowItem.isSelected ? theme.accentFg : theme.fg

                                width: root.columnWidth(index, view.width)
                                height: rowItem.height

                                Text {
                                    visible: (cell.type === "text" || cell.type === "number") && !cell.editing
                                    anchors.fill: parent
                                    leftPadding: 12
                                    rightPadding: 8
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: cell.type === "number" ? Text.AlignRight : Text.AlignLeft
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    text: String(cell.cellData)
                                    color: cell.fg
                                    font.family: Theme.uiFontFamily
                                    font.pixelSize: Theme.fontPx(15)
                                }
                                IconImage {
                                    visible: cell.type === "image"
                                    anchors.centerIn: parent
                                    implicitSize: 24
                                    source: {
                                        const s = String(cell.cellData);
                                        if (cell.type !== "image" || s === "")
                                            return "";
                                        return s.startsWith("/") ? "file://" + s : Quickshell.iconPath(s, true);
                                    }
                                }
                                Rectangle {
                                    visible: cell.type === "progress"
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 12
                                    width: parent.width - 20
                                    height: 10
                                    radius: 5
                                    color: rowItem.isSelected ? Qt.darker(theme.accent, 1.3) : theme.track
                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(100, Number(cell.cellData) || 0)) / 100
                                        height: parent.height
                                        radius: parent.radius
                                        color: rowItem.isSelected ? theme.accentFg : theme.accent
                                    }
                                }
                                DialogInput {
                                    theme: root.theme
                                    visible: cell.editing
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    implicitHeight: 32
                                    onVisibleChanged: {
                                        if (visible) {
                                            text = String(cell.cellData);
                                            input.selectAll();
                                            input.forceActiveFocus();
                                        }
                                    }
                                    keyHandler: event => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            root.commitEdit(text);
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Escape) {
                                            root.cancelEdit();
                                            event.accepted = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            DialogScrollBar {
                theme: root.theme
                flickable: view
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }
        }
    }
}
