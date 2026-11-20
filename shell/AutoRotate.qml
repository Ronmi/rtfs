// 內建螢幕自動旋轉（跟 GNOME 一樣）：進平板模式時自動打開，回筆電模式時關閉並轉回正常方向；
// 兩種模式下都可以手動切換（主選單的方塊），手動關閉時固定在目前方向。狀態不寫進設定。
// 方向來自 iio-sensor-proxy：QuickShell 沒有通用的 D-Bus 介面，所以跑它附的 monitor-sensor 解析輸出；
// 只在打開時才跑（它執行期間會向 iio-sensor-proxy 要求加速度計）。旋轉交給 niri 的 Output Transform。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // 內建面板（eDP／LVDS／DSI 開頭），跟 Mirror 的判斷一樣。
    readonly property var panel: Quickshell.screens.find(s => /^(eDP|LVDS|DSI)-/.test(s.name)) ?? null
    // 有內建面板，且 iio-sensor-proxy 回報有加速度計（主選單的方塊只在這時出現）。
    readonly property bool available: hasAccel && panel !== null
    property bool enabled: false

    property bool hasAccel: false
    // 啟動時先跑一次 monitor-sensor 確認有沒有加速度計。
    property bool probed: false
    // 最後一次送給 niri 的方向，避免重複送。
    property string applied: ""

    // iio-sensor-proxy 的方向 → niri 的 Transform（逆時針）。實測：左邊朝上回報 left-up，要轉 90。
    // niri IPC 的名稱是 "Normal"、"90"…（跟 niri msg outputs --json 讀到的格式一樣）。
    readonly property var transforms: ({
        "normal": "Normal",
        "left-up": "90",
        "bottom-up": "180",
        "right-up": "270"
    })

    function toggle() {
        enabled = !enabled;
    }

    function apply(orientation) {
        const t = transforms[orientation];
        if (!t || !panel || t === applied)
            return;
        applied = t;
        Niri.send({ Output: { output: panel.name, action: { Transform: { transform: t } } } }, reply => {
            if (reply.Err !== undefined)
                console.warn("AutoRotate: niri refused transform", t, reply.Err);
        });
    }

    function updateSensor() {
        sensor.running = (enabled && hasAccel) || !probed;
    }

    onEnabledChanged: updateSensor()

    Connections {
        target: ShellState
        function onTabletModeChanged() {
            root.enabled = ShellState.tabletMode;
            if (!ShellState.tabletMode)
                root.apply("normal");
        }
    }

    Component.onCompleted: {
        enabled = ShellState.tabletMode;
        updateSensor();
    }

    Process {
        id: sensor
        // 輸出接到 pipe 時 monitor-sensor 會整塊緩衝，stdbuf 讓它逐行送出。
        command: ["stdbuf", "-oL", "monitor-sensor", "--accel"]
        stdout: SplitParser {
            // 「=== Has accelerometer (orientation: normal, tilt: …)」、
            // 「Accelerometer orientation changed: left-up」、「=== No accelerometer」。
            onRead: line => {
                if (line.includes("No accelerometer")) {
                    root.hasAccel = false;
                    root.probed = true;
                    root.updateSensor();
                    return;
                }
                if (line.includes("Has accelerometer")) {
                    root.hasAccel = true;
                    root.probed = true;
                    root.updateSensor();
                }
                const m = line.match(/orientation(?: changed)?: ([a-z-]+)/);
                if (m && root.enabled)
                    root.apply(m[1]);
            }
        }
        // 沒裝 monitor-sensor 時馬上結束；iio-sensor-proxy 重啟之類的意外結束則稍後重跑。
        onExited: {
            root.probed = true;
            if (root.enabled && root.hasAccel)
                restart.start();
        }
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: root.updateSensor()
    }
}
