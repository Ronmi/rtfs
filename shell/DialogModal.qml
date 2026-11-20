// modal 容器：整個桌面變暗、獨佔鍵盤（DialogFrame），裡面放 DialogBody。由 Dialogs 動態建立。
import QtQuick

DialogFrame {
    id: root

    property var spec: ({})
    readonly property alias body: body

    signal finished(var payload)
    signal event(var payload)

    function show() {
        open();
        body.focusFirst();
    }

    // 沒指定寬度時依內容決定，但不窄於 440、不寬於 640（不換行的內文可以更寬）。
    cardWidth: spec.width ?? Math.max(440, Math.min(body.implicitWidth + 48, spec.wrap === false ? 1600 : 640))
    cardHeight: spec.height ?? body.implicitHeight + 48
    onDismissed: body.finish(null, "dismiss")

    DialogBody {
        id: body
        width: parent.width
        height: parent.height
        spec: root.spec
        fieldSpecs: root.spec.fields ?? []
        onFinished: payload => root.finished(payload)
        onEvent: payload => root.event(payload)
    }
}
