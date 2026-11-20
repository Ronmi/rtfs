// 狀態列（取代 waybar），放在設定的螢幕（bar.output，預設第一個螢幕）上緣或下緣。
import QtQuick
import Quickshell

PanelWindow {
    id: bar

    // 設定讀完才顯示，免得先用預設位置出現再跳走。
    screen: ShellState.barScreen
    visible: Config.ready

    anchors {
        top: !Theme.barAtBottom
        bottom: Theme.barAtBottom
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    // 跟 waybar 一樣用淡淡的黑色遮罩，避免白色桌布上看不到大衛白的色塊。
    color: Qt.rgba(0, 0, 0, 0.1)

    // 官方漸層線，畫在朝向視窗的那一側。
    Rectangle {
        id: line
        anchors.left: parent.left
        anchors.right: parent.right
        y: Theme.barAtBottom ? 0 : parent.height - height
        height: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Colors.officialFrom }
            GradientStop { position: 1; color: Colors.officialTo }
        }
    }

    // 扣掉漸層線後，色塊在剩下的空間裡垂直置中。
    readonly property real contentOffset: Theme.barAtBottom ? line.height / 2 : -line.height / 2

    // 左側（跟 waybar 一樣：工作區…）
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: bar.contentOffset
        spacing: 4

        WorkspacesBlock {
            output: bar.screen?.name ?? ""
        }
        TemperatureBlock {}
        NetworkBlock {}
    }

    ClockBlock {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: bar.contentOffset
    }

    // 右側：系統匣、螢幕鍵盤、無線、系統選單。
    // 色塊顏色從最右邊的系統選單起往左依 TWICE 年齡順序：娜璉、定延、MOMO、SANA、志效（時鐘）、MINA、多賢、子瑜。
    // 八個色塊固定顯示、不提供開關，九人九色才不會缺。
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: bar.contentOffset
        spacing: 4

        TrayBlock {}
        OskBlock {}
        WirelessBlock {}
        SystemBlock {}
    }
}
