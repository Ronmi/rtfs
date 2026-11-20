// 系統選單（從 SystemBlock 展開，類似 GNOME 的快速設定）。靠近 bar 的一端起依序是：
// 使用者（頭像、名稱）與重新開機、關機按鈕；音量（可展開輸出、輸入裝置與麥克風音量）、有程式錄音時的麥克風、亮度滑桿；
// 有播放器時的媒體控制；螢幕常亮、螢幕鏡像、桌布輪換、自動旋轉開關；
// 電池資訊（周邊裝置預設收起）；選項清單：截圖（展開選方式）、設定、其他電源動作（鎖定、睡眠、休眠、登出，預設收起）。
// 電源動作由 SystemBlock 提供：[{ icon, label, run }]，actions 放在頂端，moreActions 收在「其他」。展開的子清單在選單關閉時收回。
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets

PanelPopup {
    id: root

    required property var actions
    required property var moreActions

    // 螢幕常亮（SystemBlock 的 IdleInhibitor 讀這個值）。不寫進設定，qs 重開就回到關閉。
    property bool keepAwake: false

    readonly property int menuWidth: 340
    readonly property string home: Quickshell.env("HOME")
    readonly property string account: Quickshell.env("USER")

    // 可展開的區塊
    property bool shotOpen: false
    property bool devicesOpen: false
    property bool peripheralsOpen: false
    property bool moreOpen: false
    property bool mirrorPickOpen: false

    onVisibleChanged: if (!visible) {
        shotOpen = false;
        devicesOpen = false;
        peripheralsOpen = false;
        moreOpen = false;
        mirrorPickOpen = false;
        pickedPlayer = null;
    }

    // 顯示名稱：設定檔 → passwd 的 GECOS 全名 → 帳號。
    property string gecosName: ""
    readonly property string displayName: Config.user.name || gecosName || account

    // 頭像依序嘗試，讀不到（不存在、格式錯）就換下一個；都沒有就顯示名稱的第一個字。
    readonly property var avatarCandidates: [
        expandHome(Config.user.avatar),
        "/var/lib/AccountsService/icons/" + account,
        home + "/.face"
    ].filter(p => p !== "")
    property int avatarIndex: 0
    onAvatarCandidatesChanged: avatarIndex = 0

    function expandHome(path) {
        return path.startsWith("~/") ? home + path.slice(1) : path;
    }

    // getent 而不是讀 /etc/passwd：帳號也可能來自 LDAP 等其他 NSS 來源。
    Process {
        running: true
        command: ["getent", "passwd", root.account]
        stdout: StdioCollector {
            // name:x:uid:gid:GECOS:home:shell，GECOS 的第一欄是全名。
            onStreamFinished: root.gecosName = (text.split(":")[4] ?? "").split(",")[0].trim()
        }
    }

    // --- 音量 ---
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioReady: sink?.ready ?? false
    // 輸出裝置（排除程式的播放串流）。
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)

    // --- 麥克風 ---
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micReady: source?.ready ?? false
    // 輸入裝置。用 type 判斷：節點的 properties 要被 PwObjectTracker 追蹤後才有內容。
    readonly property var sources: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSource)
    // 有程式正在錄音時（跟 GNOME 一樣）主選單直接顯示麥克風滑桿。
    readonly property bool recording: Privacy.recording

    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
    }

    function nodeName(n) {
        return n.description || n.nickname || n.name;
    }

    // --- 媒體 ---
    // 預設顯示正在播放的播放器；手動切換過就固定那個，選單關掉後回到預設。
    readonly property var players: Mpris.players.values
    property var pickedPlayer: null
    readonly property var player: players.includes(pickedPlayer) ? pickedPlayer
        : players.find(p => p.isPlaying) ?? players[0] ?? null

    // 「1:23 / 4:56」；播放器沒提供長度時只顯示目前位置，都沒有就空白。
    readonly property string mediaTime: {
        const p = player;
        if (!p || !p.positionSupported)
            return "";
        const fmt = sec => {
            sec = Math.max(0, Math.floor(sec));
            const h = Math.floor(sec / 3600), m = Math.floor(sec / 60) % 60, ss = String(sec % 60).padStart(2, "0");
            return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss;
        };
        return fmt(p.position) + (p.lengthSupported && p.length > 0 ? " / " + fmt(p.length) : "");
    }

    function nextPlayer() {
        pickedPlayer = players[(players.indexOf(player) + 1) % players.length];
    }

    // --- 亮度 ---
    // sysfs 的 brightness 一般使用者不能寫，跟 niri 的亮度鍵一樣交給 brightnessctl。
    // 拖動滑桿時只保留最新的值，前一次執行完才送下一次，不會一次開一堆程式。
    property int wantedBrightness: -1

    function setBrightness(percent) {
        // 0% 在很多面板上是全黑，最低留 1%。
        wantedBrightness = Math.max(1, Math.round(percent));
        if (!brightnessProc.running)
            applyBrightness();
    }
    function applyBrightness() {
        brightnessProc.command = ["brightnessctl", "--quiet", "-d", Backlight.device, "set", wantedBrightness + "%"];
        wantedBrightness = -1;
        brightnessProc.running = true;
    }
    Process {
        id: brightnessProc
        onExited: if (root.wantedBrightness >= 0)
            root.applyBrightness()
    }

    // 各區塊宣告成屬性，再依 bar 位置排進 Column：bar 在下緣時選單朝上展開，順序整個反過來，
    // 電源選項一樣離 bar 最遠。
    Column {
        spacing: 8
        readonly property var sections: [
            root.header, root.separator1, root.sliders, root.media, root.toggles,
            root.separator2, root.batterySection, root.separator3, root.powerList
        ]
        children: Theme.barAtBottom ? sections.slice().reverse() : sections
    }

    // ===== 使用者、重新開機、關機 =====
    property Item header: Item {
        width: root.menuWidth
        height: 48

        ClippingRectangle {
            id: avatar
            width: 44
            height: 44
            radius: 22
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.panelRaised

            Text {
                anchors.centerIn: parent
                visible: avatarImage.status !== Image.Ready
                text: root.displayName.charAt(0).toUpperCase()
                color: Colors.shellFg
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(20)
            }
            Image {
                id: avatarImage
                anchors.fill: parent
                source: root.avatarIndex < root.avatarCandidates.length
                    ? "file://" + root.avatarCandidates[root.avatarIndex] : ""
                sourceSize.width: 88
                sourceSize.height: 88
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                onStatusChanged: if (status === Image.Error)
                    root.avatarIndex++
            }
        }

        Column {
            anchors.left: avatar.right
            anchors.leftMargin: 12
            anchors.right: headerButtons.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.displayName
                color: Colors.shellFg
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(16)
                font.bold: true
            }
            // 顯示名稱跟帳號不同時才另外列出帳號。
            Text {
                width: parent.width
                visible: root.displayName !== root.account
                elide: Text.ElideRight
                text: root.account
                color: Colors.shellDim
                font.family: Theme.uiFontFamily
                font.pixelSize: Theme.fontPx(13)
            }
        }

        // 關機最常用、放在最順手的位置；按鈕放大、拉開間隔避免誤觸（按了還會先跳確認對話窗）。
        Row {
            id: headerButtons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            Repeater {
                model: root.actions
                delegate: IconButton {
                    required property var modelData
                    size: 44
                    iconSize: Theme.fontPx(26)
                    icon: modelData.icon
                    onClicked: {
                        root.visible = false;
                        modelData.run();
                    }
                }
            }
        }
    }

    // 截圖方式（按選項清單的「截圖」才展開）。實際截圖交給 Screenshot：整個螢幕、視窗會先讓你點選要截哪個。
    property Item shotRow: Row {
        id: shotRow
        visible: root.shotOpen
        width: root.menuWidth
        spacing: 6

        readonly property var items: [
            { icon: "", label: I18n.tr("選取範圍"), // crop_free
              run: () => Screenshot.region() },
            { icon: "", label: I18n.tr("整個螢幕"), // desktop_windows
              run: () => Screenshot.screen() },
            { icon: "", label: I18n.tr("視窗"), // web_asset
              run: () => Screenshot.window() }
        ]

        Repeater {
            model: shotRow.items
            delegate: Rectangle {
                id: shotButton
                required property var modelData

                width: (shotRow.width - shotRow.spacing * (shotRow.items.length - 1)) / shotRow.items.length
                height: 36
                radius: 8
                color: shotArea.containsMouse ? Qt.lighter(Colors.panelRaised, 1.4) : Colors.panelRaised

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    MenuIcon {
                        text: shotButton.modelData.icon
                        font.pixelSize: Theme.fontPx(18)
                    }
                    MenuLabel {
                        text: shotButton.modelData.label
                        font.pixelSize: Theme.fontPx(14)
                    }
                }
                MouseArea {
                    id: shotArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.visible = false;
                        shotButton.modelData.run();
                    }
                }
            }
        }
    }

    property Item separator1: MenuSeparator { width: root.menuWidth }

    // ===== 音量、亮度 =====
    property Item sliders: Column {
        width: root.menuWidth
        spacing: 4

        // 音量：左邊圖示切換靜音，右邊的箭頭展開輸出裝置。
        Row {
            width: parent.width
            spacing: 4

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                readonly property real volume: root.audioReady ? root.sink.audio.volume : 0
                // volume_off / volume_mute / volume_down / volume_up
                icon: !root.audioReady || root.sink.audio.muted || volume === 0 ? ""
                    : volume < 0.34 ? "" : volume < 0.67 ? "" : ""
                onClicked: if (root.audioReady)
                    root.sink.audio.muted = !root.sink.audio.muted
            }
            PanelSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * 36 - 2 * parent.spacing
                enabled: root.audioReady
                value: root.audioReady ? root.sink.audio.volume : 0
                onMoved: v => root.sink.audio.volume = v
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.devicesOpen ? "" : "" // expand_less / expand_more
                active: root.devicesOpen
                onClicked: root.devicesOpen = !root.devicesOpen
            }
        }

        MicRow {
            visible: root.recording
        }

        // 展開區：輸出、輸入裝置（選了就設成預設），麥克風音量（錄音中時已經顯示在上面），音效設定。
        Rectangle {
            visible: root.devicesOpen
            width: parent.width
            height: deviceColumn.implicitHeight + 8
            radius: 10
            color: Colors.panelRaised

            Column {
                id: deviceColumn
                x: 4
                y: 4
                width: parent.width - 8

                MenuSectionTitle {
                    text: I18n.tr("輸出")
                }
                MenuLabel {
                    visible: root.sinks.length === 0
                    leftPadding: 12
                    topPadding: 8
                    bottomPadding: 8
                    text: I18n.tr("沒有輸出裝置")
                    color: Colors.shellDim
                }
                Repeater {
                    model: root.sinks
                    delegate: MenuEntry {
                        required property var modelData
                        width: deviceColumn.width
                        icon: modelData === root.sink ? "" : "" // check
                        label: root.nodeName(modelData)
                        hoverColor: Qt.lighter(Colors.panelRaised, 1.4)
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }

                MenuSectionTitle {
                    text: I18n.tr("輸入")
                }
                MicRow {
                    visible: !root.recording
                }
                MenuLabel {
                    visible: root.sources.length === 0
                    leftPadding: 12
                    topPadding: 8
                    bottomPadding: 8
                    text: I18n.tr("沒有輸入裝置")
                    color: Colors.shellDim
                }
                Repeater {
                    model: root.sources
                    delegate: MenuEntry {
                        required property var modelData
                        width: deviceColumn.width
                        icon: modelData === root.source ? "\ue5ca" : "" // check
                        label: root.nodeName(modelData)
                        hoverColor: Qt.lighter(Colors.panelRaised, 1.4)
                        onClicked: Pipewire.preferredDefaultAudioSource = modelData
                    }
                }

                MenuEntry {
                    width: deviceColumn.width
                    icon: "\ue8b8" // settings
                    label: I18n.tr("音效設定…")
                    hoverColor: Qt.lighter(Colors.panelRaised, 1.4)
                    onClicked: {
                        root.visible = false;
                        Quickshell.execDetached(["pavucontrol"]);
                    }
                }
            }
        }

        // 亮度：沒有背光裝置（桌機）就不顯示。
        Row {
            visible: Backlight.device !== ""
            width: parent.width
            spacing: 4

            Item {
                width: 36
                height: 36
                anchors.verticalCenter: parent.verticalCenter
                MenuIcon {
                    anchors.centerIn: parent
                    text: "" // light_mode
                }
            }
            PanelSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * 36 - 2 * parent.spacing
                value: Backlight.percent / 100
                onMoved: v => root.setBrightness(v * 100)
            }
        }
    }

    // ===== 媒體控制（有播放器才出現） =====
    property Item media: Rectangle {
        visible: root.player !== null
        width: root.menuWidth
        height: 96
        radius: 10
        color: Colors.panelRaised

        // 專輯封面：播放器給的可能是 file:// 或網路網址；沒有或載入失敗時顯示音符。
        ClippingRectangle {
            id: cover
            x: 8
            width: 80
            height: 80
            anchors.verticalCenter: parent.verticalCenter
            radius: 8
            color: Colors.panelBg

            MenuIcon {
                anchors.centerIn: parent
                visible: coverImage.status !== Image.Ready
                text: "" // music_note
                font.pixelSize: Theme.fontPx(32)
                color: Colors.shellDim
            }
            Image {
                id: coverImage
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                sourceSize.width: 160
                sourceSize.height: 160
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Column {
            anchors.left: cover.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            MenuLabel {
                width: parent.width
                elide: Text.ElideRight
                font.bold: true
                text: root.player?.trackTitle || root.player?.identity || ""
            }
            // 演出者 · 時間；有多個播放器時加上播放器名稱，切換時才分得出是哪個。
            MenuLabel {
                width: parent.width
                elide: Text.ElideRight
                color: Colors.shellDim
                font.pixelSize: Theme.fontPx(12)
                text: [
                    root.player?.trackArtist,
                    root.mediaTime,
                    root.players.length > 1 ? root.player?.identity : ""
                ].filter(t => t).join(" · ")
            }
            Item {
                width: parent.width
                height: 36

                Row {
                    x: -6 // 按鈕的圓形 hover 底色有留白，往左對齊文字
                    IconButton {
                        enabled: root.player?.canGoPrevious ?? false
                        icon: "" // skip_previous
                        onClicked: root.player.previous()
                    }
                    IconButton {
                        enabled: root.player?.canTogglePlaying ?? false
                        icon: root.player?.isPlaying ? "" : "" // pause / play_arrow
                        onClicked: root.player.togglePlaying()
                    }
                    IconButton {
                        enabled: root.player?.canGoNext ?? false
                        icon: "" // skip_next
                        onClicked: root.player.next()
                    }
                }
                IconButton {
                    anchors.right: parent.right
                    visible: root.players.length > 1
                    icon: "" // swap_horiz
                    onClicked: root.nextPlayer()
                }
            }
        }

        // MPRIS 的播放位置不會自己更新（規格上只在跳轉時通知），選單開著又在播放時每秒重讀一次。
        Timer {
            running: root.visible && (root.player?.isPlaying ?? false) && (root.player?.positionSupported ?? false)
            interval: 1000
            repeat: true
            onTriggered: root.player.positionChanged()
        }
    }

    // ===== 開關 =====
    property Item toggles: Column {
        width: root.menuWidth
        spacing: 4

        // 方塊由左到右排，滿兩個換行（看不見的不佔位置）。
        Flow {
            width: parent.width
            spacing: 8

            MenuTile {
                width: (root.menuWidth - parent.spacing) / 2
                icon: "" // monitor
                label: I18n.tr("螢幕常亮")
                checked: root.keepAwake
                onClicked: root.keepAwake = !root.keepAwake
            }
            // 有外接螢幕才出現。外接兩台以上時先展開清單選要鏡像到哪一台。
            MenuTile {
                width: (root.menuWidth - parent.spacing) / 2
                visible: Mirror.available
                icon: "" // screen_share
                label: I18n.tr("螢幕鏡像")
                checked: Mirror.active
                onClicked: {
                    if (Mirror.active)
                        Mirror.stop();
                    else if (Mirror.targets.length === 1)
                        Mirror.start(Mirror.targets[0]);
                    else
                        root.mirrorPickOpen = !root.mirrorPickOpen;
                }
            }
            // 有加速度計才出現；平板模式時自動打開，見 AutoRotate。
            MenuTile {
                width: (root.menuWidth - parent.spacing) / 2
                visible: AutoRotate.available
                icon: "" // screen_rotation
                label: I18n.tr("自動旋轉")
                checked: AutoRotate.enabled
                onClicked: AutoRotate.toggle()
            }
            // 開關管暫停／繼續輪換；設定裡關掉自動輪換時開關不能按，只剩「下一張」。
            MenuTile {
                width: (root.menuWidth - parent.spacing) / 2
                visible: Wallpaper.available
                icon: "" // wallpaper
                label: I18n.tr("桌布輪換")
                checked: Wallpaper.cfg.rotate && !Wallpaper.paused
                toggleEnabled: Wallpaper.cfg.rotate
                action: "" // skip_next
                onClicked: Wallpaper.setPaused(!Wallpaper.paused)
                onActionClicked: Wallpaper.next()
            }
        }

        Rectangle {
            visible: root.mirrorPickOpen && Mirror.available && !Mirror.active
            width: parent.width
            height: mirrorColumn.implicitHeight + 8
            radius: 10
            color: Colors.panelRaised

            Column {
                id: mirrorColumn
                x: 4
                y: 4
                width: parent.width - 8

                Repeater {
                    model: Mirror.targets
                    delegate: MenuEntry {
                        required property var modelData
                        width: mirrorColumn.width
                        icon: "" // tv
                        label: Mirror.label(modelData)
                        hoverColor: Qt.lighter(Colors.panelRaised, 1.4)
                        onClicked: {
                            root.mirrorPickOpen = false;
                            Mirror.start(modelData);
                        }
                    }
                }
            }
        }
    }

    property Item separator2: MenuSeparator {
        width: root.menuWidth
        visible: root.batterySection.visible
    }

    // ===== 電池 =====
    property Item batterySection: Column {
        visible: Battery.devices.length > 0
        width: root.menuWidth
        spacing: 2

        BatteryLine {
            visible: Battery.laptop !== null
            device: Battery.laptop
        }

        MenuEntry {
            visible: Battery.peripherals.length > 0
            width: parent.width
            icon: root.peripheralsOpen ? "" : "" // expand_less / expand_more
            label: I18n.tr("其他裝置（%1）", Battery.peripherals.length)
            onClicked: root.peripheralsOpen = !root.peripheralsOpen
        }
        Repeater {
            model: root.peripheralsOpen ? Battery.peripherals : []
            delegate: BatteryLine {
                required property var modelData
                device: modelData
            }
        }
    }

    property Item separator3: MenuSeparator { width: root.menuWidth }

    // ===== 選項：截圖、設定、其他電源動作 =====
    property Item powerList: Column {
        width: root.menuWidth
        spacing: 2

        MenuEntry {
            width: parent.width
            icon: "" // screenshot_monitor
            label: I18n.tr("截圖")
            trailing: root.shotOpen ? "" : "" // expand_less / expand_more
            onClicked: root.shotOpen = !root.shotOpen
        }
        Item {
            visible: root.shotOpen
            width: parent.width
            height: root.shotRow.height + 4
            data: [root.shotRow]
        }
        MenuEntry {
            width: parent.width
            icon: "" // settings
            label: I18n.tr("設定")
            onClicked: {
                root.visible = false;
                Settings.open();
            }
        }
        MenuEntry {
            width: parent.width
            icon: root.moreOpen ? "" : "" // expand_less / expand_more
            label: I18n.tr("其他")
            onClicked: root.moreOpen = !root.moreOpen
        }
        Repeater {
            model: root.moreOpen ? root.moreActions : []
            delegate: PowerEntry {
                leftPadding: 24
            }
        }
    }

    // ----- 共用元件 -----

    // 圓形的扁平圖示按鈕；active 時用娜璉色填色。
    component IconButton: Rectangle {
        id: iconButton
        property string icon
        property bool active: false
        property real size: 36
        property real iconSize: Theme.fontPx(20)
        signal clicked

        width: size
        height: size
        radius: size / 2
        opacity: enabled ? 1 : 0.4
        color: active ? Colors.accent : iconArea.containsMouse ? Colors.panelRaised : "transparent"

        MenuIcon {
            anchors.centerIn: parent
            text: iconButton.icon
            font.pixelSize: iconButton.iconSize
            color: iconButton.active ? Colors.accentFg : Colors.shellFg
        }
        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconButton.clicked()
        }
    }

    // 電源動作：關選單再執行。
    component PowerEntry: MenuEntry {
        required property var modelData
        width: root.menuWidth
        icon: modelData.icon
        label: modelData.label
        onClicked: {
            root.visible = false;
            modelData.run();
        }
    }

    // 一個電池裝置：圖示、名稱、電量、狀態（筆電另外加剩餘時間）。
    component BatteryLine: Row {
        id: line
        property var device: null
        readonly property string lvl: device ? Battery.level(device) : "normal"
        readonly property color fg: lvl === "critical" ? Colors.chaeyoung
                                  : lvl === "warning" ? Colors.jihyo : Colors.shellFg

        width: root.menuWidth
        height: 32
        spacing: 12
        leftPadding: 12

        MenuIcon {
            width: 20
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            text: line.device ? Battery.kindIcons[line.device.type] ?? Battery.batteryIcon : ""
            color: line.fg
        }
        MenuLabel {
            width: parent.width - 12 - 20 - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            color: line.fg
            text: {
                const d = line.device;
                if (!d)
                    return "";
                const time = d.isLaptopBattery ? Battery.timeText(d) : "";
                const name = d.isLaptopBattery ? I18n.tr("筆電") : (d.model || I18n.tr("未知裝置"));
                const summary = I18n.tr("%1　%2%　%3", name, Battery.pct(d), Battery.stateName(d));
                return time ? I18n.tr("%1，%2", summary, time) : summary;
            }
        }
    }

    // 麥克風：左邊圖示切換靜音＋音量滑桿，寬度跟音量滑桿對齊。
    component MicRow: Row {
        width: parent.width
        spacing: 4

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: !root.micReady || root.source.audio.muted ? "\ue02b" : "\ue029" // mic_off / mic
            onClicked: if (root.micReady)
                root.source.audio.muted = !root.source.audio.muted
        }
        PanelSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 2 * 36 - 2 * parent.spacing
            enabled: root.micReady
            value: root.micReady ? root.source.audio.volume : 0
            onMoved: v => root.source.audio.volume = v
        }
    }

    // 0–1 的滑桿。拖動時顯示拖動中的值並送出 moved，放開後回到外部綁定的 value。
    component PanelSlider: Item {
        id: slider
        property real value: 0
        signal moved(real value)

        readonly property real knob: 18
        readonly property real shown: area.pressed ? area.dragValue : value

        function clamp(v) {
            return Math.max(0, Math.min(1, v));
        }

        height: 36
        opacity: enabled ? 1 : 0.5

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: slider.knob / 2
            width: parent.width - slider.knob
            height: 6
            radius: 3
            color: Theme.dialogDark.track

            Rectangle {
                width: parent.width * slider.shown
                height: parent.height
                radius: parent.radius
                color: Colors.accent
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: slider.shown * (parent.width - slider.knob)
            width: slider.knob
            height: slider.knob
            radius: slider.knob / 2
            color: Colors.shellFg
        }
        MouseArea {
            id: area
            property real dragValue: 0

            function at(x) {
                return slider.clamp((x - slider.knob / 2) / (width - slider.knob));
            }

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => {
                dragValue = at(mouse.x);
                slider.moved(dragValue);
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                dragValue = at(mouse.x);
                slider.moved(dragValue);
            }
            // 每格 5%。
            onWheel: wheel => slider.moved(slider.clamp(slider.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
        }
    }
}
