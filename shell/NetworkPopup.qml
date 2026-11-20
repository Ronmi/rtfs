// 網路面板（從 NetworkBlock 展開）：目前連線（Wi-Fi 名稱與訊號／有線網路）、介面、IP、閘道。
// IP／閘道 Quickshell.Networking 沒有提供，打開面板時才執行一次 ip -j 查詢。
import QtQuick
import Quickshell.Io
import Quickshell.Networking

PanelPopup {
    id: root

    required property var device
    required property var wifiNetwork

    readonly property int menuWidth: 300

    property string address: ""
    property string gateway: ""

    onVisibleChanged: if (visible && device) {
        address = "";
        gateway = "";
        ipQuery.running = true;
    }

    // 兩行 JSON：位址、預設路由（ip -j 自己會換行；略過空行）。
    Process {
        id: ipQuery
        command: ["sh", "-c", "ip -j -4 addr show dev \"$1\"; ip -j -4 route show default dev \"$1\"", "sh",
                  root.device?.name ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const [addrJson, routeJson] = text.split("\n").filter(l => l.trim() !== "");
                try {
                    const info = JSON.parse(addrJson)[0]?.addr_info?.[0];
                    root.address = info ? info.local + "/" + info.prefixlen : "";
                    root.gateway = JSON.parse(routeJson || "[]")[0]?.gateway ?? "";
                } catch (e) {
                    root.address = root.gateway = "";
                }
            }
        }
    }

    Column {
        width: root.menuWidth
        spacing: 6

        Row {
            spacing: 12
            leftPadding: 12

            MenuIcon {
                anchors.verticalCenter: parent.verticalCenter
                // wifi / lan / link_off
                text: !root.device ? "" : root.device.type === DeviceType.Wifi ? "" : ""
            }
            MenuLabel {
                anchors.verticalCenter: parent.verticalCenter
                width: root.menuWidth - 12 - 20 - parent.spacing
                elide: Text.ElideRight
                font.bold: true
                text: !root.device ? I18n.tr("目前沒有網路連線") : root.wifiNetwork ? root.wifiNetwork.name : I18n.tr("有線網路")
            }
        }

        Repeater {
            model: !root.device ? [] : [
                root.wifiNetwork ? [I18n.tr("訊號"), Math.round(root.wifiNetwork.signalStrength * 100) + "%"] : null,
                [I18n.tr("介面"), root.device.name],
                ["IP", root.address || "—"],
                [I18n.tr("閘道"), root.gateway || "—"]
            ].filter(r => r !== null)

            delegate: Row {
                required property var modelData
                spacing: 12
                leftPadding: 12 + 20 + 12 // 跟標題文字對齊

                MenuLabel {
                    width: 40
                    text: modelData[0]
                    color: Colors.shellDim
                }
                MenuLabel {
                    text: modelData[1]
                }
            }
        }
    }
}
