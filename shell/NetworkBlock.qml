// 狀態列的網路色塊（MINA 色底）：連線類型圖示 ↓下載 ↑上傳速率；點擊開啟網路面板（SSID、訊號、IP）。
// 連線狀態用 Quickshell.Networking（NetworkManager）；速率它沒提供，改用 FileView 每 3 秒讀 /proc/net/dev。
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Rectangle {
    id: root

    readonly property int interval: Config.bar.interval.network

    // 目前使用的裝置：有線優先，其次 Wi-Fi。
    readonly property var devices: Networking.devices.values.filter(d => d.connected)
    readonly property var device: devices.find(d => d.type === DeviceType.Wired)
                                  ?? devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: device?.type === DeviceType.Wifi
                                       ? device.networks.values.find(n => n.connected) ?? null : null

    // 每秒位元組數；-1 表示還沒有兩次取樣可以相減。
    property real rxRate: -1
    property real txRate: -1
    property var lastSample: null // { dev, rx, tx }

    // 窄螢幕時單位只留字首（1.2k、3.4M），平常是 kB/s、MB/s。
    function unit(prefix) {
        return Theme.barCompact ? prefix : prefix === "B" ? "B/s" : prefix + "B/s";
    }

    function formatRate(bytesPerSec) {
        if (bytesPerSec < 0)
            return "—";
        if (bytesPerSec < 1000)
            return Math.round(bytesPerSec) + unit("B");
        if (bytesPerSec < 1000 * 1000)
            return (bytesPerSec / 1000).toFixed(1) + unit("k");
        return (bytesPerSec / 1000 / 1000).toFixed(1) + unit("M");
    }

    function sample(text) {
        const name = device?.name;
        const line = name ? text.split("\n").find(l => l.trim().startsWith(name + ":")) : undefined;
        if (!line) {
            rxRate = txRate = -1;
            lastSample = null;
            return;
        }
        // 「介面: 收 8 欄、送 8 欄」，第 1 欄是收到的位元組，第 9 欄是送出的位元組。
        const f = line.split(":")[1].trim().split(/\s+/).map(Number);
        const now = { dev: name, rx: f[0], tx: f[8] };
        if (lastSample?.dev === name) {
            rxRate = (now.rx - lastSample.rx) / interval;
            txRate = (now.tx - lastSample.tx) / interval;
        }
        lastSample = now;
    }

    FileView {
        id: netdev
        path: "/proc/net/dev"
        onLoaded: root.sample(text())
    }
    Timer {
        interval: root.interval * 1000
        running: true
        repeat: true
        onTriggered: netdev.reload()
    }

    implicitWidth: row.implicitWidth + 2 * Theme.blockPadding
    implicitHeight: Theme.blockHeight
    radius: Theme.blockRadius
    color: Colors.mina

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // wifi / sitemap（有線）/ chain-broken（離線）
            text: !root.device ? "" : root.device.type === DeviceType.Wifi ? "" : ""
            color: Colors.inkDark
            font.family: "FontAwesome"
            font.pixelSize: Theme.blockFont.pixelSize
            // 窄螢幕時省略（↓↑ 箭頭保留）。
            visible: !Theme.barCompact
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.device ? "↓" + root.formatRate(root.rxRate) + " ↑" + root.formatRate(root.txRate) : I18n.tr("離線")
            color: Colors.inkDark
            font: Theme.blockFont
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible = !popup.visible
    }

    NetworkPopup {
        id: popup
        anchorItem: root
        device: root.device
        wifiNetwork: root.wifiNetwork
    }
}
