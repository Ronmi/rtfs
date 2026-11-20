// 電源設定檔（power-profiles-daemon）。所有元件都透過這裡讀寫，不要直接用 PowerProfiles。
// QuickShell 的 PowerProfiles 第一次被碰到時會同步 introspect D-Bus；daemon 還沒起來就會觸發
// activation 並卡住整個 QML 載入。ppd 排在 multi-user.target 之後，而 gdm 自動登入時寫死等 20 秒
// 才關 plymouth，所以開機時 bar 會晚 20 秒才出現。
// 因此先用 gdbus wait 等 ppd 出現在 system bus（不觸發 activation），之後才碰 PowerProfiles。
// ppd 若一直沒出現（沒裝、被停用），ready 就一直是 false。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    property bool ready: false

    // ready 之前不能求值 PowerProfiles，所以每個綁定都先檢查 ready。
    readonly property int profile: ready ? PowerProfiles.profile : -1
    readonly property bool hasPerformanceProfile: ready && PowerProfiles.hasPerformanceProfile

    function set(p) {
        if (ready) PowerProfiles.profile = p;
    }

    Process {
        running: true
        command: ["gdbus", "wait", "--system", "org.freedesktop.UPower.PowerProfiles"]
        onExited: code => {
            if (code === 0) root.ready = true;
            else console.warn("PowerProfileState: gdbus wait 失敗，exit code", code);
        }
    }
}
