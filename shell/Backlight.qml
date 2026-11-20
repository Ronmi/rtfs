// 螢幕背光亮度（sysfs）。用 FileView 監看 brightness：inotify 只在有程式寫入這個檔案時通知
// （brightnessctl、logind 都是），韌體自己改的不會；這台的亮度鍵是 niri 呼叫 brightnessctl，所以夠用。
// 2026-11-07 實測寫入時 inotify 與 udev 事件都會出現；選 FileView 是因為不用多開常駐程式。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // 用第一個背光裝置（筆電通常只有一個）。FileView 不能列目錄，所以啟動時用 ls 找一次。
    property string device: ""
    readonly property string dir: device ? "/sys/class/backlight/" + device + "/" : ""

    Process {
        running: true
        command: ["ls", "/sys/class/backlight"]
        stdout: StdioCollector {
            onStreamFinished: root.device = text.split("\n")[0].trim()
        }
    }

    readonly property int max: parseInt(maxFile.text()) || 0
    property int raw: 0
    readonly property int percent: max > 0 ? Math.round(raw * 100 / max) : 0

    // 亮度被改了（不含啟動時第一次讀取）。
    signal adjusted

    property bool changePending: false

    FileView {
        id: maxFile
        path: root.dir ? root.dir + "max_brightness" : ""
    }
    FileView {
        path: root.dir ? root.dir + "brightness" : ""
        watchChanges: true
        onFileChanged: {
            root.changePending = true;
            reload();
        }
        onLoaded: {
            root.raw = parseInt(text()) || 0;
            if (root.changePending) {
                root.changePending = false;
                root.adjusted();
            }
        }
    }
}
