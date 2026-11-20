// 時鐘面板右欄：今天日期、可切換月份的月曆、開啟 gnome-calendar 的按鈕。
// 完整的行事曆（事件、待辦）交給 gnome-calendar，這裡只負責「看日期」。
// 月曆本身是跟對話框日曆 field 共用的 MonthView。
import QtQuick
import Quickshell

Column {
    id: root

    required property date today
    // 按下「開啟行事曆」後請面板關閉。
    signal closeRequested

    // 面板每次打開時回到本月。
    function reset() {
        month.showDate(today);
    }

    spacing: 12

    // 跟 GNOME 一樣，最上面是今天的完整日期。
    Text {
        text: root.today.toLocaleDateString(I18n.locale, I18n.tr("yyyy年M月d日 dddd"))
        color: Colors.shellFg
        font.family: Theme.uiFontFamily
        font.pixelSize: Theme.fontPx(18)
        font.bold: true
    }

    MonthView {
        id: month
        today: root.today
    }

    Rectangle {
        width: month.width
        height: 32
        radius: 8
        color: openArea.containsMouse ? Qt.lighter(Colors.mina, 1.1) : Colors.mina

        Text {
            anchors.centerIn: parent
            text: I18n.tr("開啟行事曆")
            color: Colors.inkDark
            font.family: Theme.uiFontFamily
            font.pixelSize: Theme.fontPx(14)
            font.bold: true
        }
        MouseArea {
            id: openArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["gnome-calendar"]);
                root.closeRequested();
            }
        }
    }
}
