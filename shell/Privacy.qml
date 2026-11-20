// 麥克風、鏡頭的隱私狀態，給狀態列和主選單用。
// 麥克風開關和鏡頭使用中由 scripts/rtfs-privacy 回報（EC 輪詢、/dev/video* 的 inotify）；
// 錄音中直接看 Pipewire。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // Framework 筆電的硬體麥克風開關：true 接通、false 切斷、null 沒有這種開關（桌機）。
    property var micSwitch: null
    // 沒有硬體開關（桌機）時看有沒有接麥克風，也就是有沒有任何輸入裝置。
    // 主機板內建音效卡的麥克風孔即使沒插也常會有輸入裝置，這時就一直顯示。
    readonly property bool micOn: micSwitch !== null ? micSwitch
        : Pipewire.nodes.values.some(n => n.type === PwNodeType.AudioSource)

    // 有程式正在錄音（跟 GNOME 一樣）。錄音串流要追蹤才讀得到 stream.monitor，
    // 用來排除音量計（例如 pavucontrol 開著時的那些）。
    readonly property var inStreams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioInStream)
    readonly property bool recording: inStreams.some(n => n.ready && String(n.properties["stream.monitor"]) !== "true")

    // 有程式開著鏡頭。鏡頭的硬體開關讀不到：FW12 的 EC 不回報，鏡頭只在串流時才送出 UVC Privacy 事件。
    property bool camera: false

    PwObjectTracker {
        objects: root.inStreams
    }

    Process {
        id: helper
        command: [Quickshell.shellDir + "/../scripts/rtfs-privacy"]
        running: true
        // 螢幕關著時停止輪詢 EC，免得閒置的筆電每秒被叫醒。
        stdinEnabled: true
        onStarted: write(ShellState.screensOff ? "pause\n" : "resume\n")
        stdout: SplitParser {
            onRead: line => {
                try {
                    const s = JSON.parse(line);
                    root.micSwitch = s.micSwitch;
                    root.camera = s.camera;
                } catch (e) {
                    console.warn("rtfs-privacy:", line);
                }
            }
        }
        // 不該結束；萬一掛了就過一會兒重開。
        onExited: restart.start()
    }

    Connections {
        target: ShellState
        function onScreensOffChanged() {
            if (helper.running)
                helper.write(ShellState.screensOff ? "pause\n" : "resume\n");
        }
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: helper.running = true
    }
}
