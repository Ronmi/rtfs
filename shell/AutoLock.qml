// 自動鎖定：閒置一段時間後鎖定、鎖定中閒置一段時間後關掉螢幕、睡眠／休眠前先鎖定。設定在 Config.lock。
// 閒置判斷用 compositor 的 ext-idle-notify（IdleMonitor），播影片等程式的閒置抑制會讓它不算閒置。
// 睡前鎖定靠 scripts/rtfs-sleep-lock 向 logind 拿 delay inhibitor（QuickShell 不能直接用 D-Bus）：
// 收到 sleep 就鎖，畫面確實蓋好（secure）或鎖定失敗後才回 ready，讓系統繼續睡，醒來時畫面已經是鎖著的。
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    // v0.3.2 的 IdleMonitor 啟用中改 timeout 不會生效（2026-11-07 實測；先停用再啟用才會用新的值），
    // 所以秒數一改（包括啟動時設定檔讀完、從預設值換成使用者的值）就關掉，下一輪事件迴圈再打開
    // （同一個 handler 裡關了馬上開沒有用，也是實測）。
    // 鎖定後就停用，解鎖後重新建立，從那時重新計時。
    IdleMonitor {
        property bool kick: false
        enabled: Config.lock.idleLock > 0 && !LockScreen.locked && !kick
        timeout: Config.lock.idleLock
        onTimeoutChanged: {
            kick = true;
            Qt.callLater(() => kick = false);
        }
        onIsIdleChanged: if (isIdle) LockScreen.lock()
    }

    // 鎖定的那一刻開始計時；niri 在有輸入時會自己把螢幕打開。
    IdleMonitor {
        id: screenOffMonitor
        property bool kick: false
        enabled: Config.lock.screenOff > 0 && LockScreen.locked && !kick
        timeout: Config.lock.screenOff
        onTimeoutChanged: {
            kick = true;
            Qt.callLater(() => kick = false);
        }
        onIsIdleChanged: if (isIdle) Niri.send({ Action: { PowerOffMonitors: {} } })
    }

    Binding {
        target: ShellState
        property: "screensOff"
        value: screenOffMonitor.enabled && screenOffMonitor.isIdle
    }

    // 等著回 ready 給 logind 的睡眠請求。
    property bool sleepPending: false

    function answerSleep() {
        if (sleepPending && (LockScreen.secure || !LockScreen.locked)) {
            sleepPending = false;
            sleeper.write("ready\n");
        }
    }

    Connections {
        target: LockScreen
        function onSecureChanged() { root.answerSleep(); }
        function onLockedChanged() { root.answerSleep(); }
    }

    // running 不用 binding：程式自己結束時 Process 會把 running 改成 false，binding 不會再把它拉起來。
    readonly property bool sleepWanted: Config.lock.beforeSleep
    onSleepWantedChanged: sleeper.running = sleepWanted
    Component.onCompleted: sleeper.running = sleepWanted

    Process {
        id: sleeper
        command: [Quickshell.shellDir + "/../scripts/rtfs-sleep-lock"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                let msg;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (msg.event === "sleep") {
                    console.info("AutoLock: system is going to sleep, locking");
                    root.sleepPending = true;
                    LockScreen.lock();
                    root.answerSleep();
                } else if (msg.event === "resume") {
                    root.sleepPending = false;
                }
            }
        }
        // 意外結束（例如 logind 重啟）時過一下再啟動，不然睡前就不會鎖了。
        onExited: code => {
            if (root.sleepWanted) {
                console.warn("AutoLock: rtfs-sleep-lock exited with", code, "- restarting");
                restart.start();
            }
        }
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: sleeper.running = root.sleepWanted
    }
}
