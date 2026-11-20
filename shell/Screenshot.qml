// 截圖（交給 niri 的截圖動作）。系統選單的截圖選項呼叫這裡。
// - 區域：niri 自己的選取介面（本來就出現在所有螢幕上）。
// - 整個螢幕：只有一個螢幕時直接截；多個螢幕時蓋上覆蓋層，點哪個螢幕就截哪個。
//   niri 的 ScreenshotScreen 只能截聚焦的螢幕，所以先把焦點移過去再截。
// - 視窗：蓋上覆蓋層，點哪個視窗就用視窗 id 截（不必移動焦點）。
//   點 bar 開選單時焦點已經跑到 bar 所在的螢幕，所以不能用「目前聚焦的視窗」。
// 截圖前先讓選單、覆蓋層從畫面上消失，才不會被截進去。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
    id: root

    // "" 沒開、"screen" 選螢幕、"window" 選視窗
    property string mode: ""
    // 覆蓋層打開時向 niri 查一次的視窗：[{ id, output, x, y, w, h }]，依上下層順序（上層在前）。
    property var windows: []

    // 參數與 niri msg action 的預設值相同。
    function region() {
        later({ Screenshot: { show_pointer: true, path: null } });
    }

    function screen() {
        if (Quickshell.screens.length > 1)
            mode = "screen";
        else
            later({ ScreenshotScreen: { write_to_disk: true, show_pointer: true, path: null } });
    }

    function window() {
        windows = [];
        mode = "window";
        Niri.query("Windows", reply => root.windows = root.visibleWindows(reply.Windows));
    }

    function cancel() {
        mode = "";
    }

    // 各螢幕目前顯示的工作區上、看得到的視窗。浮動視窗在一般視窗上面；
    // niri 不回報浮動視窗之間的上下順序，假設最近聚焦的在最上面。
    function visibleWindows(list) {
        const outputOf = {};
        for (const ws of Niri.workspaces)
            if (ws.is_active)
                outputOf[ws.id] = ws.output;
        return list
            .filter(w => outputOf[w.workspace_id] !== undefined && w.layout.tile_pos_in_workspace_view)
            .sort((a, b) => a.is_floating !== b.is_floating ? (a.is_floating ? -1 : 1)
                : stamp(b) - stamp(a))
            .map(w => ({
                id: w.id,
                output: outputOf[w.workspace_id],
                x: w.layout.tile_pos_in_workspace_view[0],
                y: w.layout.tile_pos_in_workspace_view[1],
                w: w.layout.tile_size[0],
                h: w.layout.tile_size[1]
            }));
    }
    function stamp(w) {
        return w.focus_timestamp ? w.focus_timestamp.secs + w.focus_timestamp.nanos / 1e9 : 0;
    }

    // 螢幕上 (x, y) 處最上層的視窗，沒有就是 null。
    function windowAt(output, x, y) {
        return windows.find(w => w.output === output && x >= w.x && x < w.x + w.w && y >= w.y && y < w.y + w.h) ?? null;
    }

    function pickScreen(output) {
        mode = "";
        later([{ FocusMonitor: { output: output } },
               { ScreenshotScreen: { write_to_disk: true, show_pointer: true, path: null } }]);
    }

    function pickWindow(win) {
        mode = "";
        later({ ScreenshotWindow: { id: win.id, write_to_disk: true, show_pointer: false, path: null } });
    }

    // 等選單、覆蓋層消失再送出（一個動作或依序送出多個動作）。
    function later(actions) {
        delay.actions = Array.isArray(actions) ? actions : [actions];
        delay.restart();
    }
    Timer {
        id: delay
        property var actions: []
        interval: 200
        onTriggered: {
            for (const action of actions)
                Niri.send({ Action: action });
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData

            // 滑鼠下的視窗（選視窗時）
            property var hovered: null
            // 目前選中的範圍（選螢幕時是滑鼠所在的整個螢幕，選視窗時是滑鼠下的視窗）；寬度 0 表示沒有。
            readonly property rect target: root.mode === "screen"
                ? (pointer.containsMouse ? Qt.rect(0, 0, width, height) : Qt.rect(0, 0, 0, 0))
                : hovered ? Qt.rect(hovered.x, hovered.y, hovered.w, hovered.h) : Qt.rect(0, 0, 0, 0)

            screen: modelData
            visible: root.mode !== ""
            onVisibleChanged: {
                hovered = null;
                if (visible)
                    keys.forceActiveFocus();
            }
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            // 每個螢幕都要求鍵盤：niri 只給聚焦螢幕上的那一個，Esc 在那裡有效；其他螢幕用右鍵取消。
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "rtfs-screenshot"
            color: "transparent"

            // 選中的範圍保持原本亮度，其他地方變暗：用四塊圍住選中範圍的半透明矩形（沒有選中時下面那塊蓋滿全螢幕）。
            Item {
                anchors.fill: parent
                readonly property rect t: overlay.target
                readonly property color dim: Qt.rgba(0, 0, 0, 0.45)

                Rectangle { // 上
                    width: parent.width
                    height: parent.t.y
                    color: parent.dim
                }
                Rectangle { // 下
                    y: parent.t.y + parent.t.height
                    width: parent.width
                    height: parent.height - y
                    color: parent.dim
                }
                Rectangle { // 左
                    y: parent.t.y
                    width: parent.t.x
                    height: parent.t.height
                    color: parent.dim
                }
                Rectangle { // 右
                    x: parent.t.x + parent.t.width
                    y: parent.t.y
                    width: parent.width - x
                    height: parent.t.height
                    color: parent.dim
                }
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.cancel()
            }

            MouseArea {
                id: pointer
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onPositionChanged: mouse => {
                    if (root.mode === "window")
                        overlay.hovered = root.windowAt(overlay.modelData.name, mouse.x, mouse.y);
                }
                onExited: overlay.hovered = null
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.cancel();
                    } else if (root.mode === "screen") {
                        root.pickScreen(overlay.modelData.name);
                    } else {
                        const win = root.windowAt(overlay.modelData.name, mouse.x, mouse.y);
                        if (win)
                            root.pickWindow(win);
                    }
                }
            }

            // 外框：選螢幕時框住滑鼠所在的螢幕，選視窗時框住滑鼠下的視窗。
            GradientFrame {
                visible: overlay.target.width > 0
                x: overlay.target.x
                y: overlay.target.y
                width: overlay.target.width
                height: overlay.target.height
            }

            // 提示放在下方，不擋住大部分視窗。
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 48
                width: hint.implicitWidth + 32
                height: hint.implicitHeight + 20
                radius: 12
                color: Colors.panelBg

                Text {
                    id: hint
                    anchors.centerIn: parent
                    text: root.mode === "window" ? I18n.tr("點選要截圖的視窗・Esc 或右鍵取消") : I18n.tr("點選要截圖的螢幕・Esc 或右鍵取消")
                    color: Colors.shellFg
                    font.family: Theme.uiFontFamily
                    font.pixelSize: Theme.fontPx(15)
                }
            }
        }
    }

    // 官方漸層色的外框：上下兩條是水平漸層，左右兩條是漸層兩端的顏色。
    component GradientFrame: Item {
        readonly property int thickness: 4
        // 宣告在元件裡：inline component 看不到外層檔案的 id。
        readonly property Gradient official: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Colors.officialFrom }
            GradientStop { position: 1; color: Colors.officialTo }
        }

        Rectangle {
            width: parent.width
            height: parent.thickness
            gradient: parent.official
        }
        Rectangle {
            y: parent.height - height
            width: parent.width
            height: parent.thickness
            gradient: parent.official
        }
        Rectangle {
            width: parent.thickness
            height: parent.height
            color: Colors.officialFrom
        }
        Rectangle {
            x: parent.width - width
            width: parent.thickness
            height: parent.height
            color: Colors.officialTo
        }
    }
}
