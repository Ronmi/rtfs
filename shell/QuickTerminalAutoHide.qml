// niri overview 開著時收起 kitty quick-access-terminal，關閉 overview 後再打開回來。
// overview 期間 niri 一律把 Top 層畫在 overview 上面，而 quick-access-terminal 是 Top 層（見 niri 專案的
// memories/quick-access-terminal.md），會整個蓋住 overview。
// kitty 收起面板時不會移除 layer surface，niri 的 Layers 查詢仍列得到它。所在圖層不可靠（2026-11-06 量到
// 收起時移到 Background，2026-11-10 量到一直停在 Top，overview 因此反而把面板打開），但鍵盤互動兩次都一樣：
// 開著是 Exclusive（--focus-policy=exclusive）、收起是 None，所以用它判斷開關。
// kitten quick-access-terminal 是切換，必須先確認狀態再呼叫。
import QtQuick
import Quickshell

Item {
    id: root

    readonly property string namespace: "kitty-quick-access"
    // 這次 overview 是否由我們收起了面板（只有這種情況才在關閉時打開回來）。
    property bool hiddenByUs: false

    function toggleTerminal() {
        Quickshell.execDetached(["kitten", "quick-access-terminal"]);
    }

    // onState 收到面板是否開著；沒有面板時是 false。
    function terminalShown(onState) {
        Niri.query("Layers", ok => {
            const panel = ok.Layers.find(l => l.namespace === root.namespace);
            onState(!!panel && panel.keyboard_interactivity === "Exclusive");
        });
    }

    Connections {
        target: Niri

        function onOverviewOpenChanged() {
            if (Niri.overviewOpen) {
                root.terminalShown(shown => {
                    if (shown) {
                        root.hiddenByUs = true;
                        root.toggleTerminal();
                    }
                });
            } else if (root.hiddenByUs) {
                root.hiddenByUs = false;
                // 再確認一次仍是收起的，以免 overview 期間使用者自己動過面板、被我們反向切換。
                root.terminalShown(shown => {
                    if (!shown)
                        root.toggleTerminal();
                });
            }
        }
    }
}
