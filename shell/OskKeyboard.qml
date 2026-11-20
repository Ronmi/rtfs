// 螢幕鍵盤的畫面（按鍵、底色、半透明），狀態與送鍵在 Osk.qml。
// 平常放在 OskWindow 裡；modal 對話框會蓋住 OskWindow，所以 DialogFrame 自己再放一個。
// 鍵帽像實體鍵盤一樣同時印出上檔字元，不必追蹤 Shift／Caps Lock 狀態（實體鍵盤也可能改變它）。
import QtQuick

Item {
    id: root

    readonly property var scheme: Theme.dialogDark
    readonly property int keyHeight: 44
    readonly property int gap: 4
    // 每列總寬 15 單位（跟一般筆電鍵盤一樣）。
    readonly property real unit: (width - gap) / 15

    implicitHeight: keys.length * (keyHeight + gap) + gap

    // k：evdev keycode；l：鍵帽文字；s：上檔字元；w：寬度（單位）；m：修飾鍵（見 Osk.qml）；
    // icon：用 FontAwesome 字元當鍵帽（↑↓ 等字元會被 fallback 到彩色 emoji 字型）；
    // a：不送鍵的功能鍵（translucent 切換半透明、flip 切換顯示在頂部或底部）。
    // false：拿掉 ◐（半透明）和翻轉鍵、右 Shift 補滿那一列，也不理會半透明。modal 裡用：
    // 卡片會讓到鍵盤上方，不需要看穿鍵盤，位置也固定在底部。
    property bool viewControls: true
    readonly property var rows: viewControls ? keys
        : keys.map(row => row.filter(k => !k.a).map(k => k.k === 54 ? Object.assign({}, k, { w: 2.75 }) : k))
    readonly property bool translucent: viewControls && Osk.translucent

    // 直接輸入模式（鎖定畫面用）：不經過 rtfs-vkbd 和 niri，按鍵變成 typed／command signal，
    // 由使用的地方直接改輸入框，按鍵不會離開 qs。Shift、Caps Lock 的狀態只存在這裡；
    // 輸入密碼用不到的鍵（F1–F12、Ctrl、Alt、Super、Tab、Del、方向鍵）變暗、沒有作用。
    property bool direct: false
    signal typed(string text)
    // Enter（28）、Backspace（14）、Esc（1）。
    signal command(int code)
    property bool shiftOn: false
    property bool capsOn: false

    function usable(key) {
        if (!direct)
            return true;
        return [1, 14, 28, 42, 54, 57, 58].includes(key.k) || key.s !== undefined || /^[A-Z]$/.test(key.l ?? "");
    }
    function directPress(key) {
        if (!usable(key))
            return;
        switch (key.k) {
        case 42:
        case 54:
            shiftOn = !shiftOn;
            return;
        case 58:
            capsOn = !capsOn;
            return;
        case 1:
        case 14:
        case 28:
            command(key.k);
            return;
        case 57:
            typed(" ");
            break;
        default:
            // 字母：Shift 和 Caps Lock 互相抵銷（跟實體鍵盤一樣）；其他鍵只看 Shift。
            if (/^[A-Z]$/.test(key.l))
                typed(shiftOn !== capsOn ? key.l : key.l.toLowerCase());
            else
                typed(shiftOn ? key.s : key.l);
        }
        shiftOn = false;
    }

    readonly property var keys: [
        [{ k: 1, l: "Esc" }, { k: 59, l: "F1" }, { k: 60, l: "F2" }, { k: 61, l: "F3" }, { k: 62, l: "F4" },
         { k: 63, l: "F5" }, { k: 64, l: "F6" }, { k: 65, l: "F7" }, { k: 66, l: "F8" }, { k: 67, l: "F9" },
         { k: 68, l: "F10" }, { k: 87, l: "F11" }, { k: 88, l: "F12" }, { k: 111, l: "Del", w: 2 }],
        [{ k: 41, l: "`", s: "~" }, { k: 2, l: "1", s: "!" }, { k: 3, l: "2", s: "@" }, { k: 4, l: "3", s: "#" },
         { k: 5, l: "4", s: "$" }, { k: 6, l: "5", s: "%" }, { k: 7, l: "6", s: "^" }, { k: 8, l: "7", s: "&" },
         { k: 9, l: "8", s: "*" }, { k: 10, l: "9", s: "(" }, { k: 11, l: "0", s: ")" }, { k: 12, l: "-", s: "_" },
         { k: 13, l: "=", s: "+" }, { k: 14, l: "⌫", w: 2 }],
        [{ k: 15, l: "Tab", w: 1.5 }, { k: 16, l: "Q" }, { k: 17, l: "W" }, { k: 18, l: "E" }, { k: 19, l: "R" },
         { k: 20, l: "T" }, { k: 21, l: "Y" }, { k: 22, l: "U" }, { k: 23, l: "I" }, { k: 24, l: "O" },
         { k: 25, l: "P" }, { k: 26, l: "[", s: "{" }, { k: 27, l: "]", s: "}" }, { k: 43, l: "\\", s: "|", w: 1.5 }],
        [{ k: 58, l: "Caps", w: 1.75 }, { k: 30, l: "A" }, { k: 31, l: "S" }, { k: 32, l: "D" }, { k: 33, l: "F" },
         { k: 34, l: "G" }, { k: 35, l: "H" }, { k: 36, l: "J" }, { k: 37, l: "K" }, { k: 38, l: "L" },
         { k: 39, l: ";", s: ":" }, { k: 40, l: "'", s: "\"" }, { k: 28, l: "Enter", w: 2.25 }],
        [{ k: 42, l: "Shift", w: 2.25, m: true }, { k: 44, l: "Z" }, { k: 45, l: "X" }, { k: 46, l: "C" },
         { k: 47, l: "V" }, { k: 48, l: "B" }, { k: 49, l: "N" }, { k: 50, l: "M" }, { k: 51, l: ",", s: "<" },
         { k: 52, l: ".", s: ">" }, { k: 53, l: "/", s: "?" }, { k: 54, l: "Shift", w: 1.25, m: true },
         { a: "translucent", w: 0.75 }, { a: "flip", w: 0.75 }],
        [{ k: 29, l: "Ctrl", w: 1.25, m: true }, { k: 125, l: "Super", w: 1.25, m: true },
         { k: 56, l: "Alt", w: 1.25, m: true }, { k: 57, l: "", w: 5 }, { k: 100, l: "Alt", w: 1.25, m: true },
         { k: 97, l: "Ctrl", m: true }, { k: 105, icon: "\uf060" }, { k: 103, icon: "\uf062" }, { k: 108, icon: "\uf063" }, { k: 106, icon: "\uf061" }]
    ]

    // 吃掉按鍵之間空隙的點擊：放在 modal 裡時，點擊穿透到遮罩會被當成取消。
    MouseArea {
        anchors.fill: parent
    }

    // 半透明時整塊（底色加按鍵）一起變淡；layer 讓它當成一張圖處理，按鍵不會透出底色。
    Rectangle {
        anchors.fill: parent
        color: root.scheme.bg
        opacity: root.translucent ? Config.osk.opacity / 100 : 1
        layer.enabled: root.translucent

        Column {
            x: root.gap
            y: root.gap
            spacing: root.gap

            Repeater {
                model: root.rows

                Row {
                    required property var modelData
                    spacing: root.gap

                    Repeater {
                        model: parent.modelData

                        Rectangle {
                            id: key

                            required property var modelData
                            readonly property bool modifier: modelData.m ?? false
                            readonly property string modState: root.direct
                                ? ((modelData.k === 42 || modelData.k === 54) && root.shiftOn ? "latched"
                                    : modelData.k === 58 && root.capsOn ? "locked" : "")
                                : modifier ? (Osk.mods[modelData.k]?.state ?? "") : ""
                            readonly property bool active: (tap.pressed && root.usable(modelData)) || modState !== ""
                                || (modelData.a === "translucent" && Osk.translucent)

                            width: (modelData.w ?? 1) * root.unit - root.gap
                            height: root.keyHeight
                            radius: 6
                            color: active ? root.scheme.accent : root.scheme.surface
                            opacity: root.usable(modelData) ? 1 : 0.35

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: key.modelData.s ? 6 : 0
                                // translucent 是 adjust（◐）；flip 是並排的細長箭頭（↓↑），刻意跟方向鍵的粗箭頭不同。
                                readonly property string icon: key.modelData.a === "translucent" ? "\uf042"
                                    : key.modelData.a === "flip" ? "\uf175\uf176"
                                    : key.modelData.icon ?? ""
                                text: icon || key.modelData.l
                                color: key.active ? root.scheme.accentFg : root.scheme.fg
                                font.family: icon ? "FontAwesome" : Theme.uiFontFamily
                                font.pixelSize: Theme.fontPx(text.length > 1 ? 13 : 16)
                            }
                            // 鎖定的小燈（像 Android 鍵盤的 Caps Lock 燈，顏色用官方漸層）。
                            Rectangle {
                                visible: key.modState === "locked"
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.topMargin: 5
                                width: 16
                                height: 4
                                radius: 2
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Colors.officialFrom }
                                    GradientStop { position: 1; color: Colors.officialTo }
                                }
                            }
                            Text {
                                visible: !!key.modelData.s
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 3
                                text: key.modelData.s ?? ""
                                color: key.active ? root.scheme.accentFg : root.scheme.dim
                                font.family: Theme.uiFontFamily
                                font.pixelSize: Theme.fontPx(12)
                            }

                            // TapHandler 而非 MouseArea：每根手指各自追蹤，兩指快速交替打字時不會漏鍵。
                            TapHandler {
                                id: tap
                                gesturePolicy: TapHandler.WithinBounds
                                onPressedChanged: {
                                    if (root.direct) {
                                        if (pressed)
                                            root.directPress(key.modelData);
                                    } else if (key.modelData.a === "translucent") {
                                        if (pressed)
                                            Osk.translucent = !Osk.translucent;
                                    } else if (key.modelData.a === "flip") {
                                        if (pressed)
                                            Osk.atTop = !Osk.atTop;
                                    } else if (key.modifier) {
                                        if (pressed)
                                            Osk.modifierDown(key.modelData.k);
                                        else
                                            Osk.modifierUp(key.modelData.k);
                                    } else if (pressed) {
                                        Osk.pressKey(key.modelData.k);
                                    } else {
                                        Osk.releaseKey(key.modelData.k);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
