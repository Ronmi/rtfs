// polkit 驗證 agent（pkexec、systemctl 等需要管理員權限時的密碼視窗）。
// niri 下原本沒有任何 polkit agent；QuickShell 只在 niri 下啟動，GNOME 用它自己的 agent，不會衝突。
// 外觀用所有對話框共用的 DialogFrame／DialogButton。
// Esc、點變暗的區域、按「取消」都會取消這次驗證請求。
import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Item {
    id: root

    readonly property var flow: agent.flow
    // 等待輸入時才能操作；送出後到 polkit 回應前是「驗證中」。
    readonly property bool waiting: flow !== null && flow.isResponseRequired

    function submit() {
        if (!waiting)
            return;
        flow.submit(password.text);
        password.text = "";
    }

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            password.text = "";
            frame.open();
            password.forceActiveFocus();
        }
        // 驗證結束（成功、取消、對方收回請求）時 flow 變回 null。
        onIsActiveChanged: if (!isActive) frame.close()
    }

    // 密碼錯誤後 polkit 會再要求一次輸入：清空並重新聚焦。
    Connections {
        target: root.flow
        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired)
                password.forceActiveFocus();
        }
    }

    DialogFrame {
        id: frame
        cardWidth: 420
        onDismissed: root.flow?.cancelAuthenticationRequest()

        Column {
            width: parent.width
            spacing: 16

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "" // lock
                color: Colors.accent
                font.family: "FontAwesome"
                font.pixelSize: Theme.fontPx(36)
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: I18n.tr("需要驗證")
                color: Colors.shellFg
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(20)
                font.bold: true
            }
            // 要求驗證的程式提供的說明（polkit action 的訊息）。
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.flow?.message ?? ""
                color: Colors.shellFg
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(15)
            }

            // 可以用來驗證的帳號超過一個時才讓使用者選（例如 sudo 群組有多人）。
            Column {
                visible: (root.flow?.identities.length ?? 0) > 1
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.flow?.identities ?? []
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool selected: root.flow?.selectedIdentity === modelData

                        width: parent.width
                        height: 34
                        radius: 8
                        color: selected ? Colors.accent : idArea.containsMouse ? Colors.panelRaised : "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            text: (modelData.isGroup ? I18n.tr("群組：") : "") + (modelData.displayName || modelData.string)
                            color: parent.selected ? Colors.accentFg : Colors.shellFg
                            font.family: Theme.uiFontFamily
                            font.pixelSize: Theme.fontPx(14)
                        }
                        MouseArea {
                            id: idArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // 換帳號會中止目前的對話、重新開始（polkit 的行為）。
                            onClicked: root.flow.selectedIdentity = modelData
                        }
                    }
                }
            }

            // 密碼輸入框；提示文字用 polkit 給的（通常是「密碼：」）。
            Rectangle {
                width: parent.width
                height: 40
                radius: 10
                color: Colors.panelRaised
                opacity: root.waiting ? 1 : 0.6

                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    enabled: root.waiting
                    echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    color: Colors.shellFg
                    selectionColor: Colors.accent
                    selectedTextColor: Colors.accentFg
                    font.family: Theme.uiFontFamily
                    font.pixelSize: Theme.fontPx(15)
                    onAccepted: root.submit()
                    Keys.onEscapePressed: root.flow?.cancelAuthenticationRequest()

                    Text {
                        visible: password.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        // PAM 的提示通常是沒翻譯的「Password:」，換成中文；其他提示照原樣顯示。
                        text: !root.waiting ? I18n.tr("驗證中…")
                            : /^password:?\s*$/i.test(root.flow.inputPrompt) || !root.flow.inputPrompt ? I18n.tr("密碼")
                            : root.flow.inputPrompt
                        color: Colors.shellDim
                        font: password.font
                    }
                }
            }

            // 錯誤（例如密碼錯誤）用彩瑛紅；一般補充訊息用淡色。
            Text {
                visible: text !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.flow?.supplementaryMessage ?? ""
                color: root.flow?.supplementaryIsError ? Colors.chaeyoung : Colors.shellDim
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(14)
                font.bold: root.flow?.supplementaryIsError ?? false
            }

            Row {
                width: parent.width
                spacing: 12

                DialogButton {
                    width: (parent.width - parent.spacing) / 2
                    text: I18n.tr("取消")
                    onClicked: root.flow?.cancelAuthenticationRequest()
                }
                DialogButton {
                    width: (parent.width - parent.spacing) / 2
                    text: I18n.tr("驗證")
                    fill: Colors.accent
                    textColor: Colors.accentFg
                    isDefault: true
                    opacity: root.waiting ? 1 : 0.6
                    onClicked: root.submit()
                }
            }
        }
    }
}
