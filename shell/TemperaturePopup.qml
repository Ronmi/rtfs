// 溫度色塊的詳細面板：CPU、風扇與機身、裝置三區，最下面切換電源設定檔。
// 內容與順序沿用 waybar 版 tooltip（使用者已認可），只改成分區排版。
import QtQuick
import Quickshell.Services.UPower

PanelPopup {
    id: root

    readonly property int contentWidth: 320

    function tempText(sensor) { return Math.round(sensor.temp) + "°C"; }
    // 超過門檻的數值改文字顏色：warning 志效黃、critical 彩瑛紅。
    function levelColor(level) { return level === 2 ? Colors.chaeyoung : level === 1 ? Colors.jihyo : Colors.shellFg; }

    Column {
        width: root.contentWidth
        spacing: 14

        // --- CPU ---
        Column {
            width: parent.width
            spacing: 8

            Item {
                width: parent.width
                height: pkgText.implicitHeight
                Heading {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CPU"
                }
                Text {
                    id: pkgText
                    anchors.right: parent.right
                    text: Sensors.packageSensor ? root.tempText(Sensors.packageSensor) : "—"
                    color: root.levelColor(Sensors.level(Sensors.packageSensor))
                    font.family: Theme.uiFontFamily
                    font.pixelSize: Theme.fontPx(28)
                    font.bold: true
                }
            }

            // 各核心：每列 4 個，編號淡色、溫度依門檻上色（門檻同 Package）。
            Grid {
                width: parent.width
                columns: 4
                rowSpacing: 4
                Repeater {
                    model: Sensors.cores
                    delegate: Row {
                        required property var modelData
                        width: root.contentWidth / 4
                        spacing: 6
                        Text {
                            width: 18
                            horizontalAlignment: Text.AlignRight
                            text: modelData.id
                            color: Colors.shellDim
                            font.family: Theme.uiFontFamily
                            font.pixelSize: Theme.fontPx(13)
                        }
                        Text {
                            text: Math.round(modelData.temp) + "°"
                            color: root.levelColor(Sensors.level({
                                temp: modelData.temp, warn: Sensors.barWarn, crit: Sensors.barCrit
                            }))
                            font.family: Theme.uiFontFamily
                            font.pixelSize: Theme.fontPx(14)
                        }
                    }
                }
            }

            Pairs {
                model: [
                    { label: I18n.tr("平均頻率"), value: Sensors.freqMHz + " MHz" },
                    { label: I18n.tr("負載"), value: Sensors.load.join(" / ") }
                ]
            }
        }

        Divider {}

        // --- 風扇與機身（Framework EC）---
        Column {
            width: parent.width
            spacing: 8
            visible: Sensors.fanRpm >= 0 || Sensors.ecSensors.length > 0

            Heading { text: I18n.tr("風扇與機身") }
            Pairs {
                model: (Sensors.fanRpm >= 0 ? [{
                    label: I18n.tr("風扇"),
                    value: Sensors.fanMode ? I18n.tr("%1 rpm（%2）", Sensors.fanRpm, Sensors.fanMode) : Sensors.fanRpm + " rpm"
                }] : []).concat(Sensors.ecSensors.map(s => ({
                    label: s.name, value: root.tempText(s), level: Sensors.level(s)
                })))
            }
        }

        Divider {}

        // --- 其他裝置 ---
        Column {
            width: parent.width
            spacing: 8

            Heading { text: I18n.tr("裝置") }
            Pairs {
                model: Sensors.deviceSensors.map(s => ({
                    label: s.name, value: root.tempText(s), level: Sensors.level(s)
                })).concat(isNaN(Sensors.powerDraw) ? [] : [{
                    label: I18n.tr("耗電"), value: Sensors.powerDraw.toFixed(1) + " W"
                }])
            }
        }

        // power-profiles-daemon 還沒起來時整區不顯示（見 PowerProfileState）。
        Divider { visible: PowerProfileState.ready }

        // --- 電源設定檔 ---
        Column {
            visible: PowerProfileState.ready
            width: parent.width
            spacing: 8

            Heading { text: I18n.tr("電源設定檔") }
            Row {
                id: profiles
                width: parent.width
                spacing: 6

                readonly property var items: [
                    { profile: PowerProfile.PowerSaver, icon: "", label: I18n.tr("省電") },
                    { profile: PowerProfile.Balanced, icon: "", label: I18n.tr("平衡") }
                ].concat(PowerProfileState.hasPerformanceProfile
                    ? [{ profile: PowerProfile.Performance, icon: "", label: I18n.tr("效能") }] : [])

                Repeater {
                    model: profiles.items
                    delegate: Rectangle {
                        id: button
                        required property var modelData
                        readonly property bool selected: PowerProfileState.profile === modelData.profile

                        width: (profiles.width - profiles.spacing * (profiles.items.length - 1)) / profiles.items.length
                        height: 32
                        radius: 8
                        // 目前的設定檔用娜璉色填色；其他用面板上的按鈕色。
                        color: selected ? Colors.accent
                             : area.containsMouse ? Qt.lighter(Colors.panelRaised, 1.4)
                             : Colors.panelRaised

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: button.modelData.icon
                                color: button.selected ? Colors.accentFg : Colors.shellFg
                                font.family: "FontAwesome"
                                font.pixelSize: Theme.fontPx(14)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: button.modelData.label
                                color: button.selected ? Colors.accentFg : Colors.shellFg
                                font.family: Theme.uiFontFamily
                                font.pixelSize: Theme.fontPx(14)
                                font.bold: button.selected
                            }
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerProfileState.set(button.modelData.profile)
                        }
                    }
                }
            }
        }
    }

    component Heading: Text {
        color: Colors.shellDim
        font.family: Theme.uiFontFamily
        font.pixelSize: Theme.fontPx(13)
        font.bold: true
    }

    component Divider: Rectangle {
        width: root.contentWidth
        height: 1
        color: Colors.panelRaised
    }

    // 「標籤 數值」兩欄一組、每列兩組的表格。model：[{ label, value, level? }]
    component Pairs: Grid {
        id: pairs
        property alias model: rep.model
        width: root.contentWidth
        columns: 2
        rowSpacing: 4
        Repeater {
            id: rep
            delegate: Item {
                required property var modelData
                width: root.contentWidth / 2
                height: valueText.implicitHeight
                Text {
                    text: modelData.label
                    color: Colors.shellDim
                    font.family: Theme.uiFontFamily
                    font.pixelSize: Theme.fontPx(14)
                }
                Text {
                    id: valueText
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    text: modelData.value
                    color: root.levelColor(modelData.level ?? 0)
                    font.family: Theme.uiFontFamily
                    font.pixelSize: Theme.fontPx(14)
                }
            }
        }
    }
}
