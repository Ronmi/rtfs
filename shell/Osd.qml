// 螢幕提示（OSD）：音量、亮度等短暫顯示的提示。同時只有一個，新的取代舊的。
// shell 內直接呼叫 Osd.show(spec)；rtfs-ui 的 osd 容器經由 Dialogs 也用這裡（owner 是請求 id，結束時收到 ended）。
// spec（都可省略，但至少要有一項內容）：
//   icon      info | question | warning | error，或圖示主題名稱、圖檔絕對路徑
//   glyph     FontAwesome 字元（bar 的圖示也是這樣畫），優先於 icon
//   text      文字          value  0–100，有就顯示進度條          showValue  進度條右邊顯示百分比
//   position  top-left | top | top-right | left | center | right | bottom-left | bottom | bottom-right（預設見設定 notifications.osd.position）
//   timeout   秒數，預設見設定 notifications.osd.timeout；update 會重新計時
// 不拿鍵盤、滑鼠穿透；避開 bar 等保留區（top 會出現在 bar 下方）。
pragma Singleton
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Singleton {
    id: root

    property var spec: ({})
    property string owner: ""
    property bool shown: false

    // 結束時通知擁有者：reason 是 timeout 或 replaced（被別的 OSD 取代）。hide() 不發。
    signal ended(string owner, string reason)

    function show(newSpec, newOwner) {
        const prev = owner;
        owner = newOwner ?? "";
        if (shown && prev !== "" && prev !== owner)
            ended(prev, "replaced");
        // 開啟當下決定螢幕（跟對話框一樣用 niri 聚焦的那個）；連續更新時不跳來跳去。
        if (!shown)
            win.screen = Quickshell.screens.find(s => s.name === Niri.focusedOutput)
                ?? ShellState.barScreen;
        spec = newSpec;
        shown = true;
        timer.restart();
    }

    // 合併屬性並重新計時；不是目前的擁有者就不理（已經被取代了）。
    function update(byOwner, patch) {
        if (!shown || byOwner !== owner)
            return;
        spec = Object.assign({}, spec, patch);
        timer.restart();
    }

    function hide(byOwner) {
        if (!shown || byOwner !== owner)
            return;
        timer.stop();
        shown = false;
        owner = "";
    }

    Timer {
        id: timer
        interval: (root.spec.timeout ?? Config.notifications.osd.timeout) * 1000
        onTriggered: {
            const o = root.owner;
            root.shown = false;
            root.owner = "";
            if (o !== "")
                root.ended(o, "timeout");
        }
    }

    PanelWindow {
        id: win

        readonly property string position: root.spec.position ?? Config.notifications.osd.position

        visible: root.shown
        anchors {
            top: win.position.startsWith("top")
            bottom: win.position.startsWith("bottom")
            left: win.position.endsWith("left")
            right: win.position.endsWith("right")
        }
        margins {
            top: 32
            bottom: 64
            left: 32
            right: 32
        }
        implicitWidth: card.width
        implicitHeight: card.height
        color: "transparent"
        // Normal + 不設 exclusiveZone：自己不佔空間，但會避開別人（bar）的保留區。
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "rtfs-osd"
        // 空的 Region：點擊穿透到下面的視窗。
        mask: Region {}

        Rectangle {
            id: card

            readonly property var theme: Theme.osd
            readonly property string glyph: root.spec.glyph ?? Theme.iconGlyphs[root.spec.icon] ?? ""
            readonly property string iconSource: {
                const icon = root.spec.icon ?? "";
                if (glyph !== "" || icon === "")
                    return "";
                if (icon.startsWith("/"))
                    return "file://" + icon;
                return Quickshell.hasThemeIcon(icon) ? Quickshell.iconPath(icon) : "";
            }
            readonly property bool hasValue: typeof root.spec.value === "number"
            readonly property real fraction: Math.max(0, Math.min(100, root.spec.value ?? 0)) / 100

            width: row.implicitWidth + 40
            height: row.implicitHeight + 28
            radius: 14
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: card.theme.bgFrom }
                GradientStop { position: 1; color: card.theme.bgTo }
            }

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 14

                Text {
                    visible: card.glyph !== ""
                    text: card.glyph
                    color: card.theme.fg
                    font.family: "FontAwesome"
                    font.pixelSize: Theme.fontPx(26)
                    Layout.alignment: Qt.AlignVCenter
                }
                IconImage {
                    visible: card.iconSource !== ""
                    source: card.iconSource
                    implicitSize: 32
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    // 不能用子項目的 visible：父項目隱藏時子項目的 visible 也是 false，會卡住。
                    visible: (root.spec.text ?? "") !== "" || card.hasValue
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: label
                        visible: (root.spec.text ?? "") !== ""
                        text: root.spec.text ?? ""
                        color: card.theme.fg
                        font.family: Theme.uiFontFamily
                        font.pixelSize: Theme.fontPx(17)
                        font.bold: true
                        wrapMode: Text.Wrap
                        Layout.maximumWidth: 480
                        // 有進度條時文字跟進度條同寬，置中；只有文字時照文字寬度。
                        Layout.fillWidth: bar.visible
                        horizontalAlignment: bar.visible ? Text.AlignHCenter : Text.AlignLeft
                    }
                    Rectangle {
                        id: bar
                        visible: card.hasValue
                        implicitWidth: 220
                        implicitHeight: 8
                        radius: 4
                        color: card.theme.track

                        Rectangle {
                            width: parent.width * card.fraction
                            height: parent.height
                            radius: parent.radius
                            color: card.theme.fg
                        }
                    }
                }

                Text {
                    visible: card.hasValue && !!root.spec.showValue
                    text: Math.round(root.spec.value ?? 0) + "%"
                    color: card.theme.fg
                    font.family: Theme.uiFontFamily
                    font.pixelSize: Theme.fontPx(15)
                    font.bold: true
                    // 寬度固定成「100%」，數字變動時卡片不會跟著伸縮。
                    Layout.preferredWidth: Math.ceil(hundred.advanceWidth)
                    horizontalAlignment: Text.AlignRight
                    Layout.alignment: Qt.AlignVCenter

                    TextMetrics {
                        id: hundred
                        font.family: Theme.uiFontFamily
                        font.pixelSize: Theme.fontPx(15)
                        font.bold: true
                        text: "100%"
                    }
                }
            }
        }
    }
}
