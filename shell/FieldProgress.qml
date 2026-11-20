// 進度條 field（zenity --progress、kdialog --progressbar、yad --progress／BAR）。
// spec：value（0–100）、pulsate（不確定進度時來回跑）、text（進度條下方的小字，例如剩餘時間）。沒有值。
import QtQuick

DialogField {
    id: root

    readonly property real fraction: Math.max(0, Math.min(100, field.value ?? 0)) / 100
    readonly property bool pulsate: !!field.pulsate

    hasValue: false
    implicitWidth: 300
    implicitHeight: bar.height + (sub.visible ? sub.implicitHeight + 6 : 0)

    Rectangle {
        id: bar
        width: parent.width
        height: 12
        radius: 6
        color: theme.track
        clip: true

        Rectangle {
            visible: !root.pulsate
            width: parent.width * root.fraction
            height: parent.height
            radius: parent.radius
            color: theme.accent
            Behavior on width {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        // 不確定進度：一小段來回移動。
        Rectangle {
            id: pulse
            visible: root.pulsate
            width: parent.width / 4
            height: parent.height
            radius: parent.radius
            color: theme.accent

            SequentialAnimation on x {
                running: root.pulsate && root.visible
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0
                    to: bar.width - pulse.width
                    duration: 900
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    from: bar.width - pulse.width
                    to: 0
                    duration: 900
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    Text {
        id: sub
        visible: text !== ""
        anchors.top: bar.bottom
        anchors.topMargin: 6
        width: parent.width
        horizontalAlignment: Text.AlignRight
        text: root.field.text ?? ""
        color: theme.dim
        font.family: Theme.uiFontFamily
        font.pixelSize: Theme.fontPx(13)
    }
}
