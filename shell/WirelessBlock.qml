// 狀態列的無線色塊（定延色底）：Wi-Fi 圖示＋SSID（固定寬度，太長的截掉，完整名稱在面板裡）· 藍牙圖示＋已連線裝置數；
// 點擊開啟無線面板。
import QtQuick

Rectangle {
    id: root

    readonly property color fg: Colors.inkDark

    implicitWidth: row.implicitWidth + 2 * Theme.blockPadding
    implicitHeight: Theme.blockHeight
    radius: Theme.blockRadius
    color: Colors.jeongyeon

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        BarIcon {
            text: Wireless.wifiIcon
        }
        Text {
            visible: !Theme.barCompact
            anchors.verticalCenter: parent.verticalCenter
            // 固定寬度：SSID 長短不同時色塊不會伸縮。
            width: Theme.blockFont.pixelSize * 6
            elide: Text.ElideRight
            text: Wireless.wifiText
            color: root.fg
            font: Theme.blockFont
        }

        Text {
            visible: Wireless.hasBluetooth
            anchors.verticalCenter: parent.verticalCenter
            text: "·"
            color: root.fg
            opacity: 0.5
            font: Theme.blockFont
        }
        BarIcon {
            visible: Wireless.hasBluetooth
            // bluetooth_connected / bluetooth / bluetooth_disabled
            text: !Wireless.bluetoothOn ? "" : Wireless.connectedDevices.length > 0 ? "" : ""
        }
        Text {
            visible: Wireless.hasBluetooth && Wireless.bluetoothOn
            anchors.verticalCenter: parent.verticalCenter
            text: Wireless.connectedDevices.length
            color: root.fg
            font: Theme.blockFont
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible = !popup.visible
    }

    WirelessPopup {
        id: popup
        anchorItem: root
    }

    component BarIcon: Text {
        anchors.verticalCenter: parent.verticalCenter
        color: root.fg
        font.family: "Material Icons"
        font.pixelSize: Theme.blockFont.pixelSize + 4
    }
}
