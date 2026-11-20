// 所有 modal 對話框共用的外框：所有螢幕變暗，niri 聚焦的螢幕中央放一張深藍卡片。
// Esc 或點變暗的區域會發出 dismissed()（由使用者決定怎麼處理，通常是當成取消）。
// 用法：DialogFrame { onDismissed: ...; 內容... }，open()／close() 開關。
// 內容自己負責拿鍵盤焦點（例如輸入框）；沒有的話焦點在卡片上，Esc 一樣有效。
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    default property alias content: box.data
    property int cardWidth: 400
    // 卡片高度預設跟著內容；內容自己會撐滿可用高度的（例如 DialogBody）就由使用者指定。
    property real cardHeight: box.childrenRect.height + 48
    signal dismissed

    // 讓 OskWindow 在對話框開著時讓位給這裡的鍵盤（見 Osk.modals）。
    onVisibleChanged: Osk.modals += visible ? 1 : -1
    Component.onDestruction: if (visible) Osk.modals -= 1

    function open() {
        // 開啟當下決定螢幕，之後不跟著變：niri 只把鍵盤焦點給聚焦螢幕上的 layer surface。
        screen = Quickshell.screens.find(s => s.name === Niri.focusedOutput)
            ?? ShellState.barScreen;
        visible = true;
        card.forceActiveFocus();
    }
    function close() {
        visible = false;
    }

    visible: false
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // 蓋在所有東西上面（包括 bar），不佔用空間，並獨佔鍵盤。
    // 要用 Overlay 層才贏得過同樣獨佔鍵盤的 kitty quick-access-terminal（Top 層）。
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "rtfs-dialog"
    color: Qt.rgba(0, 0, 0, 0.5)

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    // 其他螢幕也一起變暗，點了一樣算 dismissed（跟 PanelPopup 的做法相同）。
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
            // 鍵盤留給對話框本身。
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "rtfs-dialog-catcher"
            color: root.color

            MouseArea {
                anchors.fill: parent
                onClicked: root.dismissed()
            }

            DialogOskButton {}
        }
    }

    // 螢幕鍵盤畫在遮罩上面（OskWindow 被遮罩蓋住了），固定在底部、不透明、沒有半透明和翻轉鍵（使用者決定）。
    // 不拿鍵盤焦點也沒關係：按鍵經由 rtfs-vkbd 送到 niri，再交給擁有焦點的對話框。
    OskKeyboard {
        id: keyboard
        visible: Osk.shown
        viewControls: false
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: implicitHeight
    }

    // 扣掉鍵盤後的區域：卡片在這裡置中，按鈕在這裡的右下角，鍵盤打開時都不會被蓋住。
    Item {
        id: free
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: keyboard.visible ? keyboard.top : parent.bottom

        DialogOskButton {}
    }

    Rectangle {
        id: card
        anchors.centerIn: free
        width: Math.min(root.cardWidth, root.width - 32)
        height: Math.min(root.cardHeight, free.height - 32)
        radius: 16
        color: Colors.panelBg

        focus: true
        Keys.onEscapePressed: root.dismissed()

        // 吃掉卡片上的點擊，免得穿透到背景被當成取消。
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: box
            x: 24
            y: 24
            width: card.width - 48
            height: card.height - 48
        }
    }
}
