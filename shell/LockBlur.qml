// 鎖定畫面的模糊背景，另外放一個檔案由 Loader 載入：QtQuick.Effects 來自 qml6-module-qtquick-effects，
// 沒裝時只有這個檔案載入失敗，LockContent 改用只變暗的背景；寫在 LockContent 裡的話整個鎖定畫面都會壞掉，螢幕就解不開了。
import QtQuick
import QtQuick.Effects

MultiEffect {
    blurEnabled: true
    blur: 1.0
    blurMax: 64
    // 不往外擴，邊緣才不會透出底色。
    autoPaddingEnabled: false
}
