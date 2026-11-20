// 圖片 field（kdialog --imgbox／--imginputbox、yad --picture、zenity --imagelist 以外的圖片顯示）。
// spec：source（圖檔絕對路徑或 URL）、maxWidth／maxHeight（沒有多餘空間時的最大顯示大小，預設 600×400）。
// 圖片等比縮放塞進可用空間，不放大超過原尺寸。沒有值。
import QtQuick

DialogField {
    id: root

    readonly property string url: {
        const s = field.source ?? "";
        return s.startsWith("/") ? "file://" + s : s;
    }
    readonly property real natW: image.sourceSize.width
    readonly property real natH: image.sourceSize.height
    // 在最大範圍內等比縮小
    readonly property real fitScale: natW > 0 && natH > 0
        ? Math.min(1, (field.maxWidth ?? 600) / natW, (field.maxHeight ?? 400) / natH) : 1

    hasValue: false
    expand: true
    implicitWidth: natW > 0 ? natW * fitScale : 200
    implicitHeight: natH > 0 ? natH * fitScale : 40

    AnimatedImage {
        id: image
        anchors.fill: parent
        source: root.url
        fillMode: Image.PreserveAspectFit
        // 原尺寸比可用空間小時不放大
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        smooth: true
        asynchronous: true
    }

    Text {
        visible: image.status === Image.Error
        anchors.centerIn: parent
        text: I18n.tr("無法載入圖片：%1", root.field.source ?? "")
        color: theme.err
        font.family: Theme.uiFontFamily
        font.pixelSize: Theme.fontPx(14)
    }
}
