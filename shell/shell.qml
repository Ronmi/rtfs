// QuickShell 進入點（~/.config/quickshell 指向 shell/）。
import QtQuick
import Quickshell

ShellRoot {
    // singleton 在第一次被用到時才建立；ShellState 要一啟動就註冊 IPC，所以在這裡先碰它一下。
    // Launcher 同理（IPC 給 niri 的 Mod+D 用），Dialogs 也是（IPC 給 rtfs-ui 用），
    // LockScreen 也是（IPC 給 niri 的 Super+Alt+L 用，而且當機重啟後要馬上檢查要不要重新鎖定）；Settings 同理（IPC settings）。
    // AutoRotate 要一啟動就跟著平板模式切換，不能等到主選單第一次用到。
    Component.onCompleted: {
        ShellState.tabletMode;
        Launcher.shown;
        Dialogs.current;
        LockScreen.locked;
        Settings.shown;
        AutoRotate.enabled;
    }
    // 每個螢幕一個桌布視窗；螢幕接上、拔掉時自動增減。
    Variants {
        model: Quickshell.screens
        WallpaperWindow {}
    }
    Bar {}
    NotificationBanners {}
    // overview 在每個螢幕上都會開，所以每個螢幕各一個「所有程式」按鈕。
    Variants {
        model: Quickshell.screens
        OverviewButton {}
    }
    QuickTerminalAutoHide {}
    PolkitDialog {}
    SystemOsd {}
    OskWindow {}
    AutoLock {}
    HeadsetPrompt {}
}
