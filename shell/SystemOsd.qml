// 音量、靜音、麥克風靜音、亮度改變時顯示 OSD。看的是數值本身的變化，不是按鍵，
// 所以不管從快捷鍵、bar 的滾輪還是其他程式調整都會顯示，niri 的按鍵設定不用動。
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // Pipewire 節點要被追蹤，音量、靜音才會有值並即時更新。
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
    }

    // 剛開始追蹤或換了預設裝置時，數值會從 0 跳到實際值，那不是使用者調整的；
    // 換裝置後等一下，數值穩定了才開始反應，並記下當時的值當作比較基準。
    property bool settled: false
    property real lastVolume: -1
    property bool lastMuted: false
    property bool lastMicMuted: false

    onSinkChanged: settle()
    onSourceChanged: settle()
    function settle() {
        settled = false;
        settleTimer.restart();
    }
    Timer {
        id: settleTimer
        interval: 1000
        running: true
        onTriggered: {
            root.lastVolume = root.sink?.audio?.volume ?? -1;
            root.lastMuted = root.sink?.audio?.muted ?? false;
            root.lastMicMuted = root.source?.audio?.muted ?? false;
            root.settled = true;
        }
    }

    // 各聲道的音量會分別通知，平均值沒變時不重複顯示。
    function sinkUpdated() {
        if (!settled || !sink?.audio)
            return;
        const v = sink.audio.volume, m = sink.audio.muted;
        if (Math.abs(v - lastVolume) < 0.001 && m === lastMuted)
            return;
        lastVolume = v;
        lastMuted = m;
        // 比較基準照樣更新，之後重新打開設定時才不會把舊的變化補顯示出來。
        if (!Config.notifications.osd.volume)
            return;
        // 靜音時也顯示音量：wpctl 調音量不會解除靜音，不然調了看不到結果。
        const percent = Math.round(v * 100);
        Osd.show({
            glyph: m || percent === 0 ? "" : percent < 50 ? "" : "",
            text: m ? I18n.tr("靜音") : "",
            value: percent,
            showValue: true
        });
    }
    function sourceUpdated() {
        if (!settled || !source?.audio || source.audio.muted === lastMicMuted)
            return;
        lastMicMuted = source.audio.muted;
        if (!Config.notifications.osd.microphone)
            return;
        Osd.show(lastMicMuted ? { glyph: "", text: I18n.tr("麥克風已靜音") }
                              : { glyph: "", text: I18n.tr("麥克風已開啟") });
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumesChanged() { root.sinkUpdated(); }
        function onMutedChanged() { root.sinkUpdated(); }
    }
    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() { root.sourceUpdated(); }
    }

    Connections {
        target: Backlight
        function onAdjusted() {
            if (Config.notifications.osd.brightness)
                Osd.show({ glyph: "", value: Backlight.percent, showValue: true });
        }
    }
}
