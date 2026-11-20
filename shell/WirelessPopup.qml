// 無線面板（從 WirelessBlock 展開，跟系統選單同樣的風格）。靠近 bar 的一端起依序是：
// Wi-Fi、藍牙、飛航模式開關；Wi-Fi 網路清單；已配對的藍牙裝置；網路設定、藍牙設定。
// 配對新的藍牙裝置需要 BlueZ agent（QuickShell 0.3.2 沒有），企業版 Wi-Fi、隱藏網路的設定也比較複雜，
// 這些交給 blueman-manager 和 nm-connection-editor。
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking

PanelPopup {
    id: root

    readonly property int menuWidth: 340

    // 正在輸入密碼的網路（清單裡那一列下面展開密碼欄）。
    property var pskNetwork: null
    // 最後一次連線失敗的網路名稱，顯示在清單上方。
    property string failedName: ""

    onVisibleChanged: if (!visible) {
        pskNetwork = null;
        failedName = "";
    }

    // 面板開著時才主動掃描 Wi-Fi，關掉就停，省電（GNOME 也是這樣）。
    Binding {
        when: Wireless.wifiDevice !== null
        target: Wireless.wifiDevice
        property: "scannerEnabled"
        value: root.visible
    }

    function clickNetwork(network) {
        failedName = "";
        if (network.connected)
            network.disconnect();
        else if (network.known || Wireless.isOpen(network))
            network.connect();
        else if (Wireless.needsPsk(network))
            pskNetwork = pskNetwork === network ? null : network;
        else
            openSettings(["nm-connection-editor"]);
    }

    function openSettings(command) {
        visible = false;
        Quickshell.execDetached(command);
    }

    Column {
        spacing: 8
        readonly property var sections: [
            root.toggles, root.separator1, root.wifiSection, root.separator2,
            root.bluetoothSection, root.separator3, root.settingsList
        ]
        children: Theme.barAtBottom ? sections.slice().reverse() : sections
    }

    // ===== 開關 =====
    property Item toggles: Grid {
        width: root.menuWidth
        columns: 2
        spacing: 8

        MenuTile {
            width: (root.menuWidth - parent.spacing) / 2
            visible: Wireless.wifiDevice !== null
            icon: Wireless.wifiOn ? "" : "" // wifi / wifi_off
            label: "Wi-Fi"
            checked: Wireless.wifiOn
            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
        }
        MenuTile {
            width: (root.menuWidth - parent.spacing) / 2
            visible: Wireless.hasBluetooth
            icon: Wireless.bluetoothOn ? "" : "" // bluetooth / bluetooth_disabled
            label: I18n.tr("藍牙")
            checked: Wireless.bluetoothOn
            onClicked: Wireless.setBluetooth(!Wireless.bluetoothOn)
        }
        MenuTile {
            width: (root.menuWidth - parent.spacing) / 2
            visible: Wireless.rfkillDevices.length > 0
            icon: Wireless.airplane ? "" : "" // airplanemode_active / airplanemode_inactive
            label: I18n.tr("飛航模式")
            checked: Wireless.airplane
            onClicked: Wireless.setAirplane(!Wireless.airplane)
        }
    }

    property Item separator1: MenuSeparator {
        width: root.menuWidth
        visible: root.wifiSection.visible
    }

    // ===== Wi-Fi 網路 =====
    property Item wifiSection: Column {
        visible: Wireless.wifiOn
        width: root.menuWidth
        spacing: 2

        MenuSectionTitle {
            text: I18n.tr("Wi-Fi 網路")
        }
        MenuLabel {
            visible: root.failedName !== ""
            width: parent.width
            leftPadding: 12
            wrapMode: Text.Wrap
            text: I18n.tr("無法連線到「%1」", root.failedName)
            color: Colors.jihyo
        }
        MenuLabel {
            visible: Wireless.wifiNetworks.length === 0
            leftPadding: 12
            topPadding: 6
            bottomPadding: 6
            text: I18n.tr("搜尋中…")
            color: Colors.shellDim
        }

        // 網路多的時候限制高度，可以用滾輪捲動。
        ListView {
            width: parent.width
            height: Math.min(contentHeight, 36 * 7)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Wireless.wifiNetworks
            delegate: Column {
                id: networkRow
                required property var modelData
                readonly property bool busy: modelData.state === ConnectionState.Connecting
                    || modelData.state === ConnectionState.Disconnecting
                width: ListView.view.width

                MenuEntry {
                    width: parent.width
                    icon: Wireless.signalIcon(networkRow.modelData.signalStrength)
                    label: networkRow.modelData.name + (networkRow.busy ? I18n.tr("　連線中…") : "")
                    // check / lock
                    trailing: networkRow.modelData.connected ? ""
                        : Wireless.isOpen(networkRow.modelData) ? "" : ""
                    onClicked: root.clickNetwork(networkRow.modelData)
                }

                // 密碼欄：Enter 連線、Esc 取消。
                DialogInput {
                    id: pskInput
                    visible: root.pskNetwork === networkRow.modelData
                    x: 12
                    width: parent.width - 24
                    password: true
                    placeholder: I18n.tr("密碼（Enter 連線）")
                    onVisibleChanged: if (visible) {
                        text = "";
                        input.forceActiveFocus();
                    }
                    keyHandler: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (text !== "") {
                                networkRow.modelData.connectWithPsk(text);
                                root.pskNetwork = null;
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.pskNetwork = null;
                            event.accepted = true;
                        }
                    }
                }

                // 連線失敗：缺密碼或密碼錯就重新展開密碼欄，其他原因只顯示訊息。
                Connections {
                    target: networkRow.modelData
                    function onConnectionFailed(reason) {
                        root.failedName = networkRow.modelData.name;
                        if (reason === ConnectionFailReason.NoSecrets && Wireless.needsPsk(networkRow.modelData))
                            root.pskNetwork = networkRow.modelData;
                    }
                }
            }
        }
    }

    property Item separator2: MenuSeparator {
        width: root.menuWidth
        visible: root.bluetoothSection.visible
    }

    // ===== 藍牙裝置 =====
    property Item bluetoothSection: Column {
        visible: Wireless.bluetoothOn
        width: root.menuWidth
        spacing: 2

        MenuSectionTitle {
            text: I18n.tr("藍牙裝置")
        }
        MenuLabel {
            visible: Wireless.pairedDevices.length === 0
            leftPadding: 12
            topPadding: 6
            bottomPadding: 6
            text: I18n.tr("沒有已配對的裝置")
            color: Colors.shellDim
        }
        Repeater {
            model: Wireless.pairedDevices
            delegate: MenuEntry {
                required property var modelData
                readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting
                    || modelData.state === BluetoothDeviceState.Disconnecting
                width: root.menuWidth
                icon: Wireless.deviceIcon(modelData)
                label: !busy ? modelData.name : modelData.connected ? I18n.tr("%1　斷線中…", modelData.name) : I18n.tr("%1　連線中…", modelData.name)
                trailing: modelData.connected ? "" : "" // check
                onClicked: {
                    if (modelData.connected)
                        modelData.disconnect();
                    else
                        modelData.connect();
                }
            }
        }
    }

    property Item separator3: MenuSeparator {
        width: root.menuWidth
    }

    // ===== 進階設定 =====
    property Item settingsList: Column {
        width: root.menuWidth
        spacing: 2

        MenuEntry {
            width: parent.width
            icon: "" // settings
            label: I18n.tr("網路設定…")
            onClicked: root.openSettings(["nm-connection-editor"])
        }
        MenuEntry {
            visible: Wireless.hasBluetooth
            width: parent.width
            icon: "" // settings
            label: I18n.tr("藍牙設定（配對新裝置）…")
            onClicked: root.openSettings(["blueman-manager"])
        }
    }
}
