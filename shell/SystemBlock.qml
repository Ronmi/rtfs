// 狀態列的系統選單色塊（娜璉色底）：音量圖示、筆電電量、麥克風、使用中的鏡頭、播放中的音符、螢幕常亮時的螢幕、電源圖示。
// 點擊開系統選單。
// 鎖定、睡眠、休眠直接執行；會丟失工作的登出、重新開機、關機先跳確認對話框（跟 GNOME 一樣）。
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland

Rectangle {
    id: root

    // 每個動作：icon（Material Icons）、label、run。
    // actions 是平常顯示的，moreActions 不常用、預設收在「其他」裡。
    readonly property var actions: [
        {
            icon: "", label: I18n.tr("重新開機…"), run: () => root.ask({ // restart_alt
                title: I18n.tr("重新開機"), message: I18n.tr("確定要重新開機嗎？未儲存的工作將會遺失。"), confirmText: I18n.tr("重新開機"),
                run: () => Quickshell.execDetached(["systemctl", "reboot"])
            })
        },
        {
            icon: "", label: I18n.tr("關機…"), run: () => root.ask({ // power_settings_new
                title: I18n.tr("關機"), message: I18n.tr("確定要關機嗎？未儲存的工作將會遺失。"), confirmText: I18n.tr("關機"),
                run: () => Quickshell.execDetached(["systemctl", "poweroff"])
            })
        }
    ]
    readonly property var moreActions: [
        { icon: "", label: I18n.tr("鎖定"), run: () => LockScreen.lock() }, // lock
        { icon: "", label: I18n.tr("睡眠"), run: () => Quickshell.execDetached(["systemctl", "suspend"]) }, // bedtime
        { icon: "", label: I18n.tr("休眠"), run: () => Quickshell.execDetached(["systemctl", "hibernate"]) }, // ac_unit
        {
            icon: "", label: I18n.tr("登出…"), run: () => root.ask({ // logout
                title: I18n.tr("登出"), message: I18n.tr("確定要登出 niri 嗎？未儲存的工作將會遺失。"), confirmText: I18n.tr("登出"),
                run: () => Niri.send({ Action: { Quit: { skip_confirmation: true } } })
            })
        }
    ]

    property var pending: null

    function ask(request) {
        pending = request;
        dialog.title = request.title;
        dialog.message = request.message;
        dialog.confirmText = request.confirmText;
        dialog.open();
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioReady: sink?.ready ?? false
    readonly property bool muted: audioReady && sink.audio.muted
    readonly property real volume: audioReady ? sink.audio.volume : 0

    // Pipewire 節點要被「追蹤」，音量、靜音這些屬性才會有值並即時更新。
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    // 螢幕常亮：開著時向 compositor 要求不進入閒置（AutoLock 的 IdleMonitor 也會遵守），
    // 所以不會自動鎖定或關螢幕。狀態只在記憶體裡，qs 重開就回到關閉。
    // IdleInhibitor 要掛在一個看得見的視窗上，用 bar 本身。
    IdleInhibitor {
        window: root.QsWindow.window
        enabled: menu.keepAwake
    }

    implicitWidth: row.implicitWidth + 2 * Theme.blockPadding
    implicitHeight: Theme.blockHeight
    radius: Theme.blockRadius
    color: Colors.nayeon

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        BarIcon {
            // volume_off / volume_mute / volume_down / volume_up
            text: !root.audioReady || root.muted || root.volume === 0 ? ""
                : root.volume < 0.34 ? "" : root.volume < 0.67 ? "" : ""
        }

        // 筆電電量；沒有筆電電池（桌機）就不顯示。電量低時用彩瑛紅字（對比不高，但足以讓人注意到）。
        Row {
            visible: Battery.laptop !== null
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            readonly property color fg: Battery.laptopLevel === "normal" ? Colors.inkDark : Colors.chaeyoung

            BarIcon {
                text: !Battery.laptop ? "" : Battery.charging(Battery.laptop) ? Battery.chargingIcon
                    : Battery.laptopLevel === "normal" ? Battery.batteryIcon : Battery.alertIcon
                color: parent.fg
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.laptop ? Battery.pct(Battery.laptop) + "%" : ""
                color: parent.fg
                font: Theme.blockFont
            }
        }

        // 麥克風接通時顯示（沒有硬體開關就看軟體靜音），錄音中改用彩瑛色。
        BarIcon {
            visible: Privacy.micOn
            text: "" // mic
            color: Privacy.recording ? Colors.chaeyoung : Colors.inkDark
        }

        // 鏡頭只在有程式使用時顯示。
        BarIcon {
            visible: Privacy.camera
            text: "" // videocam
            color: Colors.chaeyoung
        }

        // 有東西在播時提醒一下，控制在主選單裡。
        BarIcon {
            visible: Mpris.players.values.some(p => p.isPlaying)
            text: "" // music_note
        }

        // 螢幕常亮開著時提醒一下，免得忘了關。
        BarIcon {
            visible: menu.keepAwake
            text: "" // monitor
        }

        BarIcon {
            text: "" // power_settings_new
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.visible = !menu.visible
    }

    // 給快捷鍵用：qs ipc call menu toggle|open|close。選單開著時獨佔鍵盤，Esc 就能關。
    IpcHandler {
        target: "menu"

        function toggle(): void {
            if (menu.visible)
                close();
            else
                open();
        }
        function open(): void {
            // 鎖定時 session lock 本來就蓋在上面，但不要讓選單在背後搶鍵盤。
            if (!LockScreen.locked)
                menu.visible = true;
        }
        function close(): void {
            menu.visible = false;
        }
    }

    SystemPopup {
        id: menu
        anchorItem: root
        actions: root.actions
        moreActions: root.moreActions
    }

    ConfirmDialog {
        id: dialog
        onAccepted: root.pending?.run()
    }

    component BarIcon: Text {
        anchors.verticalCenter: parent.verticalCenter
        color: Colors.inkDark
        font.family: "Material Icons"
        font.pixelSize: Theme.blockFont.pixelSize + 4
    }
}
