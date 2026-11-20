// niri IPC（$NIRI_SOCKET，每行一個 JSON）。
// 一條連線送 "EventStream" 後持續接收事件，維護工作區與視窗狀態；另一條連線送動作請求。
// 事件格式見 niri v26.04 的 niri-ipc/src/lib.rs（enum Event）。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // niri IPC 的 Workspace 物件（id、idx、output、is_active、is_focused、is_urgent…），依 idx 排序。
    property var workspaces: []
    // 目前聚焦的螢幕名稱（聚焦的工作區所在的螢幕）。
    readonly property string focusedOutput: workspaces.find(w => w.is_focused)?.output ?? ""
    // niri 的 overview 是否開著（OverviewOpenedOrClosed 事件）。
    property bool overviewOpen: false
    // niri IPC 的 Window 物件（id、app_id、title、workspace_id…）。
    property var windows: []

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""

    function focusWorkspace(id) {
        // 用 id 指定：CLI 的 focus-workspace 只能用「目前聚焦螢幕上的序號」，多螢幕時會切錯螢幕。
        send({ Action: { FocusWorkspace: { reference: { Id: id } } } });
    }

    function focusMonitor(output) {
        send({ Action: { FocusMonitor: { output: output } } });
    }

    function toggleOverview() {
        send({ Action: { ToggleOverview: {} } });
    }

    // 等待回覆的 callback；niri 依請求順序逐行回覆，所以用佇列一一對應（不需要回覆的放 null）。
    property var pendingReplies: []

    function send(request, onReply) {
        if (!requests.connected) {
            console.warn("niri: request socket not connected, dropped", JSON.stringify(request));
            return;
        }
        pendingReplies.push(onReply ?? null);
        requests.write(JSON.stringify(request) + "\n");
        requests.flush();
    }

    // 查詢資料：onReply 收到 Ok 的內容，例如 query("Layers", r => r.Layers)。
    function query(request, onReply) {
        send(request, reply => {
            if (reply.Ok !== undefined)
                onReply(reply.Ok);
        });
    }

    function handleEvent(line) {
        const msg = JSON.parse(line);
        if (msg.Err !== undefined) {
            console.warn("niri: event stream error", msg.Err);
        } else if (msg.WorkspacesChanged) {
            workspaces = msg.WorkspacesChanged.workspaces.sort((a, b) => a.idx - b.idx);
        } else if (msg.WorkspaceActivated) {
            const ev = msg.WorkspaceActivated;
            const output = workspaces.find(w => w.id === ev.id)?.output;
            // 同一個螢幕上只有一個 active；focused 則是全域唯一。
            // 整個陣列換成新的，綁定 workspaces 的畫面才會更新。
            workspaces = workspaces.map(w => Object.assign({}, w, {
                is_active: w.output === output ? w.id === ev.id : w.is_active,
                is_focused: ev.focused ? w.id === ev.id : w.is_focused
            }));
        } else if (msg.WorkspaceUrgencyChanged) {
            const ev = msg.WorkspaceUrgencyChanged;
            workspaces = workspaces.map(w => w.id === ev.id ? Object.assign({}, w, { is_urgent: ev.urgent }) : w);
        } else if (msg.OverviewOpenedOrClosed) {
            overviewOpen = msg.OverviewOpenedOrClosed.is_open;
        } else if (msg.WindowsChanged) {
            windows = msg.WindowsChanged.windows;
        } else if (msg.WindowOpenedOrChanged) {
            const win = msg.WindowOpenedOrChanged.window;
            windows = windows.filter(w => w.id !== win.id).concat([win]);
        } else if (msg.WindowClosed) {
            const id = msg.WindowClosed.id;
            windows = windows.filter(w => w.id !== id);
        }
        // 其他事件（鍵盤配置…）目前用不到。
    }

    Socket {
        id: events
        path: root.socketPath
        connected: true
        parser: SplitParser {
            onRead: line => root.handleEvent(line)
        }
        onConnectionStateChanged: {
            if (connected) {
                write('"EventStream"\n');
                flush();
            } else {
                retry.start();
            }
        }
        onError: retry.start()
    }

    Socket {
        id: requests
        path: root.socketPath
        connected: true
        parser: SplitParser {
            onRead: line => {
                const reply = JSON.parse(line);
                const callback = root.pendingReplies.shift();
                if (reply.Err !== undefined)
                    console.warn("niri: request failed", reply.Err);
                else if (callback)
                    callback(reply);
            }
        }
        onConnectionStateChanged: {
            if (!connected) {
                // 斷線時還沒收到的回覆不會來了，清掉以免之後對錯請求。
                root.pendingReplies = [];
                retry.start();
            }
        }
        onError: retry.start()
    }

    // QuickShell 的 Socket 斷線或連不上時不會自己重連（例如 niri 重啟），這裡每秒重試。
    Timer {
        id: retry
        interval: 1000
        onTriggered: {
            if (!events.connected) events.connected = true;
            if (!requests.connected) requests.connected = true;
        }
    }
}
