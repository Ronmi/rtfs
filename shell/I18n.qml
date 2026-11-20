// 介面文字翻譯。QuickShell 不載入 Qt 的 .qm 翻譯檔（QML 也裝不了 QTranslator），所以 qsTr 沒有作用，改用自己的對照表：
// 程式裡的原文是繁體中文，shell/i18n/<語言>.json 是「原文 → 譯文」，譯文空白或沒有這一項就顯示原文。
// 語言照 gettext 的順序取環境變數 LANGUAGE（冒號分隔的清單）、LC_ALL、LC_MESSAGES、LANG，
// 每個依序試 ll_CC.json、ll.json；先碰到原文的語言（zh_TW／zh）就不翻譯。Python 腳本（scripts/rtfs_i18n.py）用同一套規則與檔案。
// 新增語言：scripts/i18n-update <語言> 產生／更新對照表，再填譯文。
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // 實際採用的語言（例如 "en"）；用原文時是 sourceLanguage。日期格式也照這個語言。
    readonly property string language: loaded.language
    readonly property var locale: Qt.locale(language)
    readonly property string sourceLanguage: "zh_TW"

    // 原文 → 譯文。%1、%2… 依序換成後面的參數（跟 qsTr().arg() 一樣）。
    function tr(text: string, ...args): string {
        let out = loaded.catalog[text] || text;
        for (let i = args.length; i >= 1; i--)
            out = out.split("%" + i).join(String(args[i - 1]));
        return out;
    }

    // 要試的語言，依優先順序；遇到原文語言就停。
    function candidates(): var {
        const out = [];
        const add = l => {
            if (l && !out.includes(l))
                out.push(l);
        };
        const names = Quickshell.env("LANGUAGE")?.split(":") ?? [];
        for (const v of ["LC_ALL", "LC_MESSAGES", "LANG"]) {
            const value = Quickshell.env(v);
            if (value) {
                names.push(value);
                break; // 跟 setlocale 一樣，第一個有設的就是答案
            }
        }
        for (const name of names) {
            const l = (name ?? "").replace(/[.@].*$/, "");
            if (!l || l === "C" || l === "POSIX")
                continue;
            add(l);
            add(l.split("_")[0]);
        }
        return out;
    }

    readonly property var loaded: {
        for (const l of candidates()) {
            if (l === sourceLanguage || l === sourceLanguage.split("_")[0])
                break;
            file.path = Quickshell.shellDir + "/i18n/" + l + ".json";
            const text = file.text();
            if (!text)
                continue;
            try {
                return { language: l, catalog: JSON.parse(text) };
            } catch (e) {
                console.warn("I18n: " + file.path + ": " + e);
            }
        }
        return { language: sourceLanguage, catalog: {} };
    }

    FileView {
        id: file
        blockAllReads: true
        printErrors: false
    }
}
