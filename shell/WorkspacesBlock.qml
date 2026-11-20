// 狀態列的工作區色塊（子瑜色底），只列出這條 bar 所在螢幕的工作區。
// 混合版：目前所在用彩瑛色色塊加數字，其他工作區用 GNOME 式小圓點
// （使用者覺得其他工作區的數字意義不大；純圓點版的膠囊在定延色底上不好看）。
// 點擊開關 niri 的 overview（跟 GNOME 點工作區指示器一樣）。
import QtQuick

Rectangle {
    id: root

    required property string output

    readonly property var workspaces: Niri.workspaces.filter(w => w.output === root.output)

    implicitWidth: row.implicitWidth + 2 * 6
    implicitHeight: Theme.blockHeight
    radius: Theme.blockRadius
    color: Colors.tzuyu

    Row {
        id: row
        anchors.centerIn: parent

        Repeater {
            // model 用數量而不是陣列：Niri 每次更新都換成新陣列，以陣列當 model 會讓 Repeater
            // 把所有點刪掉重建，切換時就看不到動畫。用數量的話只有工作區增減時才重建。
            model: root.workspaces.length

            // 可點範圍（整個色塊高、點的左右各留 3px）比點本身大，不用瞄得很準。
            delegate: Item {
                id: slot

                required property int index
                readonly property var modelData: root.workspaces[index]
                readonly property bool active: modelData.is_active
                readonly property bool urgent: modelData.is_urgent

                width: dot.width + 6
                height: root.height

                Rectangle {
                    id: dot
                    anchors.centerIn: parent
                    width: slot.active ? label.implicitWidth + 14 : 8
                    height: slot.active ? root.height - 6 : 8
                    radius: slot.active ? 6 : 4
                    // 目前所在用彩瑛紅；有視窗要求注意用志效黃（彩瑛紅已經是目前所在，
                    // 志效黃在子瑜底上也夠顯眼）；其他是半透明淺灰，刻意低調（延續 waybar 版的低對比數字）。
                    color: slot.urgent ? Colors.jihyo
                         : slot.active ? Colors.chaeyoung
                         : Qt.rgba(Colors.inkLight.r, Colors.inkLight.g, Colors.inkLight.b, 0.45)

                    Behavior on width {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    Text {
                        id: label
                        anchors.centerIn: parent
                        // 動畫展開到一定寬度才顯示，避免數字擠在小圓點裡。
                        visible: slot.active && dot.width > implicitWidth
                        text: slot.modelData.idx
                        color: slot.urgent ? Colors.inkDark : Colors.inkLight
                        font.family: Theme.barFontFamily
                        font.pixelSize: Theme.blockFont.pixelSize
                        font.bold: true
                    }
                }

            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Niri.toggleOverview()
    }
}
