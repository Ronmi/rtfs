// bar 色塊共用的 hover 說明視窗（取代 waybar 的 tooltip）。
// 用法：在色塊裡放 Tooltip { anchorItem: 色塊; shown: hover 狀態; 內容... }
import QtQuick
import Quickshell

PopupWindow {
    id: root

    required property Item anchorItem
    property bool shown: false
    default property alias content: box.data

    // 跟月曆面板一樣朝螢幕內側長出。
    anchor.item: anchorItem
    anchor.edges: Theme.barAtBottom ? Edges.Top : Edges.Bottom
    anchor.gravity: Theme.barAtBottom ? Edges.Top : Edges.Bottom

    // 稍微延遲再顯示，滑鼠只是經過時不會閃一下。
    visible: delay.ready && shown
    onShownChanged: {
        delay.ready = false;
        if (shown)
            delay.restart();
    }
    Timer {
        id: delay
        property bool ready: false
        interval: 300
        onTriggered: ready = true
    }

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight + 6
    color: "transparent"

    // tooltip 用 kitty 深色（TWICE 配色的 SHELL_RAISED），跟 GTK tooltip 一致。
    Rectangle {
        id: frame
        y: Theme.barAtBottom ? 0 : 6
        implicitWidth: box.childrenRect.width + 20
        implicitHeight: box.childrenRect.height + 16
        radius: 8
        color: Colors.shellRaised

        Item {
            id: box
            x: 10
            y: 8
        }
    }
}
