// 全螢幕程式啟動器（GNOME app grid 風格，取代 fuzzel 的程式啟動）。
// 程式依名稱排序、分頁排列；觸控左右滑換頁、點圖示啟動；鍵盤直接打字搜尋、方向鍵移動、Enter 啟動。
// 每個螢幕都開一個，共用搜尋字、選取與頁數；每頁格子數相同、排列依螢幕形狀而定（見 layoutFor），放不下的螢幕顯示遮罩。
// niri 只把鍵盤焦點給聚焦螢幕上的 layer surface，所以在哪個螢幕上點，就把 niri 的焦點移到那個螢幕。
// 開關：open()／close()／toggle()，或 qs ipc call launcher toggle（niri 的 Mod+D）。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Singleton {
    id: root

    property bool shown: false
    // 啟動器跟 OskWindow 都在 Overlay 層、啟動器較晚出現，會蓋住它；
    // 跟 modal 一樣讓 OskWindow 讓位，螢幕鍵盤由啟動器自己畫（見 Osk.modals）。
    onShownChanged: Osk.modals += shown ? 1 : -1
    Component.onDestruction: if (shown) Osk.modals -= 1
    property string query: ""
    // 目前選取的程式在 results 裡的位置。
    property int selected: 0

    // 所有要顯示的程式，依名稱排序（中文依台灣習慣排序）。
    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name, "zh-TW"))

    // 搜尋：名稱、通用名稱、關鍵字、id 任一包含輸入的字（不分大小寫）。
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return apps;
        return apps.filter(e => [e.name, e.genericName, e.id].concat(e.keywords)
            .some(s => s && s.toLowerCase().includes(q)));
    }

    // 格子：所有螢幕每頁的格子數相同，頁數與「第幾頁有哪些程式」才能共用。
    // 每頁格子數由主螢幕（狀態列所在的螢幕）用原始格子大小決定；
    // 每個螢幕各自挑放得下這麼多格、格子最大的欄列排列（直立螢幕就排成直的），
    // 格子得縮到 minCellScale 以下才放得下的螢幕（例如長條螢幕）不顯示啟動器，改顯示遮罩。
    readonly property int baseCellWidth: 140
    readonly property int baseCellHeight: 132
    readonly property real minCellScale: 0.8
    readonly property ShellScreen mainScreen: ShellState.barScreen
    readonly property int perPage: mainScreen
        ? Math.max(1, Math.floor((mainScreen.width - 160) / baseCellWidth))
          * Math.max(1, Math.floor((mainScreen.height - 260) / baseCellHeight))
        : 1
    readonly property int pageCount: Math.max(1, Math.ceil(results.length / perPage))

    // 這個螢幕的排列：{ columns, rows, scale }。格子倍率一樣時選空格少的。
    function layoutFor(screen) {
        let best = { columns: 1, rows: perPage, scale: 0 };
        for (let c = 1; c <= perPage; c++) {
            const r = Math.ceil(perPage / c);
            const s = Math.min((screen.width - 160) / (c * baseCellWidth),
                               (screen.height - 260) / (r * baseCellHeight));
            if (s > best.scale + 1e-9 || (Math.abs(s - best.scale) < 1e-9 && c * r < best.columns * best.rows))
                best = { columns: c, rows: r, scale: s };
        }
        return best;
    }
    // 這個螢幕顯示啟動器（否則顯示遮罩）。主螢幕一律顯示，所以至少有一個螢幕能用。
    function isActive(screen) {
        // 螢幕拔掉或轉向時 delegate 銷毀前 modelData 會先變成 null。
        if (!screen)
            return false;
        if (screen === mainScreen)
            return true;
        if (Config.launcher.excludeOutputs.includes(screen.name))
            return false;
        return layoutFor(screen).scale >= minCellScale;
    }
    // 目前顯示的頁數，所有螢幕一起翻。
    property int page: 0

    function select(i) {
        if (results.length === 0)
            return;
        selected = Math.max(0, Math.min(results.length - 1, i));
        page = Math.floor(selected / perPage);
    }
    function goToPage(p) {
        page = Math.max(0, Math.min(pageCount - 1, p));
        selected = Math.min(results.length - 1, page * perPage);
    }

    // screen：從哪個螢幕開的（overview 的「所有程式」按鈕），就把 niri 的焦點移過去，鍵盤才會在那裡。
    // 那個螢幕（或目前聚焦的螢幕）只顯示遮罩的話，焦點改到主螢幕。
    function open(screen) {
        query = "";
        selected = 0;
        page = 0;
        const s = screen ?? Quickshell.screens.find(x => x.name === Niri.focusedOutput);
        if (s && isActive(s))
            focusScreen(s);
        else if (mainScreen)
            focusScreen(mainScreen);
        shown = true;
    }
    function close() {
        shown = false;
        menuEntry = null;
        infoEntry = null;
    }
    // 在某個螢幕上操作：niri 焦點移過去，別的螢幕上開著的選單／資訊面板關掉。
    function focusScreen(screen) {
        if (Niri.focusedOutput !== screen.name)
            Niri.focusMonitor(screen.name);
        if (menuScreen !== screen.name) {
            menuEntry = null;
            infoEntry = null;
        }
    }

    // 右鍵選單（右鍵／長按／Menu 鍵）：.desktop 的附加動作，加上「程式資訊」。
    property var menuEntry: null
    property point menuPos
    property int menuIndex: 0
    // 選單（以及從選單開的資訊面板）顯示在哪個螢幕。
    property string menuScreen: ""
    readonly property var menuItems: menuEntry
        ? menuEntry.actions.map(a => ({ text: a.name, action: a }))
            .concat([{ text: I18n.tr("程式資訊"), action: null }])
        : []

    function openMenu(entry, pos, screenName) {
        infoEntry = null;
        menuEntry = entry;
        menuPos = pos;
        menuScreen = screenName;
        menuIndex = 0;
    }
    function activateMenu(i) {
        const item = menuItems[i];
        const entry = menuEntry;
        menuEntry = null;
        if (item.action)
            launch(entry, item.action);
        else
            showInfo(entry);
    }

    // 程式資訊面板；.desktop 檔路徑 QuickShell 沒提供，開面板時依 id 去 XDG 目錄找。
    property var infoEntry: null
    property string infoPath: ""

    function showInfo(entry) {
        infoEntry = entry;
        infoPath = "";
        findPath.running = false;
        findPath.command = ["sh", "-c", root.findPathScript, "sh", entry.id];
        findPath.running = true;
    }

    // 依 XDG 規範：desktop id 是 applications/ 底下的相對路徑把 / 換成 -，
    // 依 XDG_DATA_HOME、XDG_DATA_DIRS 的順序，第一個符合的檔案生效。
    readonly property string findPathScript: '
        IFS=:
        for d in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
            a="${d%/}/applications"
            [ -d "$a" ] || continue
            find "$a" -name "*.desktop" | while IFS= read -r f; do
                rel="${f#"$a"/}"
                if [ "$(printf %s "${rel%.desktop}" | tr / -)" = "$1" ]; then
                    printf "%s\\n" "$f"
                    exit 1
                fi
            done || exit 0
        done'

    Process {
        id: findPath
        stdout: StdioCollector {
            onStreamFinished: root.infoPath = text.trim()
        }
    }
    function toggle() {
        if (shown)
            close();
        else
            open();
    }

    // action：.desktop 的附加動作（DesktopAction），沒給就執行程式本身。
    function launch(entry, action) {
        const target = action ?? entry;
        // DesktopEntry.execute() 不處理 Terminal=true，這類程式交給設定的終端機（launcher.terminal）執行。
        if (entry.runInTerminal)
            Quickshell.execDetached(Config.launcher.terminal.split(/\s+/).filter(w => w).concat(target.command));
        else
            target.execute();
        close();
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }
    }

    // 每個螢幕一個；螢幕接上、拔掉時自動增減。
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData
            visible: root.shown && active
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            // 蓋在 bar 與所有視窗（包括 niri overview）上面；獨佔鍵盤（Overlay 層才贏得過 kitty quick-access-terminal）。
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "rtfs-launcher"
            // 面板深藍、半透明，看得出底下的桌面但文字仍好讀。
            color: Qt.rgba(Colors.panelBg.r, Colors.panelBg.g, Colors.panelBg.b, 0.92)

            onVisibleChanged: if (visible) search.forceActiveFocus()

            // 這個螢幕的欄列排列與格子倍率（見 root.layoutFor）。
            // 用 screen 而不是視窗寬高：視窗隱藏時寬高歸零，開啟時會經過 0→500→實際尺寸，
            // 每變一次格子就整批重建，開啟會慢上幾百毫秒。
            readonly property bool active: root.isActive(modelData)
            // 螢幕鍵盤開著時扣掉鍵盤高度再排，整頁程式都還看得到（只影響排列，不影響要不要顯示遮罩）。
            readonly property var layout: root.layoutFor({
                width: modelData?.width ?? 0,
                height: (modelData?.height ?? 0) - (hasKeyboard ? keyboard.implicitHeight : 0)
            })
            // 螢幕鍵盤只畫在 niri 聚焦的螢幕：按鍵經 rtfs-vkbd 送進 niri，只會到那個螢幕的啟動器。
            readonly property bool hasKeyboard: Osk.shown && Niri.focusedOutput === modelData?.name
            readonly property int columns: layout.columns
            readonly property int rows: layout.rows
            readonly property real cellScale: layout.scale
            readonly property real cellWidth: root.baseCellWidth * cellScale
            // 選單與資訊面板只畫在開啟它的螢幕上。
            readonly property bool ownsMenu: root.menuScreen === modelData?.name
            readonly property real cellHeight: root.baseCellHeight * cellScale

            // 鍵盤開選單：放在選取中的格子中央。
            function openMenuForSelected() {
                if (root.results.length === 0)
                    return;
                const i = root.selected - root.page * root.perPage;
                root.openMenu(root.results[root.selected],
                              Qt.point(pages.x + (i % columns + 0.5) * cellWidth,
                                       pages.y + (Math.floor(i / columns) + 0.5) * cellHeight),
                              modelData.name);
            }

            // 點空白處關閉。
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
                // 滾輪換頁（累積滿一格才換）。
                property real accum: 0
                onWheel: wheel => {
                    accum += wheel.angleDelta.y + wheel.angleDelta.x;
                    if (Math.abs(accum) >= 120) {
                        root.goToPage(root.page + (accum > 0 ? -1 : 1));
                        accum = 0;
                    }
                }
            }

            // 搜尋框：一直保有鍵盤焦點，方向鍵等操作也在這裡處理。
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 48
                width: 420
                height: 44
                radius: 22
                color: Colors.panelRaised

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: "" // search
                    color: Colors.shellDim
                    font.family: "FontAwesome"
                    font.pixelSize: Theme.fontPx(16)
                }

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 48
                    anchors.rightMargin: 18
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Colors.shellFg
                    selectionColor: Colors.accent
                    selectedTextColor: Colors.accentFg
                    font.family: Theme.uiFontFamily
                    font.pixelSize: Theme.fontPx(17)
                    text: root.query
                    onTextChanged: {
                        root.menuEntry = null;
                        root.query = text;
                        root.selected = 0;
                        root.page = 0;
                    }

                    Keys.onPressed: event => {
                        // 資訊面板開著：Esc／Enter 關掉它，其他鍵吃掉（不要改到背後的搜尋字）。
                        if (root.infoEntry) {
                            if ([Qt.Key_Escape, Qt.Key_Return, Qt.Key_Enter].includes(event.key))
                                root.infoEntry = null;
                            event.accepted = true;
                            return;
                        }
                        // 選單開著：上下選、Enter 執行、Esc 關；打字照常搜尋（會關掉選單）。
                        if (root.menuEntry) {
                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.menuEntry = null;
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.activateMenu(root.menuIndex);
                                break;
                            case Qt.Key_Up:
                                root.menuIndex = (root.menuIndex + root.menuItems.length - 1) % root.menuItems.length;
                                break;
                            case Qt.Key_Down:
                                root.menuIndex = (root.menuIndex + 1) % root.menuItems.length;
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
                            win.openMenuForSelected();
                            event.accepted = true;
                            return;
                        }
                        switch (event.key) {
                        case Qt.Key_Escape:
                            root.close();
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            if (root.results.length > 0)
                                root.launch(root.results[root.selected]);
                            break;
                        case Qt.Key_Left:
                            root.select(root.selected - 1);
                            break;
                        case Qt.Key_Right:
                            root.select(root.selected + 1);
                            break;
                        case Qt.Key_Up:
                            root.select(root.selected - win.columns);
                            break;
                        case Qt.Key_Down:
                            root.select(root.selected + win.columns);
                            break;
                        case Qt.Key_PageUp:
                            root.goToPage(root.page - 1);
                            break;
                        case Qt.Key_PageDown:
                            root.goToPage(root.page + 1);
                            break;
                        default:
                            return;
                        }
                        event.accepted = true;
                    }

                    Text {
                        visible: search.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("輸入名稱搜尋程式")
                        color: Colors.shellDim
                        font: search.font
                    }
                }
            }

            Text {
                visible: root.results.length === 0
                anchors.centerIn: parent
                text: I18n.tr("找不到符合的程式")
                color: Colors.shellDim
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(16)
            }

            // 分頁：水平 ListView，一頁一格，可以用觸控／滑鼠拖曳換頁。
            ListView {
                id: pages
                anchors.horizontalCenter: parent.horizontalCenter
                y: 132
                width: win.columns * win.cellWidth
                height: win.rows * win.cellHeight
                orientation: ListView.Horizontal
                snapMode: ListView.SnapOneItem
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 250
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                model: root.pageCount

                // 跟 root.page 雙向同步，所有螢幕一起翻頁。
                // 用手滑到別頁時，選取移到那一頁的第一個。
                onCurrentIndexChanged: {
                    if (currentIndex !== root.page)
                        root.goToPage(currentIndex);
                }
                Connections {
                    target: root
                    function onPageChanged() {
                        if (pages.currentIndex !== root.page)
                            pages.currentIndex = root.page;
                    }
                }

                delegate: Item {
                    id: page
                    required property int index
                    width: pages.width
                    height: pages.height

                    Grid {
                        columns: win.columns

                        Repeater {
                            model: root.results.slice(page.index * root.perPage, (page.index + 1) * root.perPage)

                            delegate: Item {
                                id: cell
                                required property var modelData
                                required property int index
                                readonly property int globalIndex: page.index * root.perPage + index
                                readonly property bool isSelected: globalIndex === root.selected

                                width: win.cellWidth
                                height: win.cellHeight

                                // 選取：娜璉色填色；滑鼠移過：面板按鈕色。
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 6 * win.cellScale
                                    radius: 16 * win.cellScale
                                    color: cell.isSelected ? Colors.accent
                                         : cellArea.containsMouse ? Colors.panelRaised
                                         : "transparent"
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8 * win.cellScale

                                    IconImage {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        implicitSize: Math.round(64 * win.cellScale)
                                        source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                                    }
                                    Text {
                                        width: win.cellWidth - 20 * win.cellScale
                                        horizontalAlignment: Text.AlignHCenter
                                        text: cell.modelData.name
                                        color: cell.isSelected ? Colors.accentFg : Colors.shellFg
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                        font.family: Theme.uiFontFamily
                                        font.pixelSize: Math.round(Theme.fontPx(14) * win.cellScale)
                                    }
                                }

                                MouseArea {
                                    id: cellArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton)
                                            menuHere(mouse);
                                        else
                                            root.launch(cell.modelData);
                                    }
                                    // 觸控（平板模式）沒有右鍵，用長按；長按後放開不會再觸發 clicked。
                                    onPressAndHold: mouse => menuHere(mouse)

                                    function menuHere(mouse) {
                                        root.selected = cell.globalIndex;
                                        root.openMenu(cell.modelData, mapToItem(null, mouse.x, mouse.y), win.modelData.name);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 頁數圓點（可點）。
            Row {
                visible: root.pageCount > 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: pages.bottom
                anchors.topMargin: 16
                spacing: 4

                Repeater {
                    model: root.pageCount
                    delegate: Item {
                        required property int index
                        width: 20
                        height: 20
                        Rectangle {
                            anchors.centerIn: parent
                            width: index === pages.currentIndex ? 10 : 8
                            height: width
                            radius: width / 2
                            color: index === pages.currentIndex ? Colors.accent : Colors.shellDim
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.goToPage(index)
                        }
                    }
                }
            }

            // 選單開著時，點選單外面只關選單（不關 launcher）。
            MouseArea {
                visible: root.menuEntry !== null && win.ownsMenu
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.menuEntry = null
            }

            Rectangle {
                id: menu
                visible: root.menuEntry !== null && win.ownsMenu
                // 放在點的位置右下方，超出螢幕就往內收。
                x: Math.min(root.menuPos.x, win.width - width - 8)
                y: Math.min(root.menuPos.y, free.height - height - 8)
                width: 260
                height: menuColumn.implicitHeight + 12
                radius: 12
                color: Colors.panelBg
                border.width: 1
                border.color: Colors.panelRaised

                Column {
                    id: menuColumn
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    Repeater {
                        model: root.menuItems

                        delegate: Column {
                            id: menuRow
                            required property var modelData
                            required property int index
                            width: menuColumn.width

                            // 附加動作與「程式資訊」之間的分隔線。
                            Item {
                                visible: menuRow.modelData.action === null && menuRow.index > 0
                                width: parent.width
                                height: 9
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 1
                                    color: Colors.panelRaised
                                }
                            }
                            Rectangle {
                                width: parent.width
                                height: 32
                                radius: 8
                                color: menuRow.index === root.menuIndex ? Colors.panelRaised : "transparent"

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    text: menuRow.modelData.text
                                    color: Colors.shellFg
                                    font.family: Theme.uiFontFamily
                                    font.pixelSize: Theme.fontPx(14)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: if (containsMouse) root.menuIndex = menuRow.index
                                    onClicked: root.activateMenu(menuRow.index)
                                }
                            }
                        }
                    }
                }
            }

            // 程式資訊：整理過的 .desktop 欄位；點外面、Esc、Enter 或「關閉」關掉。
            Rectangle {
                visible: root.infoEntry !== null && win.ownsMenu
                // 只蓋鍵盤以外的區域：鍵盤開著時照樣能用。
                anchors.fill: free
                color: Qt.rgba(0, 0, 0, 0.4)

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: root.infoEntry = null
                }

                Rectangle {
                    id: info
                    readonly property var entry: root.infoEntry
                    // 空的欄位不顯示。
                    readonly property var fields: entry ? [
                        ["ID", entry.id],
                        [I18n.tr("指令"), entry.execString],
                        [I18n.tr("工作目錄"), entry.workingDirectory],
                        [I18n.tr("終端機"), entry.runInTerminal ? I18n.tr("在終端機裡執行") : ""],
                        [I18n.tr("分類"), entry.categories.join(I18n.tr("、"))],
                        [I18n.tr("關鍵字"), entry.keywords.join(I18n.tr("、"))],
                        [I18n.tr("視窗類別"), entry.startupClass],
                        [I18n.tr("檔案"), findPath.running ? I18n.tr("尋找中…") : (root.infoPath || I18n.tr("找不到"))]
                    ].filter(f => f[1]) : []

                    anchors.centerIn: parent
                    width: Math.min(560, parent.width - 32)
                    height: infoColumn.implicitHeight + 48
                    radius: 16
                    color: Colors.panelBg
                    border.width: 1
                    border.color: Colors.panelRaised

                    // 吃掉面板上的點擊，不要穿到背後去關掉面板。
                    MouseArea {
                        anchors.fill: parent
                    }

                    Column {
                        id: infoColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 24
                        spacing: 16

                        Row {
                            spacing: 16
                            IconImage {
                                implicitSize: 64
                                source: info.entry ? Quickshell.iconPath(info.entry.icon, "application-x-executable") : ""
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: infoColumn.width - 80
                                spacing: 4
                                Text {
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    text: info.entry?.name ?? ""
                                    color: Colors.shellFg
                                    font.family: Theme.uiFontFamily
                                    font.pixelSize: Theme.fontPx(20)
                                    font.bold: true
                                }
                                Text {
                                    visible: text !== ""
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    text: info.entry?.genericName ?? ""
                                    color: Colors.shellDim
                                    font.family: Theme.uiFontFamily
                                    font.pixelSize: Theme.fontPx(14)
                                }
                            }
                        }

                        Text {
                            visible: text !== ""
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: info.entry?.comment ?? ""
                            color: Colors.shellFg
                            font.family: Theme.uiFontFamily
                            font.pixelSize: Theme.fontPx(14)
                        }

                        Column {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: info.fields
                                delegate: Row {
                                    id: fieldRow
                                    required property var modelData
                                    spacing: 16

                                    Text {
                                        id: fieldLabel
                                        width: 80
                                        text: fieldRow.modelData[0]
                                        color: Colors.shellDim
                                        font.family: Theme.uiFontFamily
                                        font.pixelSize: Theme.fontPx(14)
                                    }
                                    // 可以用滑鼠選取複製（例如指令、路徑）；不搶焦點，鍵盤仍留在搜尋框。
                                    TextEdit {
                                        width: infoColumn.width - fieldLabel.width - parent.spacing
                                        readOnly: true
                                        selectByMouse: true
                                        activeFocusOnPress: false
                                        wrapMode: TextEdit.Wrap
                                        text: fieldRow.modelData[1]
                                        color: Colors.shellFg
                                        selectionColor: Colors.accent
                                        selectedTextColor: Colors.accentFg
                                        font.family: Theme.uiFontFamily
                                        font.pixelSize: Theme.fontPx(14)
                                    }
                                }
                            }
                        }

                        DialogButton {
                            anchors.right: parent.right
                            text: I18n.tr("關閉")
                            onClicked: root.infoEntry = null
                        }
                    }
                }
            }

            // 螢幕鍵盤：跟 modal 一樣固定在底部、不透明、沒有半透明和翻轉鍵。
            OskKeyboard {
                id: keyboard
                visible: win.hasKeyboard
                viewControls: false
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: implicitHeight
            }

            // 扣掉鍵盤後的區域：開關按鈕在這裡的右下角，選單、資訊面板也不會被鍵盤蓋住。
            Item {
                id: free
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: keyboard.visible ? keyboard.top : parent.bottom

                DialogOskButton {}
            }

            // 在這個螢幕上按下滑鼠／觸控：先讓 niri 聚焦這個螢幕（之後打字、方向鍵都在這裡），
            // 不接受這個事件，按下照常傳給底下的格子、選單等。放在最後才會疊在最上面先收到。
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: mouse => {
                    root.focusScreen(win.modelData);
                    mouse.accepted = false;
                }
            }
        }
    }

    // 不顯示啟動器的螢幕（排列放不下，或設定排除的）：蓋一層遮罩，點一下關閉啟動器。
    // 不拿鍵盤焦點：鍵盤留給主螢幕或使用者操作中的螢幕上的啟動器。
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property ShellScreen modelData
            visible: root.shown && !root.isActive(modelData)
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "rtfs-launcher-mask"
            color: Qt.rgba(Colors.panelBg.r, Colors.panelBg.g, Colors.panelBg.b, 0.7)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: root.close()
            }

            DialogOskButton {}
        }
    }
}
