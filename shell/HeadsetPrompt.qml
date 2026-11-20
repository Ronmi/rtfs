// 二合一耳機孔插上東西時，用通知問是耳機還是耳麥（GNOME 用對話框問；這裡忽略通知就維持預設）。
// 偵測、通知與切換都在 scripts/rtfs-jack；這裡只負責讓它跟著 shell 跑（GNOME 底下不會啟動）。
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    Process {
        id: helper
        command: [Quickshell.shellDir + "/../scripts/rtfs-jack"]
        running: true
        // stdin 關閉時 helper 會跟著結束，qs 結束時不會留下孤兒。
        stdinEnabled: true
        // 缺 alsactl／pw-dump 時以 0 結束，不必重開；其他情況是掛了，過一會兒重開。
        onExited: code => {
            if (code !== 0)
                restart.start();
        }
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: helper.running = true
    }
}
