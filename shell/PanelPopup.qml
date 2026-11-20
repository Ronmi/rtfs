// 從 bar 色塊點擊展開的面板共用外框：朝螢幕內側展開、點面板以外任何地方或按 Esc 關閉、深藍底。
// 用法：PanelPopup { anchorItem: 色塊; 內容... }，開關用 visible。
//
// 不用 PopupWindow（xdg_popup grab）：在 niri v26.04 上，從 bar（layer-shell）彈出的 popup
// 點到其他視窗不會關閉，只有點桌面或 bar 才會（waybar 的 GTK 選單也一樣）。
// 改成打開時顯示一個蓋住整個螢幕的透明 layer-shell 視窗，面板畫在裡面；點到透明處就關閉。
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property Item anchorItem
    default property alias content: box.data

    visible: false
    screen: anchorItem.QsWindow.window?.screen ?? null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // 蓋在 bar 與所有視窗上面、不佔空間；開著時獨佔鍵盤（Esc、通知回覆才收得到）。
    // 用 Overlay 層：niri 依 Overlay → Top 的順序找獨佔鍵盤的 layer surface，
    // 放在 Top 會輸給同樣在 Top、也獨佔鍵盤的 kitty quick-access-terminal。
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "rtfs-panel"
    color: "transparent"

    // 色塊的水平中心（螢幕座標）。bar 橫跨整個螢幕寬度，所以 bar 視窗座標就是螢幕座標。
    // mapToItem 不會隨版面自動更新，所以每次打開時重算。
    property real anchorCenter: 0
    onVisibleChanged: {
        if (visible) {
            anchorCenter = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
            panel.forceActiveFocus();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    // 其他螢幕也各蓋一層透明視窗：點外接螢幕上的視窗或桌面也要能關閉面板。
    Variants {
        model: Quickshell.screens.filter(s => s !== root.screen)

        PanelWindow {
            required property var modelData

            screen: modelData
            visible: root.visible
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            // 鍵盤留給面板本身。
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "rtfs-panel-catcher"
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                onClicked: root.visible = false
            }
        }
    }

    // 面板用通知中心、fuzzel 同一個深藍（TWICE 配色的 PANEL_BG）。
    Rectangle {
        id: panel
        width: box.childrenRect.width + 32
        height: box.childrenRect.height + 32
        // 水平置中於色塊，但不超出螢幕左右邊（留 4px）。
        x: Math.max(4, Math.min(root.width - width - 4, root.anchorCenter - width / 2))
        // 朝螢幕內側（遠離 bar 的方向）展開，與 bar 之間留 6px。
        y: Theme.barAtBottom ? root.height - Theme.barHeight - height - 6 : Theme.barHeight + 6
        radius: 12
        color: Colors.panelBg

        focus: true
        Keys.onEscapePressed: root.visible = false

        // 吃掉面板上的點擊，免得穿透到背景被當成「點外面」。
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: box
            x: 16
            y: 16
        }
    }
}
