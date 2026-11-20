// tray 圖示的右鍵選單，自己畫以符合面板風格（取代 Qt 內建的淺色 Fusion 選單）。
// 子選單跟 GNOME 一樣在同一個面板裡切換，最上面出現「返回」。
// 用法：TrayMenu { anchorItem: 圖示; menu: trayItem.menu }，open() 打開。
import QtQuick
import Quickshell
import Quickshell.Widgets

PanelPopup {
    id: root

    required property var menu

    readonly property int menuWidth: 260

    // 目前所在的選單層級：[根選單, 子選單, ...]；每項是 QsMenuHandle（QsMenuEntry 本身也是）。
    property var stack: []
    readonly property var current: stack.length ? stack[stack.length - 1] : null

    function open() {
        stack = [menu];
        visible = true;
    }

    // D-Bus 選單用 _ 標記快速鍵（__ 代表真正的底線），顯示時去掉。
    function label(text) {
        return text.replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_");
    }

    // 主題裡找不到的圖示，QuickShell 會畫成洋紅色棋盤格，所以先檢查。
    // 只檢查「向圖示主題查名稱」的網址；帶 path／fallback 或程式直接提供的圖片都視為可用。
    function iconUsable(url) {
        if (!url)
            return false;
        if (!url.startsWith("image://icon/") || url.includes("?"))
            return true;
        return Quickshell.hasThemeIcon(url.slice("image://icon/".length));
    }

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    // 這一層有沒有勾選框／單選圈，有的話所有項目都留出指示欄位，文字才會對齊。
    readonly property bool hasIndicators: opener.children.values.some(e => e.buttonType !== QsMenuButtonType.None)
    readonly property bool hasIcons: opener.children.values.some(e => root.iconUsable(e.icon))

    Column {
        width: root.menuWidth
        spacing: 2

        // 子選單才有「返回」。
        MenuRow {
            visible: root.stack.length > 1
            enabled: true
            leading: "" // angle-left
            text: I18n.tr("返回")
            onClicked: root.stack = root.stack.slice(0, -1)
        }
        Rectangle {
            visible: root.stack.length > 1
            width: root.menuWidth
            height: 1
            color: Colors.panelRaised
        }

        Repeater {
            model: opener.children

            delegate: Loader {
                id: entryLoader
                required property var modelData
                width: root.menuWidth
                sourceComponent: modelData.isSeparator ? separator : item

                Component {
                    id: separator
                    Item {
                        height: 9
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.menuWidth
                            height: 1
                            color: Colors.panelRaised
                        }
                    }
                }

                Component {
                    id: item
                    MenuRow {
                        readonly property var entry: entryLoader.modelData
                        enabled: entry.enabled
                        text: root.label(entry.text)
                        icon: entry.icon
                        leading: entry.buttonType === QsMenuButtonType.CheckBox
                                 ? (entry.checkState === Qt.Checked ? "" : "") // check-square-o / square-o
                                 : entry.buttonType === QsMenuButtonType.RadioButton
                                 ? (entry.checkState === Qt.Checked ? "" : "") // dot-circle-o / circle-o
                                 : ""
                        trailing: entry.hasChildren ? "" : "" // angle-right
                        onClicked: {
                            if (entry.hasChildren) {
                                root.stack = root.stack.concat([entry]);
                            } else {
                                entry.triggered();
                                root.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }

    // 一列選單項目：［指示欄］［圖示］文字［子選單箭頭］
    component MenuRow: Rectangle {
        id: rowRoot
        property string text
        property string icon
        property string leading
        property string trailing
        property bool enabled: true
        signal clicked

        readonly property color fg: enabled ? Colors.shellFg : Colors.shellDim

        width: root.menuWidth
        height: 32
        radius: 8
        color: enabled && area.containsMouse ? Colors.panelRaised : "transparent"

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                visible: root.hasIndicators || rowRoot.leading !== ""
                width: 16
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
                text: rowRoot.leading
                color: rowRoot.fg
                font.family: "FontAwesome"
                font.pixelSize: Theme.fontPx(14)
            }
            Item {
                visible: root.hasIcons
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                IconImage {
                    anchors.fill: parent
                    visible: root.iconUsable(rowRoot.icon)
                    source: rowRoot.icon
                    implicitSize: 16
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - (rowRoot.trailing ? 20 : 0)
                elide: Text.ElideRight
                text: rowRoot.text
                color: rowRoot.fg
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(14)
            }
        }
        Text {
            visible: rowRoot.trailing !== ""
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: rowRoot.trailing
            color: rowRoot.fg
            font.family: "FontAwesome"
            font.pixelSize: Theme.fontPx(14)
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: rowRoot.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: rowRoot.clicked()
        }
    }
}
