// 設定視窗的開關（IPC target "settings"：open／close）。視窗本身見 SettingsWindow.qml；設定的內容見 Config。
// 系統選單的設定按鈕也是呼叫這裡。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool shown: false

    function open() {
        shown = true;
    }
    function close() {
        shown = false;
    }

    // 關掉就銷毀，下次打開重新讀目前的設定值。
    LazyLoader {
        active: root.shown

        SettingsWindow {
            onDone: root.close()
        }
    }

    IpcHandler {
        target: "settings"

        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
    }
}
