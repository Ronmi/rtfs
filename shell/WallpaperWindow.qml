// 一個螢幕的桌布：Background layer 上的全螢幕視窗，圖由 Wallpaper.images 決定。
// namespace 跟 swaybg 一樣是 "wallpaper"，niri 的 layer-rule（place-within-backdrop，總覽裡也看得到）不用改。
// 兩層輪流使用：新圖載入完成後疊在舊圖上播過場，播完清掉舊圖釋放記憶體。
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "wallpaper"
    color: "transparent"

    // 螢幕拔掉或轉向時 modelData 會先變成 null 才銷毀視窗，要擋一下。
    readonly property string source: Wallpaper.images[modelData?.name] ?? ""
    onSourceChanged: show(Wallpaper.transition)
    // 熱重載或螢幕剛接上時直接顯示，不播過場。
    Component.onCompleted: show("none")

    property Item front: layerA
    property Item back: layerB
    property string pendingType: ""
    property bool animating: false

    function show(type) {
        if (source === front.source)
            return;
        // 上一個過場還沒播完就直接跳到結尾。
        if (animating) {
            fade.stop();
            slide.stop();
            wipe.stop();
            if (animating)
                finish();
        }
        // 圖片目錄清空了：拿掉圖，露出漸層背景。
        if (source === "") {
            pendingType = "";
            front.source = "";
            back.source = "";
            return;
        }
        if (type === "random")
            type = ["fade", "slide", "wipe"][Math.floor(Math.random() * 3)];
        pendingType = Wallpaper.duration > 0 ? type : "none";
        back.reset();
        back.z = 1;
        front.z = 0;
        back.source = source;
    }

    // back 的圖載入完成（WallpaperLayer 呼叫）。
    function loaded(layer) {
        if (layer !== back || pendingType === "")
            return;
        const type = pendingType;
        pendingType = "";
        animating = true;
        if (type === "fade") {
            back.opacity = 0;
            fade.start();
        } else if (type === "slide") {
            back.x = width;
            slide.start();
        } else if (type === "wipe") {
            back.width = 0;
            wipe.start();
        } else {
            finish();
        }
    }

    function finish() {
        animating = false;
        const old = front;
        front = back;
        back = old;
        front.reset();
        back.source = "";
        back.reset();
    }

    component WallpaperLayer: Item {
        id: layer

        property alias source: img.source

        function reset() {
            x = 0;
            width = win.width;
            opacity = 1;
        }

        height: win.height
        width: win.width
        clip: true

        Image {
            id: img
            // 寬高固定是整個螢幕，外層 Item 縮窄（wipe）時只是被裁掉，圖本身不變形。
            width: win.width
            height: win.height
            fillMode: Wallpaper.fillMode
            // 原圖常是 4K 以上；照螢幕實際像素解碼，省記憶體。
            sourceSize: Qt.size(win.width * (win.modelData?.devicePixelRatio ?? 1),
                win.height * (win.modelData?.devicePixelRatio ?? 1))
            asynchronous: true
            cache: false
            onStatusChanged: {
                if (status === Image.Ready)
                    win.loaded(layer);
                else if (status === Image.Error) {
                    console.warn("Wallpaper: cannot load", source);
                    if (layer === win.back)
                        win.pendingType = "";
                }
            }
        }
    }

    // 沒設定圖片目錄（或第一張圖載入前）露出的背景：官方漸層色。
    Rectangle {
        anchors.fill: parent
        z: -1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Colors.officialFrom }
            GradientStop { position: 1; color: Colors.officialTo }
        }
    }

    WallpaperLayer {
        id: layerA
    }
    WallpaperLayer {
        id: layerB
    }

    NumberAnimation {
        id: fade
        target: win.back
        property: "opacity"
        from: 0
        to: 1
        duration: Wallpaper.duration
        easing.type: Easing.InOutQuad
        onFinished: if (win.animating) win.finish()
    }
    // 新圖從右邊推進來，舊圖同時被推出去。
    ParallelAnimation {
        id: slide
        onFinished: if (win.animating) win.finish()
        NumberAnimation {
            target: win.back
            property: "x"
            from: win.width
            to: 0
            duration: Wallpaper.duration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: win.front
            property: "x"
            from: 0
            to: -win.width
            duration: Wallpaper.duration
            easing.type: Easing.OutCubic
        }
    }
    // 新圖從左到右蓋過舊圖。
    NumberAnimation {
        id: wipe
        target: win.back
        property: "width"
        from: 0
        to: win.width
        duration: Wallpaper.duration
        easing.type: Easing.InOutQuad
        onFinished: if (win.animating) win.finish()
    }
}
