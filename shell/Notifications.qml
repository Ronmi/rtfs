// 通知服務（取代 swaync）：接收 org.freedesktop.Notifications、保存通知清單、決定哪些要彈出。
// 同一時間只能有一個通知服務，swaync 還在跑時這裡拿不到 D-Bus 名稱。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    // 同時彈出的上限；更多的只收進通知中心。
    readonly property int maxBanners: 3
    // 程式沒指定時，一般與低緊急程度的通知彈出幾秒。
    readonly property real defaultTimeout: Config.notifications.timeout

    // 勿擾：不彈出（緊急通知例外，跟 GNOME 一樣），只收進通知中心。
    property bool dnd: false

    // 所有保留中的通知（舊的在前）。
    readonly property var list: server.trackedNotifications.values
    // 目前彈出中的通知（新的在前）。
    property var banners: []

    // 時鐘面板（通知中心）開著時不彈出：通知直接出現在列表裡（跟 GNOME 一樣），也不會疊在面板上。
    property bool centerOpen: false
    onCenterOpenChanged: if (centerOpen) banners = []

    // 有沒有還沒看過的通知；打開時鐘面板就算看過（ClockPopup 會清掉）。
    property bool unread: false
    readonly property bool hasUnread: unread && list.length > 0

    // 收到時間（通知物件本身沒有）；key 是通知 id。熱重載後會遺失，那時就不顯示時間。
    property var receivedAt: ({})

    // 請時鐘面板（通知中心）開關；ClockBlock 接這個 signal。
    signal toggleCenterRequested

    // 給 niri 快捷鍵用：qs ipc call notifications <函式>（例如 Mod+N → toggleCenter）。
    IpcHandler {
        target: "notifications"

        function toggleCenter(): void {
            root.toggleCenterRequested();
        }
        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }
        function clearAll(): void {
            root.clearAll();
        }
    }

    function clearAll() {
        // dismiss 會讓通知從 list 移除，所以先複製一份。
        for (const n of list.slice())
            n.dismiss();
    }

    function hideBanner(n) {
        banners = banners.filter(b => b !== n);
    }

    // 彈出幾秒；0 表示一直留著，直到使用者關掉。
    function bannerTimeout(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        // D-Bus 規格：0 = 永不過期，-1 = 由伺服器決定（QuickShell 換算成秒後是負數）。
        if (n.expireTimeout === 0)
            return 0;
        return n.expireTimeout > 0 ? n.expireTimeout : defaultTimeout;
    }

    NotificationServer {
        id: server

        // 熱重載時保留通知（qs 重啟後仍會清空）。
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        actionsSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: n => {
            // 不設 tracked，通知會在這個 handler 結束後被丟掉。
            n.tracked = true;
            const times = Object.assign({}, root.receivedAt);
            times[n.id] = new Date();
            root.receivedAt = times;
            // 面板開著時，通知就出現在眼前的列表裡，不算未讀。
            if (!root.centerOpen)
                root.unread = true;

            if (!root.centerOpen && (!root.dnd || n.urgency === NotificationUrgency.Critical))
                root.banners = [n].concat(root.banners.filter(b => b.id !== n.id)).slice(0, root.maxBanners);

            // 通知被關閉（使用者、逾時、程式收回）後物件會被銷毀，先從彈出清單移掉。
            n.closed.connect(() => root.hideBanner(n));
        }
    }
}
