// 無線狀態（Wi-Fi、藍牙、飛航模式）與顯示用的共用函式，給無線色塊（WirelessBlock、WirelessPopup）用。
// Wi-Fi 用 Quickshell.Networking（NetworkManager），藍牙用 Quickshell.Bluetooth（BlueZ）；
// 飛航模式 QuickShell 沒有提供，直接用 rfkill（/dev/rfkill 對登入中的使用者開放，不需要 root）。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: root

    // ===== 飛航模式（rfkill）=====
    // rfkill -J 的裝置清單：[{ id, type: "wlan"／"bluetooth"…, soft, hard: "blocked"／"unblocked" }]
    property var rfkillDevices: []
    // 所有無線裝置都被擋住才算飛航模式（跟 GNOME 一樣）。
    readonly property bool airplane: rfkillDevices.length > 0
        && rfkillDevices.every(d => d.soft === "blocked" || d.hard === "blocked")
    readonly property bool bluetoothBlocked: rfkillDevices.some(d => d.type === "bluetooth" && d.soft === "blocked")

    function setAirplane(on) {
        Quickshell.execDetached(["rfkill", on ? "block" : "unblock", "all"]);
    }

    Process {
        id: rfkillQuery
        command: ["rfkill", "-J"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.rfkillDevices = JSON.parse(text).rfkilldevices ?? [];
                } catch (e) {
                    root.rfkillDevices = [];
                }
            }
        }
    }
    // rfkill event 一啟動先印出每個裝置的現況，之後每次有變化印一行；收到就重新查一次完整清單。
    Process {
        running: true
        command: ["rfkill", "event"]
        stdout: SplitParser {
            onRead: rfkillDebounce.restart()
        }
    }
    Timer {
        id: rfkillDebounce
        interval: 100
        onTriggered: rfkillQuery.running = true
    }

    // ===== Wi-Fi =====
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool wifiOn: wifiDevice !== null && Networking.wifiEnabled && Networking.wifiHardwareEnabled
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null

    // 清單用：去掉隱藏 SSID（沒有名稱），已連線的排第一，再來是存過的，其餘依訊號強弱。
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values.filter(n => n.name !== "").sort((a, b) =>
        (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)) : []

    // Material Icons：訊號分 4 格（0～1）。
    function signalIcon(strength) {
        return strength >= 0.75 ? "" // signal_wifi_4_bar
             : strength >= 0.5 ? "" // network_wifi_3_bar
             : strength >= 0.25 ? "" // network_wifi_2_bar
             : ""; // network_wifi_1_bar
    }
    readonly property string wifiIcon: airplane ? "" // airplanemode_active
        : !wifiOn ? "" // wifi_off
        : wifiNetwork ? signalIcon(wifiNetwork.signalStrength)
        : "" // signal_wifi_0_bar
    readonly property string wifiText: airplane ? I18n.tr("飛航模式")
        : !wifiDevice ? I18n.tr("沒有 Wi-Fi")
        : !wifiOn ? I18n.tr("Wi-Fi 關閉")
        : wifiNetwork ? wifiNetwork.name : I18n.tr("未連線")

    // 需要輸入密碼的安全類型（個人版 WPA／WPA2／WPA3）；企業版（EAP）等其他類型交給 nm-connection-editor。
    function needsPsk(network) {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security);
    }
    function isOpen(network) {
        return [WifiSecurityType.Open, WifiSecurityType.Owe].includes(network.security);
    }

    // ===== 藍牙 =====
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: !bluetoothBlocked && (adapter?.enabled ?? false)
    readonly property var pairedDevices: adapter ? adapter.devices.values.filter(d => d.paired)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name)) : []
    readonly property var connectedDevices: pairedDevices.filter(d => d.connected)
    // 有藍牙硬體（BlueZ 看得到 adapter，或 rfkill 有藍牙裝置）才顯示藍牙的部分。
    readonly property bool hasBluetooth: adapter !== null || rfkillDevices.some(d => d.type === "bluetooth")

    function setBluetooth(on) {
        // 被 rfkill 擋住時 BlueZ 開不了；解除後 BlueZ 預設會自動開啟（AutoEnable）。
        if (on && bluetoothBlocked)
            Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
        else if (adapter)
            adapter.enabled = on;
    }

    // BlueZ 的裝置圖示名稱（freedesktop icon name）→ Material Icons。
    function deviceIcon(device) {
        const icon = device?.icon ?? "";
        return icon.startsWith("audio-head") ? "" // headphones
             : icon.startsWith("audio") ? "" // speaker
             : icon === "input-keyboard" ? "" // keyboard
             : icon === "input-mouse" ? "" // mouse
             : icon === "input-gaming" ? "" // sports_esports
             : icon === "phone" ? "" // smartphone
             : ""; // bluetooth
    }
}
