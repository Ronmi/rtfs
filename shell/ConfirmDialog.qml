// GNOME 風格的確認對話框：「取消」和確認按鈕（彩瑛紅，給會丟失工作的動作用）。
// Esc 或點變暗的區域都算取消；不提供 Enter 快捷鍵，避免誤觸危險動作。
// 外框與按鈕是所有對話框共用的 DialogFrame／DialogButton。
// 用法：設定 title、message、confirmText，接 onAccepted，再 open()。
import QtQuick

DialogFrame {
    id: root

    property string title
    property string message
    property string confirmText: I18n.tr("確定")

    signal accepted

    cardWidth: 400
    onDismissed: close()

    Column {
        width: parent.width
        spacing: 16

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.title
            color: Colors.shellFg
            font.family: Theme.uiFontFamily
            font.pixelSize: Theme.fontPx(20)
            font.bold: true
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.message
            color: Colors.shellFg
            font.family: Theme.uiFontFamily
            font.pixelSize: Theme.fontPx(15)
        }

        Row {
            width: parent.width
            spacing: 12

            DialogButton {
                width: (parent.width - parent.spacing) / 2
                text: I18n.tr("取消")
                onClicked: root.close()
            }
            DialogButton {
                width: (parent.width - parent.spacing) / 2
                text: root.confirmText
                fill: Colors.chaeyoung
                textColor: Colors.inkLight
                onClicked: {
                    root.close();
                    root.accepted();
                }
            }
        }
    }
}
