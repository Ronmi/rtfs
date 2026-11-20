// 螢幕鍵盤的視窗：狀態列所在螢幕底部（可切到頂部）的完整筆電版面（狀態與送鍵在 Osk.qml）。
// 不拿鍵盤焦點，點按鍵時打字的目標仍是原本的視窗；保留區讓視窗縮開，不會被蓋住。
// 鍵盤畫面在 OskKeyboard.qml。有 modal 對話框開著時隱藏，改由 DialogFrame 畫在遮罩上面。
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    screen: ShellState.barScreen
    visible: Osk.shown && Osk.modals === 0

    anchors {
        top: Osk.atTop
        bottom: !Osk.atTop
        left: true
        right: true
    }
    // 底部：佔保留區，視窗縮開。頂部（osk.topReserve 關閉時）：避開 bar 但自己不佔保留區（exclusiveZone 0），
    // 浮在上面什麼都不推：固定高度的 kitty quick-access-terminal 只會被推出螢幕，不如讓它下方的提示列露出來。
    exclusionMode: Osk.atTop && !Config.osk.topReserve ? ExclusionMode.Normal : ExclusionMode.Auto
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "rtfs-osk"

    implicitHeight: keyboard.implicitHeight
    color: "transparent"

    OskKeyboard {
        id: keyboard
        anchors.fill: parent
    }
}
