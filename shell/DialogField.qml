// 對話框 field（Field*.qml）的共用基底：DialogBody 依 spec.fields 逐一建立。
// 每種 field 自己決定外觀，並透過這些屬性跟 DialogBody 溝通：
//   field       這個 field 的 spec（update 時會整個換成合併後的新物件，所以顯示用的屬性直接綁 field.xxx）
//   body        所屬的 DialogBody（送事件、觸發預設按鈕）
//   value       要放進結果的值；hasValue 為 false 的 field（標籤、圖片）不會出現在結果裡
//   expand      版面有多的高度時要不要長高（清單、多行文字）
//   focusTarget 對話框打開時要拿鍵盤焦點的項目
import QtQuick

Item {
    id: root

    property var field: ({})
    property var body: null
    // 配色跟著所屬的 DialogBody（容器決定深淺）。
    readonly property var theme: body ? body.theme : Theme.dialogDark
    property int index: 0

    property var value: null
    property bool hasValue: true
    property bool expand: false
    property Item focusTarget: null
    // field 自己顯示 spec 的 label（核取方塊、按鈕），DialogBody 就不在上方另外顯示。
    property bool ownsLabel: false

    // 送出中途事件（不會結束對話框），例如 scale 拖動中、拖放、表單按鈕。
    function emitEvent(name, data) {
        if (body)
            body.emitEvent(name, index, data);
    }
}
