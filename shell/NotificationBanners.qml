// 新通知彈出的卡片：bar 正下方、水平置中（跟 GNOME 一樣），最多同時 3 張。
// 視窗只跟卡片一樣大，不會擋住其他地方的點擊。逾時只是收起彈出，通知仍留在通知中心。
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    // 跟 bar 放在同一個螢幕。
    screen: ShellState.barScreen
    visible: Notifications.banners.length > 0

    // 只錨定上緣：layer-shell 會把它水平置中。
    anchors.top: true
    // 尊重 bar 的保留區，所以自然出現在 bar 下方；自己不保留空間。
    exclusiveZone: 0
    margins.top: 6
    // 蓋在全螢幕視窗上面也看得到。
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rtfs-notifications"
    // 平常完全不拿鍵盤焦點。不能用 OnDemand：niri 會把焦點交給「剛出現」的 OnDemand surface，
    // 每次彈出通知都會搶走正在打字的程式的鍵盤。
    // 只有輸入回覆時改成獨佔：Overlay 層的獨佔優先於 Top 層（例如 kitty quick-access-terminal）。
    readonly property bool anyReplying: {
        for (let i = 0; i < cards.count; i++) {
            if (cards.itemAt(i)?.replying)
                return true;
        }
        return false;
    }
    WlrLayershell.keyboardFocus: anyReplying ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    implicitWidth: 380
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"

    Column {
        id: column
        spacing: 8

        Repeater {
            id: cards
            model: Notifications.banners

            delegate: NotificationCard {
                id: card
                required property var modelData
                notification: modelData
                // 在彈出卡片上按關閉 = 關閉通知本身（跟 swaync 一樣）。

                // 逾時收起；滑鼠停在卡片上或正在輸入回覆時暫停計時。
                Timer {
                    readonly property real seconds: Notifications.bannerTimeout(card.modelData)
                    running: seconds > 0 && !hover.containsMouse && !card.replying
                    interval: seconds * 1000
                    onTriggered: Notifications.hideBanner(card.modelData)
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }
}
