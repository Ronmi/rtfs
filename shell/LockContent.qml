// 一個螢幕的鎖定畫面內容：該螢幕目前的桌布（變暗或模糊）、時鐘、日期、密碼輸入框。
// 真正鎖定時放在 WlSessionLockSurface 裡，預覽時放在一般視窗裡（LockScreen.qml）。
import QtQuick
import Quickshell

Item {
    id: root

    // 螢幕名稱（connector），用來拿 Wallpaper.images 裡的圖。
    required property string screenName
    property bool preview: false

    readonly property var shellScreen: Quickshell.screens.find(s => s.name === screenName) ?? null
    readonly property string background: {
        const v = Config.lock.background;
        if (v === "dim" || v === "blur")
            return v;
        console.warn("LockScreen: lock.background must be dim/blur; got", v);
        return "dim";
    }

    // 沒有桌布圖時跟桌布一樣用官方漸層色。
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Colors.officialFrom }
            GradientStop { position: 1; color: Colors.officialTo }
        }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        // 模糊版載入成功時由它畫，原圖只當來源。
        visible: blur.status !== Loader.Ready
        source: Wallpaper.images[root.screenName] ?? ""
        fillMode: Wallpaper.fillMode
        sourceSize: Qt.size(width * (root.shellScreen?.devicePixelRatio ?? 1),
            height * (root.shellScreen?.devicePixelRatio ?? 1))
        asynchronous: true
        cache: false
    }

    Loader {
        id: blur
        anchors.fill: parent
        source: root.background === "blur" ? "LockBlur.qml" : ""
        onLoaded: item.source = wallpaper
        onStatusChanged: if (status === Loader.Error)
            console.warn("LockScreen: blur unavailable (qml6-module-qtquick-effects installed?), using dim")
    }

    // 桌布亮暗不一，壓暗之後白字才讀得清楚。
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Colors.shellBg.r, Colors.shellBg.g, Colors.shellBg.b, 0.55)
    }

    // 點任何地方都把焦點拉回輸入框。
    MouseArea {
        anchors.fill: parent
        onClicked: password.input.forceActiveFocus()
    }

    // 螢幕鍵盤的按鍵直接改輸入框（不經過 niri）；驗證中跟實體鍵盤一樣不接受輸入。
    function oskType(text) {
        const input = password.input;
        if (password.readOnly)
            return;
        if (input.selectionStart !== input.selectionEnd)
            input.remove(input.selectionStart, input.selectionEnd);
        input.insert(input.cursorPosition, text);
    }
    function oskCommand(code) {
        const input = password.input;
        if (password.readOnly)
            return;
        if (code === 28) {
            LockScreen.submit(password.text);
        } else if (code === 1) {
            password.text = "";
        } else if (code === 14) {
            if (input.selectionStart !== input.selectionEnd)
                input.remove(input.selectionStart, input.selectionEnd);
            else if (input.cursorPosition > 0)
                input.remove(input.cursorPosition - 1, input.cursorPosition);
        }
    }

    OskKeyboard {
        id: keyboard
        visible: LockScreen.oskShown
        viewControls: false
        direct: true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: implicitHeight
        onTyped: text => root.oskType(text)
        onCommand: code => root.oskCommand(code)
    }

    // 扣掉鍵盤後的區域：時鐘和輸入框在這裡置中，按鈕在這裡的右下角（跟 modal 對話框一樣）。
    Item {
        id: free
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: keyboard.visible ? keyboard.top : parent.bottom

        DialogOskButton {
            active: LockScreen.oskShown
            action: () => LockScreen.oskShown = !LockScreen.oskShown
        }
    }

    SystemClock {
        id: clock
        // 格式裡有秒才每秒更新（ss、s 都算；不在乎引號裡的字也被當成秒）。
        precision: Config.lock.clockFormat.includes("s") ? SystemClock.Seconds : SystemClock.Minutes
    }

    Column {
        anchors.centerIn: free
        anchors.verticalCenterOffset: -free.height * 0.08
        spacing: 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, Config.lock.clockFormat)
            color: Colors.shellFg
            font.family: Theme.barFontFamily
            font.pixelSize: Theme.fontPx(112)
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clock.date.toLocaleDateString(I18n.locale, I18n.tr("yyyy年M月d日 dddd"))
            color: Colors.shellFg
            font.family: Theme.barFontFamily
            font.pixelSize: Theme.fontPx(26)
        }

        Item {
            width: 1
            height: 36
        }

        DialogInput {
            id: password
            anchors.horizontalCenter: parent.horizontalCenter
            width: 340
            password: true
            glyph: "" // lock
            placeholder: LockScreen.busy ? I18n.tr("驗證中…") : I18n.tr("輸入密碼解鎖")
            readOnly: LockScreen.busy
            opacity: LockScreen.busy ? 0.7 : 1
            keyHandler: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    LockScreen.submit(password.text);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    password.text = "";
                    event.accepted = true;
                }
            }
            Component.onCompleted: input.forceActiveFocus()
        }

        // 錯誤不用紅字（深色底上對比不到 4.5）：紅色圖示＋粗體，跟 FieldLabel 的 tone: error 一樣。
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 24
            spacing: 8

            Text {
                visible: LockScreen.statusIsError && LockScreen.status !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.iconGlyphs.error
                color: Theme.dialogDark.err
                font.family: "FontAwesome"
                font.pixelSize: Theme.fontPx(16)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: LockScreen.status
                color: Colors.shellFg
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(16)
                font.bold: LockScreen.statusIsError
            }
        }
    }

    Connections {
        target: LockScreen
        function onCleared() {
            password.text = "";
        }
    }

    Text {
        visible: root.preview
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        text: I18n.tr("預覽（沒有真的鎖定）：點這裡關閉")
        color: Colors.shellFg
        font.family: Theme.uiFontFamily
        font.pixelSize: Theme.fontPx(14)

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: LockScreen.preview()
        }
    }
}
