// 狀態列的時鐘色塊；點擊開啟時鐘面板（通知中心＋月曆）。
// 勿擾時前面顯示鈴鐺斜線；有未讀通知時後面顯示彩瑛紅圓點（跟 swaync 的未讀顏色一致）。
import QtQuick
import Quickshell

Rectangle {
    id: root

    // 窄螢幕時拿掉年份：年份後面接分隔符號（yyyy/MM/dd、yyyy年M月）就連分隔符號一起拿，
    // 否則拿掉前面的分隔符號（MM/dd/yyyy）。
    function withoutYear(format) {
        const leading = /y+[\/\-.年]/;
        return leading.test(format) ? format.replace(leading, "") : format.replace(/[\/\-.]?y+/, "");
    }

    implicitWidth: row.implicitWidth + 2 * Theme.blockPadding
    implicitHeight: Theme.blockHeight
    radius: Theme.blockRadius
    color: Colors.jihyo

    SystemClock {
        id: clock
        // 格式裡有秒才每秒更新（ss、s 都算；不在乎引號裡的字也被當成秒）。
        precision: Config.bar.clockFormat.includes("s") ? SystemClock.Seconds : SystemClock.Minutes
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: Notifications.dnd
            anchors.verticalCenter: parent.verticalCenter
            text: "" // bell-slash
            color: Colors.inkDark
            font.family: "FontAwesome"
            font.pixelSize: Theme.blockFont.pixelSize
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date,
                Theme.barCompact ? root.withoutYear(Config.bar.clockFormat) : Config.bar.clockFormat)
            color: Colors.inkDark
            font: Theme.blockFont
        }
        Rectangle {
            visible: Notifications.hasUnread
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: Colors.chaeyoung
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible = !popup.visible
    }

    // niri 快捷鍵（qs ipc call notifications toggleCenter）也能開關面板。
    Connections {
        target: Notifications
        function onToggleCenterRequested() {
            popup.visible = !popup.visible;
        }
    }

    ClockPopup {
        id: popup
        anchorItem: root
        today: clock.date
    }
}
