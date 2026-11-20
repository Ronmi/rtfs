// 一張通知卡片，彈出與通知中心共用。
// 配色沿用 swaync 的 TWICE 規則：依緊急程度填滿成員色（低 Sana、一般娜璉、緊急彩瑛紅配淺色字），
// 左側一條官方漸層色條（通知中心裡的卡片不顯示）。
// 點卡片執行預設動作（通常是打開程式）；其他動作是按鈕；支援的話可以直接回覆。
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

ClippingRectangle {
    id: root

    required property var notification
    // 左側官方漸層色條：彈出卡片有，通知中心列表裡的卡片不要（使用者偏好）。
    property bool showStrip: true
    // 按下關閉鈕時的動作；預設是關閉通知本身（從通知中心移除）。
    property var onCloseRequested: () => notification.dismiss()

    // 正在輸入回覆（彈出卡片用來暫停倒數）。
    readonly property bool replying: replyBox.visible

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property color fg: critical ? Colors.inkLight : Colors.inkDark
    readonly property color fgSoft: Qt.rgba(fg.r, fg.g, fg.b, 0.15)

    // "default" 是點通知本身的動作，不顯示成按鈕；"inline-reply" 由回覆框處理。
    readonly property var defaultAction: notification.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttonActions: notification.actions.filter(a =>
        a.identifier !== "default" && a.identifier !== "inline-reply")

    // 程式圖示可能是圖示名稱或檔案路徑。
    readonly property string appIconSource: {
        const icon = notification.appIcon;
        if (!icon)
            return "";
        if (icon.startsWith("/") || icon.includes("://"))
            return icon.startsWith("/") ? "file://" + icon : icon;
        return Quickshell.iconPath(icon, true);
    }

    function timeText() {
        const t = Notifications.receivedAt[notification.id];
        return t ? Qt.formatTime(t, "HH:mm") : "";
    }

    function sendReply() {
        const text = replyInput.text.trim();
        if (text === "")
            return;
        notification.sendInlineReply(text);
        replyInput.text = "";
        replyBox.visible = false;
    }

    width: 380
    implicitHeight: content.implicitHeight + 24
    radius: 10
    color: critical ? Colors.chaeyoung
         : notification.urgency === NotificationUrgency.Low ? Colors.sana
         : Colors.nayeon

    // 點卡片本身 = 預設動作。放在最底層，上面的按鈕、輸入框會先接到點擊。
    MouseArea {
        anchors.fill: parent
        enabled: root.defaultAction !== null
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.defaultAction.invoke()
    }

    // 左側官方漸層色條（ClippingRectangle 會把它裁成圓角）。
    Rectangle {
        id: strip
        visible: root.showStrip
        width: visible ? 6 : 0
        height: parent.height
        gradient: Gradient {
            GradientStop { position: 0; color: Colors.officialFrom }
            GradientStop { position: 1; color: Colors.officialTo }
        }
    }

    Column {
        id: content
        x: strip.width + 12
        y: 12
        width: parent.width - x - 12
        spacing: 4

        // 程式圖示、名稱、時間、關閉鈕
        Item {
            width: parent.width
            height: 20

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                IconImage {
                    visible: root.appIconSource !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    source: root.appIconSource
                    implicitSize: 16
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.notification.appName + (root.timeText() ? " · " + root.timeText() : "")
                    color: root.fg
                    opacity: 0.75
                    font.family: Theme.uiFontFamily
                    font.pixelSize: Theme.fontPx(12)
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: closeArea.containsMouse ? root.fgSoft : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "" // times
                    color: root.fg
                    font.family: "FontAwesome"
                    font.pixelSize: Theme.fontPx(12)
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.onCloseRequested()
                }
            }
        }

        Row {
            width: parent.width
            spacing: 10

            // 通知附帶的圖片（例如聯絡人頭像）。
            Image {
                id: picture
                visible: root.notification.image !== "" && status === Image.Ready
                width: visible ? 48 : 0
                height: 48
                source: root.notification.image
                sourceSize.width: 96
                sourceSize.height: 96
                fillMode: Image.PreserveAspectCrop
            }

            Column {
                width: parent.width - (picture.visible ? picture.width + parent.spacing : 0)
                spacing: 2

                Text {
                    width: parent.width
                    text: root.notification.summary
                    color: root.fg
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: Theme.uiFontFamily
                    font.pixelSize: Theme.fontPx(15)
                    font.bold: true
                }
                Text {
                    visible: text !== ""
                    width: parent.width
                    text: root.notification.body
                    // 有宣告支援 body markup，內文可能含 <b>、<i>、<a>。
                    textFormat: Text.StyledText
                    color: root.fg
                    linkColor: root.fg
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    font.family: Theme.uiFontFamily
                    font.pixelSize: Theme.fontPx(14)
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }
        }

        // 動作按鈕（含「回覆」）。
        Flow {
            visible: root.buttonActions.length > 0 || root.notification.hasInlineReply
            width: parent.width
            spacing: 6
            topPadding: 6

            Repeater {
                model: root.buttonActions
                delegate: CardButton {
                    required property var modelData
                    text: modelData.text
                    onClicked: modelData.invoke()
                }
            }
            CardButton {
                visible: root.notification.hasInlineReply && !replyBox.visible
                text: I18n.tr("回覆")
                onClicked: {
                    replyBox.visible = true;
                    replyInput.forceActiveFocus();
                }
            }
        }

        // 回覆框：Enter 送出、Esc 收起。
        Rectangle {
            id: replyBox
            visible: false
            width: parent.width
            height: 32
            radius: 8
            color: root.fgSoft

            TextInput {
                id: replyInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: root.fg
                selectionColor: root.fg
                selectedTextColor: root.color
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(14)
                onAccepted: root.sendReply()
                Keys.onEscapePressed: event => {
                    replyBox.visible = false;
                    event.accepted = true;
                }

                Text {
                    visible: replyInput.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.notification.inlineReplyPlaceholder || I18n.tr("輸入回覆，按 Enter 送出")
                    color: root.fg
                    opacity: 0.5
                    font: replyInput.font
                }
            }
        }
    }

    component CardButton: Rectangle {
        property alias text: label.text
        signal clicked

        width: label.implicitWidth + 20
        height: 28
        radius: 8
        color: area.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.25) : root.fgSoft

        Text {
            id: label
            anchors.centerIn: parent
            color: root.fg
            font.family: Theme.uiFontFamily
            font.pixelSize: Theme.fontPx(13)
            font.bold: true
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
