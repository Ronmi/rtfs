// 鎖定畫面（取代 swaylock）：ext-session-lock 協定（WlSessionLock）＋PAM 驗證（PamContext）。
// 畫面內容在 LockContent.qml，每個螢幕一份；這裡管狀態、驗證和當機後的重新鎖定。
// IPC：qs ipc call lock lock｜preview｜status。刻意沒有 unlock：只能用密碼解鎖。
//
// 安全性靠 compositor：qs 在鎖定中當掉或被關掉，niri 會保持鎖定（整片純色）。
// 這時 QuickShell 的 crash handler 會重新啟動 qs，啟動時看到旗標檔就馬上再鎖一次；
// niri 在舊的鎖定程式已經死掉時接受新的鎖定（niri src/niri.rs Niri::lock()）。
// 旗標檔殘留（例如 niri 自己在鎖定中當掉）頂多是下次登入時多鎖一次，不會讓畫面在該鎖時沒鎖。
// 最後手段：切到 TTY 執行 WAYLAND_DISPLAY=wayland-1 swaylock 接手後解鎖，所以 swaylock 要留著。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

Singleton {
    id: root

    readonly property bool locked: persist.locked
    // compositor 確認所有螢幕都蓋上鎖定畫面了。
    readonly property bool secure: session.secure
    // 預覽：同樣的畫面放在一般視窗裡，不真的鎖定（開發時截圖、試驗 PAM 用）。
    property bool previewing: false
    // 鎖定畫面上的螢幕鍵盤（LockContent 裡，直接改輸入框，不經過 rtfs-vkbd）。跟一般的螢幕鍵盤分開，
    // 只在鎖定、預覽開始時沿用它的開關：平板模式下鍵盤開著就鎖定，解鎖時不用再按一次。
    property bool oskShown: false

    // 驗證中（已送出密碼，等 PAM 回覆；login 設定裡的 pam_faildelay 會讓失敗等 3 秒）。
    readonly property bool busy: pam.active
    // 顯示在輸入框下方的訊息（密碼錯誤、PAM 的提示）。
    property string status: ""
    property bool statusIsError: false

    readonly property string flagPath: Quickshell.env("XDG_RUNTIME_DIR") + "/rtfs-locked"

    // 送出後清空每個螢幕的輸入框。
    signal cleared

    // 熱重載不能解除鎖定；bool 會被 PersistentProperties 保留下來（WlSessionLock 自己也會把鎖交給新的實例）。
    PersistentProperties {
        id: persist
        reloadableId: "lockScreen"

        property bool locked: false
    }

    function lock() {
        if (persist.locked)
            return;
        previewing = false;
        reset();
        oskShown = Osk.shown;
        // 先寫旗標再鎖：鎖定途中當掉也會在重啟後鎖上。
        Quickshell.execDetached(["touch", flagPath]);
        persist.locked = true;
        lockCheck.restart();
    }

    // 再呼叫一次就關閉預覽。
    function preview() {
        if (persist.locked)
            return;
        reset();
        oskShown = Osk.shown;
        previewing = !previewing;
    }

    // 輸入框按 Enter。PAM 還沒開始就先開始，等它要求回覆時再交出密碼（見 PamContext）。
    property string pending: ""

    function submit(password) {
        if (busy || password === "")
            return;
        status = "";
        statusIsError = false;
        pending = password;
        cleared();
        if (!pam.start()) {
            pending = "";
            setStatus(I18n.tr("無法啟動驗證"), true);
        }
    }

    function setStatus(text, isError) {
        status = text;
        statusIsError = isError;
    }

    function reset() {
        if (pam.active)
            pam.abort();
        pending = "";
        status = "";
        statusIsError = false;
        cleared();
    }

    function authenticated() {
        // 留紀錄：當機重啟等狀況之後，才查得出解鎖是不是經過密碼驗證。
        console.info("LockScreen: authenticated, unlocking");
        previewing = false;
        if (persist.locked) {
            persist.locked = false;
            finishUnlock();
        }
    }

    // 解鎖後（或鎖定失敗後）的清理。不能靠 WlSessionLock 的 onLockedChanged：
    // v0.3.2 的 unlock() 先解鎖才檢查 isLocked()，所以解鎖時永遠不會發出 lockStateChanged。
    function finishUnlock() {
        reset();
        Quickshell.execDetached(["rm", "-f", flagPath]);
    }

    // 鎖定失敗（例如另一個鎖定程式正在鎖）時 WlSessionLock 會自己放棄，同樣沒有 signal，所以過一下再檢查。
    Timer {
        id: lockCheck
        interval: 1000
        onTriggered: {
            if (persist.locked && !session.locked) {
                console.warn("LockScreen: failed to acquire session lock");
                persist.locked = false;
                root.finishUnlock();
                Config.notify(I18n.tr("無法鎖定螢幕（可能有其他鎖定程式正在執行）"));
            }
        }
    }

    // 用預設的 login 設定（/etc/pam.d/login，系統一定有）；swaylock 的設定檔會跟著 swaylock 移除，屆時就無法解鎖。
    PamContext {
        id: pam

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            // 只有密碼這一種提問；萬一還有第二個問題，送空字串讓它失敗，而不是卡住。
            respond(root.pending);
            root.pending = "";
        }
        // 提問本身（「Password:」）不顯示；其他訊息（例如帳號過期）照原樣顯示。
        onPamMessage: {
            if (!responseRequired && message !== "")
                root.setStatus(message, messageIsError);
        }
        onCompleted: result => {
            root.pending = "";
            if (result === PamResult.Success)
                root.authenticated();
            else if (result === PamResult.Failed)
                root.setStatus(I18n.tr("密碼錯誤"), true);
            else
                root.setStatus(I18n.tr("驗證失敗（%1），請再試一次", PamResult.toString(result)), true);
        }
        onError: err => console.warn("LockScreen: PAM error", PamError.toString(err))
    }

    WlSessionLock {
        id: session
        locked: persist.locked

        WlSessionLockSurface {
            id: surface
            // 圖還沒載入前露出的底色；文件建議不要用透明。
            color: Colors.shellBg

            LockContent {
                anchors.fill: parent
                screenName: surface.screen?.name ?? ""
            }
        }
    }

    // 全螢幕 Overlay，跟真的鎖定畫面一樣蓋過 kitty 的快速終端機等 Top layer；Exclusive 才能打字。
    PanelWindow {
        visible: root.previewing
        screen: Quickshell.screens[0] ?? null
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "rtfs-lock-preview"
        color: Colors.shellBg

        LockContent {
            anchors.fill: parent
            screenName: Quickshell.screens[0]?.name ?? ""
            preview: true
        }
    }

    // 啟動（含當機後重啟）時旗標還在 → 上次是在鎖定中結束的，馬上再鎖。
    Process {
        running: true
        command: ["test", "-e", root.flagPath]
        onExited: code => {
            if (code === 0 && !persist.locked) {
                console.warn("LockScreen: lock flag found at startup, locking again");
                Quickshell.execDetached(["touch", root.flagPath]);
                persist.locked = true;
                lockCheck.restart();
            }
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
        function preview(): void {
            root.preview();
        }
        function status(): string {
            return JSON.stringify({
                locked: root.locked,
                secure: root.secure
            });
        }
    }
}
