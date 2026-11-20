// 可切換月份的月曆（時鐘面板的 CalendarView 和對話框的日曆 field 共用）。
// selectable 為 true 時可以點選日期：選取的日期用娜璉色實心圓，今天改成外框圓；
// 不可選時只標出今天（實心圓）。配色用對話框的配色角色（theme）。
import QtQuick
import QtQuick.Controls

Column {
    id: root

    property var theme: Theme.dialogDark
    property date today: new Date()
    property bool selectable: false
    property date selected: today
    signal picked(date day)
    // 雙擊日期（對話框用來觸發預設按鈕）。
    signal activated(date day)

    // 目前顯示的月份。
    property int shownYear: today.getFullYear()
    property int shownMonth: today.getMonth()


    function showDate(d) {
        shownYear = d.getFullYear();
        shownMonth = d.getMonth();
    }
    function shiftMonth(delta) {
        showDate(new Date(shownYear, shownMonth + delta, 1));
    }
    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    spacing: 12

    // 月份標題與切換箭頭
    Item {
        width: grid.width
        height: 28

        NavButton {
            anchors.left: parent.left
            text: "‹"
            onClicked: root.shiftMonth(-1)
        }
        Text {
            anchors.centerIn: parent
            text: new Date(root.shownYear, root.shownMonth, 1).toLocaleDateString(I18n.locale, I18n.tr("yyyy年M月"))
            color: root.theme.fg
            font.family: Theme.uiFontFamily
            font.pixelSize: Theme.fontPx(15)
            font.bold: true
        }
        NavButton {
            anchors.right: parent.right
            text: "›"
            onClicked: root.shiftMonth(1)
        }
    }

    DayOfWeekRow {
        width: grid.width
        locale: I18n.locale
        delegate: Text {
            required property string narrowName
            text: narrowName
            horizontalAlignment: Text.AlignHCenter
            color: root.theme.dim
            font.family: Theme.uiFontFamily
            font.pixelSize: Theme.fontPx(13)
        }
    }

    MonthGrid {
        id: grid
        width: 7 * 36
        year: root.shownYear
        month: root.shownMonth
        locale: I18n.locale
        spacing: 0

        delegate: Item {
            id: cell
            required property date date
            required property int day
            required property int month
            required property bool today
            readonly property bool isSelected: root.selectable && root.sameDay(date, root.selected)
            // 成員色當填色，不當文字色：實心圓配深色字。
            readonly property bool filled: isSelected || (today && !root.selectable)
            implicitWidth: 36
            implicitHeight: 32

            Rectangle {
                anchors.centerIn: parent
                width: 30
                height: 30
                radius: 15
                visible: cell.filled || cell.today || dayArea.containsMouse
                color: cell.filled ? root.theme.accent : dayArea.containsMouse ? root.theme.surface : "transparent"
                border.width: cell.today && !cell.filled ? 2 : 0
                border.color: root.theme.accent
            }
            Text {
                anchors.centerIn: parent
                text: cell.day
                color: cell.filled ? root.theme.accentFg
                     : cell.month === grid.month ? root.theme.fg
                     : root.theme.dim
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(14)
                font.bold: cell.today
            }
            MouseArea {
                id: dayArea
                anchors.fill: parent
                enabled: root.selectable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selected = cell.date;
                    if (cell.month !== grid.month)
                        root.showDate(cell.date);
                    root.picked(cell.date);
                }
                onDoubleClicked: root.activated(cell.date)
            }
        }
    }

    // 只在這個檔案用到的小元件：月份切換箭頭。
    component NavButton: Rectangle {
        property alias text: label.text
        signal clicked

        width: 28
        height: 28
        radius: 14
        color: navArea.containsMouse ? root.theme.surface : "transparent"

        Text {
            id: label
            anchors.centerIn: parent
            color: root.theme.fg
            font.family: Theme.uiFontFamily
            font.pixelSize: Theme.fontPx(20)
        }
        MouseArea {
            id: navArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
