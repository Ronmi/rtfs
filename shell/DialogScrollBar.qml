// 對話框共用的細捲軸：放在 Flickable 旁邊，內容超出時才出現，可以拖曳或點軌道跳過去。
import QtQuick

Item {
    id: root

    // 配色（Theme.dialogDark／dialogLight），由使用的地方傳入；預設深色。
    property var theme: Theme.dialogDark

    required property Flickable flickable

    implicitWidth: 8
    visible: flickable.contentHeight > flickable.height + 1

    function scrollTo(y) {
        const range = height - handle.height;
        const ratio = range > 0 ? Math.max(0, Math.min(1, (y - handle.height / 2) / range)) : 0;
        flickable.contentY = ratio * (flickable.contentHeight - flickable.height);
    }

    Rectangle {
        id: handle
        width: parent.width
        radius: width / 2
        y: root.flickable.visibleArea.yPosition * root.height
        height: Math.max(24, root.flickable.visibleArea.heightRatio * root.height)
        color: theme.dim
        opacity: area.pressed || area.containsMouse ? 0.9 : 0.5
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onPressed: mouse => root.scrollTo(mouse.y)
        onPositionChanged: mouse => {
            if (pressed)
                root.scrollTo(mouse.y);
        }
    }
}
