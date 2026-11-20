// 顏色選擇 field（zenity --color-selection、kdialog --getcolor、yad --color／CLR）。
// spec：color（初始顏色，QML 認得的字串："#rrggbb"、"#aarrggbb"、顏色名稱）、
// palette（顯示色票：TWICE 成員色與幾個介面色）、alpha（可調透明度）。
// 值：{ r, g, b（0–255）, a（0–1）, hex（"#rrggbb"，有透明度時 "#rrggbbaa"） }（輸出格式由轉接層處理）。
import QtQuick
import QtQuick.Layouts

DialogField {
    id: root

    // 內部用 HSV 保存，免得在灰色（飽和度 0）時色相被吃掉。
    property real hue: 0
    property real sat: 0
    property real val: 1
    property real alpha: 1
    readonly property color current: Qt.hsva(hue, sat, val, alpha)
    readonly property bool hasAlpha: !!field.alpha

    readonly property var swatches: [
        Colors.nayeon, Colors.jeongyeon, Colors.momo, Colors.sana, Colors.jihyo,
        Colors.mina, Colors.dahyun, Colors.chaeyoung, Colors.tzuyu,
        Colors.officialFrom, Colors.officialTo, Colors.inkDark, Colors.inkLight
    ]

    function hex2(n) {
        return Math.round(n).toString(16).padStart(2, "0");
    }
    function hexOf(c, withAlpha) {
        return "#" + hex2(c.r * 255) + hex2(c.g * 255) + hex2(c.b * 255) + (withAlpha ? hex2(c.a * 255) : "");
    }
    function setColor(c) {
        // 灰色沒有色相（hsvHue 為 -1），保留原本的色相。
        if (c.hsvHue >= 0)
            hue = c.hsvHue;
        sat = c.hsvSaturation;
        val = c.hsvValue;
        alpha = hasAlpha ? c.a : 1;
    }
    // 解析使用者輸入：#rgb、#rrggbb、#rrggbbaa（CSS 順序，跟輸出一致）或顏色名稱。
    function parse(text) {
        const t = text.trim();
        const m = t.match(/^#?([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i);
        if (m) {
            let h = m[1];
            if (h.length === 3)
                h = h.split("").map(ch => ch + ch).join("");
            const n = i => parseInt(h.substr(i, 2), 16) / 255;
            return Qt.rgba(n(0), n(2), n(4), h.length === 8 ? n(6) : 1);
        }
        probe.color = "transparent";
        probe.color = t; // QML 的顏色名稱（red、skyblue…）；認不得時維持 transparent
        return probe.color.a > 0 || t === "transparent" ? probe.color : null;
    }

    value: ({
        r: Math.round(current.r * 255),
        g: Math.round(current.g * 255),
        b: Math.round(current.b * 255),
        a: hasAlpha ? Number(current.a.toFixed(3)) : 1,
        hex: hexOf(current, hasAlpha && current.a < 1)
    })
    implicitWidth: 360
    implicitHeight: layout.implicitHeight

    Component.onCompleted: {
        const c = parse(field.color ?? "") ?? Qt.rgba(1, 1, 1, 1);
        setColor(c);
        hexInput.text = hexOf(current, hasAlpha && current.a < 1);
    }
    onCurrentChanged: if (!hexInput.input.activeFocus) hexInput.text = hexOf(current, hasAlpha && current.a < 1)

    Rectangle {
        id: probe
        visible: false
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            spacing: 12

            // 飽和度（左→右）／明度（上→下）方塊
            Rectangle {
                id: svBox
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: "white"
                    }
                    GradientStop {
                        position: 1
                        color: Qt.hsva(root.hue, 1, 1, 1)
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1
                            color: "black"
                        }
                    }
                }
                Rectangle {
                    x: root.sat * parent.width - width / 2
                    y: (1 - root.val) * parent.height - height / 2
                    width: 14
                    height: 14
                    radius: 7
                    color: "transparent"
                    border.width: 2
                    border.color: root.val > 0.5 ? "black" : "white"
                }
                MouseArea {
                    anchors.fill: parent
                    function apply(mouse) {
                        root.sat = Math.max(0, Math.min(1, mouse.x / width));
                        root.val = Math.max(0, Math.min(1, 1 - mouse.y / height));
                    }
                    onPressed: mouse => apply(mouse)
                    onPositionChanged: mouse => apply(mouse)
                }
            }

            // 色相條（上→下）
            Strip {
                gradient: Gradient {
                    GradientStop { position: 0.000; color: Qt.hsva(0.000, 1, 1, 1) }
                    GradientStop { position: 0.167; color: Qt.hsva(0.167, 1, 1, 1) }
                    GradientStop { position: 0.333; color: Qt.hsva(0.333, 1, 1, 1) }
                    GradientStop { position: 0.500; color: Qt.hsva(0.500, 1, 1, 1) }
                    GradientStop { position: 0.667; color: Qt.hsva(0.667, 1, 1, 1) }
                    GradientStop { position: 0.833; color: Qt.hsva(0.833, 1, 1, 1) }
                    GradientStop { position: 1.000; color: Qt.hsva(1.000, 1, 1, 1) }
                }
                position: root.hue
                onMoved: p => root.hue = Math.min(p, 0.999)
            }

            // 透明度條（上不透明→下透明）
            Strip {
                visible: root.hasAlpha
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.hsva(root.hue, root.sat, root.val, 1)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.hsva(root.hue, root.sat, root.val, 0)
                    }
                }
                position: 1 - root.alpha
                onMoved: p => root.alpha = 1 - p
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // 目前顏色預覽
            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 10
                color: root.current
                border.width: 1
                border.color: theme.line === "transparent" ? theme.dim : theme.line
            }
            DialogInput {
                id: hexInput
                theme: root.theme
                Layout.fillWidth: true
                placeholder: "#rrggbb"
                keyHandler: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        hexInput.apply();
                    root.body.handleKey(event);
                }
                function apply() {
                    const c = root.parse(text);
                    if (c !== null)
                        root.setColor(c);
                    text = root.hexOf(root.current, root.hasAlpha && root.current.a < 1);
                }
                Connections {
                    target: hexInput.input
                    function onEditingFinished() {
                        hexInput.apply();
                    }
                }
            }
        }

        // 色票
        Flow {
            visible: !!root.field.palette
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.swatches
                Rectangle {
                    required property color modelData
                    width: 28
                    height: 28
                    radius: 14
                    color: modelData
                    border.width: 1
                    border.color: theme.line === "transparent" ? theme.dim : theme.line
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setColor(parent.modelData)
                    }
                }
            }
        }
    }

    // 直的漸層條加一個位置標記，可點擊或拖曳；position 是 0（上）到 1（下）。
    component Strip: Rectangle {
        id: strip
        property real position: 0
        signal moved(real p)

        Layout.preferredWidth: 20
        Layout.fillHeight: true
        radius: 6

        Rectangle {
            x: -3
            y: strip.position * strip.height - height / 2
            width: strip.width + 6
            height: 6
            radius: 3
            color: "white"
            border.width: 1
            border.color: "black"
        }
        MouseArea {
            anchors.fill: parent
            function apply(mouse) {
                strip.moved(Math.max(0, Math.min(1, mouse.y / height)));
            }
            onPressed: mouse => apply(mouse)
            onPositionChanged: mouse => apply(mouse)
        }
    }
}
