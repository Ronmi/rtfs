// 檔案選擇容器（spec.container "file"）：目前交給 xdg-desktop-portal（scripts/rtfs-portal），畫面由 portal 後端畫。
// 以後要換成自己畫的檔案選擇器時只改這裡，spec 與結果格式不變，前端（rtfs-ui、rtfs-zenity）不用動。
// spec：title、save（存檔）、directory（選目錄）、multiple、
//   filename（一開始選取的檔案或目錄；結尾 "/" 的絕對路徑代表從這個目錄開始；存檔時不存在的檔案當成建議檔名）、
//   filters（[{name, patterns: ["*.png", ...]}]）、timeout（秒）。
// 結果同其他容器：button "ok"（選好）或 null，reason button | dismiss | timeout，values { paths: [...] }。
// 銷毀時 Process 被 SIGKILL；portal 發現呼叫端斷線會自己關掉對話框（2026-11-07 實測）。
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    required property var spec
    property bool done: false
    property string output: ""

    signal finished(var payload)
    signal event(var payload) // 沒有中途事件；Dialogs 對每個容器都會接這個 signal

    function show() {
        const s = spec;
        const cmd = [Quickshell.shellDir + "/../scripts/rtfs-portal", "file", "--title", s.title ?? ""];
        for (const flag of ["save", "directory", "multiple"])
            if (s[flag])
                cmd.push("--" + flag);
        if (s.filename)
            cmd.push("--filename", String(s.filename));
        for (const f of s.filters ?? [])
            cmd.push("--filter", (f.name ?? "") + " | " + (f.patterns ?? []).join(" "));
        if (s.timeout > 0)
            cmd.push("--timeout", String(Math.round(s.timeout)));
        proc.command = cmd;
        proc.running = true;
    }

    function finish(payload) {
        if (done)
            return;
        done = true;
        finished(payload);
    }

    function report() {
        let out;
        try {
            out = JSON.parse(root.output);
        } catch (e) {
            root.finish({ error: "rtfs-portal gave no result" });
            return;
        }
        const ok = out.status === "ok";
        root.finish({
            button: ok ? "ok" : null,
            reason: ok ? "button" : out.status === "timeout" ? "timeout" : "dismiss",
            values: { paths: ok ? out.paths : [] }
        });
    }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: line => root.output += line
        }
        // stdout 的最後一行可能比 exited 晚到，晚一拍再解析。
        onExited: (code, status) => {
            if (code !== 0)
                root.finish({ error: "rtfs-portal failed (exit " + code + ")" });
            else
                Qt.callLater(root.report);
        }
    }
}
