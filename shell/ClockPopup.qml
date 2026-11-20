// 時鐘的下拉面板（跟 GNOME 一樣）：左欄通知中心、右欄月曆。
import QtQuick

PanelPopup {
    id: root

    required property date today

    onVisibleChanged: {
        Notifications.centerOpen = visible;
        if (visible) {
            calendar.reset();
            Notifications.unread = false;
        }
    }

    Row {
        spacing: 16

        NotificationCenter {
            // 跟月曆一樣高；通知多時在裡面捲動。
            height: calendar.height
        }

        Rectangle {
            width: 1
            height: calendar.height
            color: Colors.panelRaised
        }

        CalendarView {
            id: calendar
            today: root.today
            onCloseRequested: root.visible = false
        }
    }
}
