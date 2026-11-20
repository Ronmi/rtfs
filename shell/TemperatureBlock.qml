// 狀態列的溫度色塊（多賢色底）：CPU Package 溫度 · 風扇轉速 · 電源設定檔；點擊開啟詳細面板。
import QtQuick

Rectangle {
    id: root

    // 電源設定檔 → Font Awesome 4.7 圖示（leaf / balance-scale / rocket）
    readonly property var profileIcons: ["", "", ""]

    readonly property int level: Sensors.level(Sensors.packageSensor)
    // 過熱時整塊換底色：warning 志效黃、critical 彩瑛紅（配淺色字）。
    readonly property color fg: level === 2 ? Colors.inkLight : Colors.inkDark

    implicitWidth: row.implicitWidth + 2 * Theme.blockPadding
    implicitHeight: Theme.blockHeight
    radius: Theme.blockRadius
    color: level === 2 ? Colors.chaeyoung : level === 1 ? Colors.jihyo : Colors.dahyun

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        // 讀不到 CPU 溫度（Sensors 認得 coretemp、k10temp、zenpower）時不顯示溫度，只剩風扇和電源設定檔。
        // 窄螢幕時省略溫度、風扇的圖示（數字有 ° 和 rpm 分得出來）；電源設定檔本身就是圖示，保留。
        Icon {
            visible: Sensors.packageSensor !== null && !Theme.barCompact
            text: "" // thermometer-half
        }
        Label {
            visible: Sensors.packageSensor !== null
            text: Sensors.packageSensor ? Math.round(Sensors.packageSensor.temp) + "°" : ""
        }

        // 有風扇資料就一直顯示（停轉時顯示 0 rpm），避免色塊時有時無。
        Separator { visible: Sensors.packageSensor !== null && Sensors.fanRpm >= 0 && !Theme.barCompact }
        Icon {
            visible: Sensors.fanRpm >= 0 && !Theme.barCompact
            text: "" // snowflake-o
        }
        Label {
            visible: Sensors.fanRpm >= 0
            text: Sensors.fanRpm + " rpm"
            // 預留 4 位數的寬度並靠右對齊，轉速變動時整個色塊不會跟著伸縮。
            // 字型的數字不一定等寬，所以取 0 和 8 兩種寬度較大者。
            width: Math.max(implicitWidth, fanWide0.width, fanWide8.width)
            horizontalAlignment: Text.AlignRight
        }

        Separator { visible: (Sensors.packageSensor !== null || Sensors.fanRpm >= 0) && !Theme.barCompact }
        // power-profiles-daemon 還沒起來時顯示淡色的問號佔位（開機約 20 秒）。
        Icon {
            text: PowerProfileState.ready ? root.profileIcons[PowerProfileState.profile] ?? "" : "\uf128" // question
            opacity: PowerProfileState.ready ? 1 : 0.5
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible = !popup.visible
    }

    TextMetrics {
        id: fanWide0
        font: Theme.blockFont
        text: "0000 rpm"
    }
    TextMetrics {
        id: fanWide8
        font: Theme.blockFont
        text: "8888 rpm"
    }

    TemperaturePopup {
        id: popup
        anchorItem: root
    }

    component Icon: Text {
        anchors.verticalCenter: parent.verticalCenter
        color: root.fg
        font.family: "FontAwesome"
        font.pixelSize: Theme.blockFont.pixelSize
    }
    component Label: Text {
        anchors.verticalCenter: parent.verticalCenter
        color: root.fg
        font: Theme.blockFont
    }
    component Separator: Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "·"
        color: root.fg
        opacity: 0.5
        font: Theme.blockFont
    }
}
