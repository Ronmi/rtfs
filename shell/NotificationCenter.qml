// 時鐘面板左欄：通知中心。依程式分組、新的在上面，太多時可以捲動；底部是勿擾開關與「清除全部」。
// 同一程式超過 1 則時有標題列（名稱、則數、清除這組），預設只顯示最新一則，「還有 N 則」可展開。
import QtQuick

Item {
    id: root

    readonly property var notifications: Notifications.list.slice().reverse()

    // [{ app, items }]：依程式名稱分組，組內新的在前；組的順序依最新一則（notifications 已經是新的在前）。
    readonly property var groups: {
        const order = [];
        const byApp = {};
        for (const n of notifications) {
            const app = n.appName || I18n.tr("未知程式");
            if (!byApp[app]) {
                byApp[app] = [];
                order.push(app);
            }
            byApp[app].push(n);
        }
        return order.map(app => ({ app: app, items: byApp[app] }));
    }

    // 已展開的組：{ 程式名稱: true }
    property var expanded: ({})

    function setExpanded(app, value) {
        const e = Object.assign({}, expanded);
        if (value)
            e[app] = true;
        else
            delete e[app];
        expanded = e;
    }

    implicitWidth: 380

    Text {
        id: title
        text: I18n.tr("通知")
        color: Colors.shellFg
        font.family: Theme.uiFontFamily
        font.pixelSize: Theme.fontPx(18)
        font.bold: true
    }

    Flickable {
        id: list
        anchors.top: title.bottom
        anchors.topMargin: 12
        anchors.bottom: footer.top
        anchors.bottomMargin: 12
        width: parent.width
        contentHeight: cards.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: cards
            width: parent.width
            spacing: 8

            Repeater {
                model: root.groups
                delegate: Column {
                    id: group
                    required property var modelData
                    readonly property bool multiple: modelData.items.length > 1
                    readonly property bool open: root.expanded[modelData.app] === true

                    width: cards.width
                    spacing: 6

                    // 標題列：程式名稱（則數）、收合、清除這組
                    Item {
                        visible: group.multiple
                        width: parent.width
                        height: 24

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("%1（%2）", group.modelData.app, group.modelData.items.length)
                            color: Colors.shellDim
                            font.family: Theme.uiFontFamily
                            font.pixelSize: Theme.fontPx(13)
                            font.bold: true
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            LinkButton {
                                visible: group.open
                                text: I18n.tr("收合")
                                onClicked: root.setExpanded(group.modelData.app, false)
                            }
                            LinkButton {
                                text: I18n.tr("清除")
                                onClicked: {
                                    for (const n of group.modelData.items.slice())
                                        n.dismiss();
                                }
                            }
                        }
                    }

                    Repeater {
                        model: group.open ? group.modelData.items : group.modelData.items.slice(0, 1)
                        delegate: NotificationCard {
                            required property var modelData
                            notification: modelData
                            showStrip: false
                        }
                    }

                    LinkButton {
                        visible: group.multiple && !group.open
                        text: I18n.tr("還有 %1 則", group.modelData.items.length - 1)
                        onClicked: root.setExpanded(group.modelData.app, true)
                    }
                }
            }
        }
    }

    // 沒有通知時
    Column {
        visible: root.notifications.length === 0
        anchors.centerIn: list
        spacing: 8
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "" // bell-o
            color: Colors.shellDim
            font.family: "FontAwesome"
            font.pixelSize: Theme.fontPx(40)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.tr("沒有通知")
            color: Colors.shellDim
            font.family: Theme.uiFontFamily
            font.pixelSize: Theme.fontPx(14)
        }
    }

    Item {
        id: footer
        anchors.bottom: parent.bottom
        width: parent.width
        height: 32

        // 勿擾開關：開啟時軌道用娜璉色（跟 swaync 一樣）。
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("勿擾")
                color: Colors.shellFg
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(14)
            }
            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 24
                radius: 12
                color: Notifications.dnd ? Colors.accent : Colors.panelRaised

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    y: 3
                    x: Notifications.dnd ? parent.width - width - 3 : 3
                    color: Notifications.dnd ? Colors.accentFg : Colors.shellFg
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.dnd = !Notifications.dnd
                }
            }
        }

        // 「清除全部」用 Mina 色（彩瑛紅太顯眼，跟 swaync 一樣）。
        Rectangle {
            visible: root.notifications.length > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: clearText.implicitWidth + 24
            height: 32
            radius: 8
            color: clearArea.containsMouse ? Qt.lighter(Colors.mina, 1.1) : Colors.mina

            Text {
                id: clearText
                anchors.centerIn: parent
                text: I18n.tr("清除全部")
                color: Colors.inkDark
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(14)
                font.bold: true
            }
            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.clearAll()
            }
        }
    }

    // 面板上的文字按鈕（不搶眼的次要操作）。
    component LinkButton: Rectangle {
        property alias text: label.text
        signal clicked

        width: label.implicitWidth + 16
        height: 24
        radius: 6
        color: area.containsMouse ? Colors.panelRaised : "transparent"

        Text {
            id: label
            anchors.centerIn: parent
            color: Colors.shellDim
            font.family: Theme.uiFontFamily
            font.pixelSize: Theme.fontPx(13)
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
