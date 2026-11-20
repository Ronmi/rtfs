// 一般視窗容器（zenity 等工具的預設）：由 niri 管理，不搶整個桌面，可以同時開好幾個。
// 裡面放 DialogBody；用視窗的關閉鈕或 niri 的關閉視窗動作關掉，等同按 Esc。由 Dialogs 動態建立。
import QtQuick
import Quickshell

FloatingWindow {
    id: root

    property var spec: ({})
    readonly property alias body: body

    signal finished(var payload)
    signal event(var payload)

    function show() {
        visible = true;
        if (spec.maximized)
            maximized = true;
        if (spec.fullscreen)
            fullscreen = true;
        body.focusFirst();
    }

    visible: false
    // 標題也給 niri 的 window rule 比對用。
    title: spec.title || "rtfs-ui"
    implicitWidth: spec.width ?? Math.max(440, Math.min(body.implicitWidth + 48, spec.wrap === false ? 1600 : 640))
    implicitHeight: spec.height ?? body.implicitHeight + 48
    minimumSize: Qt.size(240, 120)
    // 一般視窗跟其他程式一樣用淺色（TWICE 配色原則：程式淺色、shell 深色）。
    color: Theme.dialogLight.bg

    onClosed: body.finish(null, "dismiss")

    DialogBody {
        id: body
        anchors.fill: parent
        anchors.margins: 24
        theme: Theme.dialogLight
        spec: root.spec
        fieldSpecs: root.spec.fields ?? []
        onFinished: payload => root.finished(payload)
        onEvent: payload => root.event(payload)
    }
}
