// 狀態列的系統匣色塊（SANA 色底）：StatusNotifierItem 圖示。
// 左鍵啟動（只有選單的項目則開選單）、中鍵次要動作、右鍵或長按選單（觸控沒有右鍵）、滾輪交給程式。
// 右鍵選單自己畫（TrayMenu.qml），外觀跟其他面板一致。
// 窄螢幕（Theme.barCompact）時只顯示一個圖示，其他收進下拉清單（圖示＋名稱，手指也好點）。
// 顯示哪一個：有 NeedsAttention 的就挑最近變動的那個，否則挑所有圖示裡最近變動的（後蓋前）；
// 「變動」是出現、換圖示或換狀態（切換輸入法會換圖示，所以輸入法會被帶出來）。
import QtQuick
import QtQml
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Rectangle {
    id: root

    // Passive 是程式表示「目前不需要顯示」，跟 waybar 一樣隱藏。
    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive)
    readonly property bool collapsed: Theme.barCompact && items.length > 1

    // 每個圖示最後一次變動的序號（[{ item, tick }]，用遞增序號而不是時間，同一毫秒也分得出先後）。
    property var stamps: []
    property int tick: 0
    function touch(item) {
        tick++;
        stamps = stamps.filter(s => s.item !== item && SystemTray.items.values.includes(s.item))
            .concat([{ item: item, tick: tick }]);
    }
    function lastTick(item) {
        return stamps.find(s => s.item === item)?.tick ?? 0;
    }
    function latest(list) {
        return list.reduce((best, i) => best === null || lastTick(i) > lastTick(best) ? i : best, null);
    }
    readonly property var featured: latest(items.filter(i => i.status === Status.NeedsAttention)) ?? latest(items)
    readonly property var shownItems: collapsed ? [featured] : items

    // 看所有圖示（不是篩過的 items）：items 是新陣列，每次重算 delegate 都會重建、亂記一通。
    Instantiator {
        model: SystemTray.items
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIconChanged() {
                root.touch(modelData);
            }
            function onStatusChanged() {
                root.touch(modelData);
            }
            Component.onCompleted: root.touch(modelData)
        }
    }

    // 長按當右鍵（開選單）。Qt 預設 800ms 太久，GNOME 大約是 500ms。
    readonly property int holdInterval: 500

    // bar 上的圖示與下拉清單共用的點擊行為。
    function handleClick(item, button, menu) {
        if (button === Qt.MiddleButton)
            item.secondaryActivate();
        else if (button === Qt.RightButton || item.onlyMenu) {
            if (item.hasMenu)
                menu.open();
        } else
            item.activate();
    }

    // 沒有圖示時也顯示（色塊固定八個，SANA 色不能缺），最小是正方形。
    implicitWidth: Math.max(row.implicitWidth + 2 * 6, Theme.blockHeight)
    implicitHeight: Theme.blockHeight
    radius: Theme.blockRadius
    color: Colors.sana

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: root.shownItems

            delegate: Item {
                id: slot

                required property var modelData

                implicitWidth: 18
                implicitHeight: 18
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    anchors.fill: parent
                    source: slot.modelData.icon
                    implicitSize: 18
                }

                TrayMenu {
                    id: menu
                    anchorItem: slot
                    menu: slot.modelData.menu
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    // 處理了 pressAndHold，放開時就不會再送 clicked。
                    pressAndHoldInterval: root.holdInterval
                    onClicked: mouse => root.handleClick(slot.modelData, mouse.button, menu)
                    onPressAndHold: root.handleClick(slot.modelData, Qt.RightButton, menu)
                    onWheel: wheel => {
                        const horizontal = wheel.angleDelta.x !== 0;
                        slot.modelData.scroll(horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal);
                    }
                }

                // 選單開著時不顯示 tooltip，免得疊在選單上。
                Tooltip {
                    anchorItem: slot
                    shown: area.containsMouse && !menu.visible
                           && (slot.modelData.tooltipTitle || slot.modelData.title) !== ""

                    Column {
                        spacing: 2
                        Text {
                            text: slot.modelData.tooltipTitle || slot.modelData.title
                            color: Colors.shellFg
                            font.family: Theme.uiFontFamily
                            font.pixelSize: Theme.fontPx(14)
                            font.bold: slot.modelData.tooltipDescription !== ""
                        }
                        Text {
                            visible: text !== ""
                            // tooltip 描述可能含 HTML（SNI 規格允許），交給 Text 自動判斷。
                            text: slot.modelData.tooltipDescription
                            color: Colors.shellFg
                            font.family: Theme.uiFontFamily
                            font.pixelSize: Theme.fontPx(13)
                        }
                    }
                }
            }
        }

        // 收起時的下拉箭頭。
        Text {
            visible: root.collapsed
            anchors.verticalCenter: parent.verticalCenter
            text: overflow.visible ? "" : "" // expand_less / expand_more
            color: Colors.inkDark
            font.family: "Material Icons"
            font.pixelSize: Theme.blockFont.pixelSize + 4

            MouseArea {
                // 點擊範圍比箭頭本身大一點。
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: overflow.visible = !overflow.visible
            }
        }
    }

    // 收起來的其他圖示。點了先關清單；選單從色塊展開（清單已經關了）。
    PanelPopup {
        id: overflow
        anchorItem: root
        // 回到寬螢幕時圖示都回到 bar 上了。
        onVisibleChanged: if (visible && !root.collapsed) visible = false

        Column {
            width: 240
            spacing: 2

            Repeater {
                model: root.collapsed ? root.items.filter(i => i !== root.featured) : []

                delegate: Rectangle {
                    id: entry
                    required property var modelData

                    width: parent.width
                    height: 40
                    radius: 8
                    color: entryArea.containsMouse ? Colors.panelRaised : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            source: entry.modelData.icon
                            implicitSize: 22
                        }
                        MenuLabel {
                            width: parent.width - 22 - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: entry.modelData.tooltipTitle || entry.modelData.title || entry.modelData.id
                        }
                    }

                    TrayMenu {
                        id: entryMenu
                        anchorItem: root
                        menu: entry.modelData.menu
                    }

                    MouseArea {
                        id: entryArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        pressAndHoldInterval: root.holdInterval
                        onClicked: mouse => {
                            overflow.visible = false;
                            root.handleClick(entry.modelData, mouse.button, entryMenu);
                        }
                        onPressAndHold: {
                            overflow.visible = false;
                            root.handleClick(entry.modelData, Qt.RightButton, entryMenu);
                        }
                    }
                }
            }
        }
    }
}
