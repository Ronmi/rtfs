// 設定的 schema：有哪些設定、型別、預設值、設定視窗的標籤與說明。Config.qml 與 SettingsWindow.qml 都看這裡，
// 專案根目錄的 config.example.yaml 也由這裡產生（scripts/gen-config-example），改了之後記得重新產生。
// 「= 」後面必須是嚴格的 JSON（雙引號、沒有結尾逗號、沒有註解），產生腳本直接當 JSON 讀。
//
// 節點：有 items 的是分組（label、desc、items）；其他是設定項：
//   type     bool | int | number | string | enum（choices: [{value, label}]）| list（字串清單）| output（螢幕名稱）
//   default  預設值      label  設定視窗的標籤      desc  說明（可省略）
//   min／max  數字範圍    digits  number 的小數位數（設定視窗用）
.pragma library

var schema = 
{
  "appearance": {
    "label": "外觀",
    "items": {
      "wallpaper": {
        "label": "桌布",
        "items": {
          "dirs": {
            "type": "list",
            "default": [],
            "label": "圖片目錄",
            "desc": "只看第一層；jpg、jpeg、png、webp。設定視窗裡一行一個。沒有設定時用官方漸層色當背景。"
          },
          "rotate": {
            "type": "bool",
            "default": true,
            "label": "自動輪換",
            "desc": "關掉時啟動時挑一次，之後只有 wp next 會換。"
          },
          "interval": {
            "type": "int",
            "default": 900,
            "min": 10,
            "max": 86400,
            "label": "輪換間隔（秒）"
          },
          "order": {
            "type": "enum",
            "default": "shuffle",
            "label": "順序",
            "choices": [
              { "value": "shuffle", "label": "隨機（全部輪過一次才重新打亂）" },
              { "value": "sequential", "label": "照檔名順序" }
            ]
          },
          "perOutput": {
            "type": "enum",
            "default": "different",
            "label": "多個螢幕",
            "choices": [
              { "value": "different", "label": "每個螢幕各一張" },
              { "value": "same", "label": "所有螢幕同一張" }
            ]
          },
          "fill": {
            "type": "enum",
            "default": "crop",
            "label": "縮放方式",
            "choices": [
              { "value": "crop", "label": "填滿螢幕，多的裁掉" },
              { "value": "fit", "label": "完整顯示，留邊" },
              { "value": "stretch", "label": "拉伸" }
            ]
          },
          "transition": {
            "label": "過場",
            "items": {
              "type": {
                "type": "enum",
                "default": "fade",
                "label": "過場效果",
                "choices": [
                  { "value": "fade", "label": "淡入淡出" },
                  { "value": "slide", "label": "推入" },
                  { "value": "wipe", "label": "擦除" },
                  { "value": "random", "label": "每次隨機挑一種" },
                  { "value": "none", "label": "直接換" }
                ]
              },
              "duration": {
                "type": "int",
                "default": 800,
                "min": 0,
                "max": 10000,
                "label": "過場長度（毫秒）"
              }
            }
          }
        }
      },
      "fonts": {
        "label": "字型",
        "items": {
          "barFamily": {
            "type": "string",
            "default": "sans-serif",
            "label": "狀態列字型",
            "desc": "狀態列色塊的文字，也用在鎖定畫面的時鐘。可以用 sans-serif、serif 這類通用名稱，由 fontconfig 挑實際的字型。"
          },
          "barSize": {
            "type": "int",
            "default": 16,
            "min": 8,
            "max": 32,
            "label": "狀態列字級（px）",
            "desc": "色塊高度不會跟著變，太大會被切掉。"
          },
          "uiFamily": {
            "type": "string",
            "default": "sans-serif",
            "label": "介面字型",
            "desc": "面板、選單、對話框、提示框的文字。可以用 sans-serif、serif 這類通用名稱，由 fontconfig 挑實際的字型。"
          },
          "uiSize": {
            "type": "int",
            "default": 14,
            "min": 8,
            "max": 32,
            "label": "介面字級（px）",
            "desc": "面板、對話框裡的文字以 14 為基準等比例縮放（14 就是原本的大小）。面板寬度不會跟著變，太大可能會被切掉。"
          }
        }
      }
    }
  },
  "bar": {
    "label": "狀態列",
    "items": {
      "output": {
        "type": "output",
        "default": "",
        "label": "螢幕",
        "desc": "狀態列、通知、螢幕鍵盤放在這個螢幕；OSD、對話框找不到聚焦的螢幕時也用它。空白或這個螢幕沒接上時用第一個螢幕。"
      },
      "position": {
        "type": "enum",
        "default": "top",
        "label": "位置",
        "choices": [
          { "value": "top", "label": "上緣" },
          { "value": "bottom", "label": "下緣" }
        ]
      },
      "clockFormat": {
        "type": "string",
        "default": "yyyy/MM/dd HH:mm",
        "label": "時鐘格式",
        "desc": "Qt 的日期時間格式（yyyy 年、MM 月、dd 日、ddd 星期、HH 時、mm 分、ss 秒）。"
      },
      "interval": {
        "label": "更新頻率",
        "items": {
          "network": {
            "type": "int",
            "default": 3,
            "min": 1,
            "max": 60,
            "label": "網速（秒）"
          },
          "sensors": {
            "type": "int",
            "default": 3,
            "min": 1,
            "max": 60,
            "label": "溫度、風扇、負載（秒）"
          }
        }
      },
      "battery": {
        "label": "電池",
        "items": {
          "warning": {
            "type": "int",
            "default": 30,
            "min": 1,
            "max": 100,
            "label": "警告門檻（%）",
            "desc": "筆電電量低於等於這個值（且沒在充電）時，狀態列系統選單的電量變成彩瑛紅並換成警示圖示；選單裡的電池列變成志效黃。"
          },
          "critical": {
            "type": "int",
            "default": 15,
            "min": 1,
            "max": 100,
            "label": "危險門檻（%）",
            "desc": "電量低於等於這個值時，選單裡的電池列變成彩瑛紅。"
          }
        },
        "desc": "主選單色塊與選單裡電池列的低電量顯示。"
      }
    }
  },
  "notifications": {
    "label": "通知",
    "items": {
      "timeout": {
        "type": "number",
        "default": 5,
        "min": 1,
        "max": 120,
        "digits": 1,
        "label": "彈出秒數",
        "desc": "程式沒指定時，一般與低緊急程度的通知顯示幾秒；緊急通知一直留著。"
      },
      "osd": {
        "label": "OSD",
        "items": {
          "timeout": {
            "type": "number",
            "default": 1.5,
            "min": 0.5,
            "max": 10,
            "digits": 1,
            "label": "顯示秒數"
          },
          "position": {
            "type": "enum",
            "default": "bottom",
            "label": "位置",
            "choices": [
              { "value": "top-left", "label": "左上" },
              { "value": "top", "label": "上方" },
              { "value": "top-right", "label": "右上" },
              { "value": "left", "label": "左側" },
              { "value": "center", "label": "正中央" },
              { "value": "right", "label": "右側" },
              { "value": "bottom-left", "label": "左下" },
              { "value": "bottom", "label": "下方" },
              { "value": "bottom-right", "label": "右下" }
            ]
          },
          "volume": { "type": "bool", "default": true, "label": "音量、靜音改變時顯示" },
          "microphone": { "type": "bool", "default": true, "label": "麥克風靜音改變時顯示" },
          "brightness": { "type": "bool", "default": true, "label": "亮度改變時顯示" }
        }
      }
    }
  },
  "lock": {
    "label": "螢幕鎖定",
    "items": {
      "background": {
        "type": "enum",
        "default": "dim",
        "label": "背景",
        "desc": "用該螢幕目前的桌布。模糊需要 qml6-module-qtquick-effects 套件；沒裝時自動改用變暗。",
        "choices": [
          { "value": "dim", "label": "變暗" },
          { "value": "blur", "label": "模糊再變暗" }
        ]
      },
      "idleLock": {
        "type": "int",
        "default": 300,
        "min": 0,
        "max": 7200,
        "label": "閒置多久後鎖定（秒）",
        "desc": "0 表示不自動鎖定。播放影片等程式要求保持喚醒時不算閒置。"
      },
      "screenOff": {
        "type": "int",
        "default": 30,
        "min": 0,
        "max": 3600,
        "label": "鎖定後閒置多久關掉螢幕（秒）",
        "desc": "手動鎖定也算；動一下滑鼠或鍵盤就會亮。0 表示不關。"
      },
      "beforeSleep": {
        "type": "bool",
        "default": true,
        "label": "睡眠、休眠前先鎖定"
      },
      "clockFormat": {
        "type": "string",
        "default": "HH:mm",
        "label": "時鐘格式",
        "desc": "Qt 的日期時間格式（yyyy 年、MM 月、dd 日、ddd 星期、HH 時、mm 分、ss 秒）。"
      }
    }
  },
  "launcher": {
    "label": "啟動器",
    "items": {
      "terminal": {
        "type": "string",
        "default": "x-terminal-emulator -e",
        "label": "終端機指令",
        "desc": "執行需要終端機的程式（Terminal=true）時用；程式的指令接在後面，用空白分隔。預設是 Debian 的 x-terminal-emulator（update-alternatives 選的終端機）；例如 kitty --、foot、alacritty -e。"
      },
      "overviewButton": {
        "type": "enum",
        "default": "tablet",
        "label": "overview 的「所有程式」按鈕",
        "desc": "niri overview 開著時，每個螢幕上方中央顯示一個開啟啟動器的按鈕。",
        "choices": [
          { "value": "never", "label": "不顯示" },
          { "value": "tablet", "label": "只在平板模式顯示" },
          { "value": "always", "label": "一律顯示" }
        ]
      },
      "excludeOutputs": {
        "type": "list",
        "default": [],
        "label": "不顯示啟動器的螢幕",
        "desc": "啟動器會在每個螢幕顯示，每頁格子數由狀態列所在的螢幕決定；其他螢幕得把格子縮太小才放得下時（例如長條螢幕）自動改顯示遮罩。這裡列出的螢幕也一律顯示遮罩。設定視窗裡一行一個螢幕名稱（例如 DP-3）；狀態列所在的螢幕一律顯示，沒接上的螢幕忽略。"
      }
    }
  },
  "osk": {
    "label": "螢幕鍵盤",
    "items": {
      "opacity": {
        "type": "int",
        "default": 80,
        "min": 10,
        "max": 100,
        "label": "半透明時的不透明度（%）",
        "desc": "按鍵盤上的 ◐ 切換半透明；數字越小越透明。"
      },
      "topReserve": {
        "type": "bool",
        "default": false,
        "label": "在頂部時也讓視窗縮開",
        "desc": "關閉時鍵盤浮在視窗上面、不推動任何東西：固定高度的面板（例如 kitty quick-access-terminal）被推動只會跑出螢幕，不如露出它下方的內容。"
      },
      "topTranslucent": {
        "type": "bool",
        "default": true,
        "label": "切到頂部時自動打開半透明",
        "desc": "只在頂部不讓視窗縮開時有效；之後仍可按 ◐ 關掉。"
      },
      "modalButton": {
        "type": "enum",
        "default": "tablet",
        "label": "對話框、鎖定畫面上的螢幕鍵盤按鈕",
        "desc": "密碼等對話框和鎖定畫面會蓋住狀態列，所以在畫面右下角另外放一顆開關螢幕鍵盤的按鈕。",
        "choices": [
          { "value": "always", "label": "一律顯示（每個螢幕）" },
          { "value": "tablet", "label": "只在平板模式（每個螢幕）" },
          { "value": "never", "label": "不顯示" }
        ]
      }
    }
  },
  "user": {
    "label": "使用者",
    "items": {
      "name": {
        "type": "string",
        "default": "",
        "label": "顯示名稱",
        "desc": "系統選單上顯示的名稱。空白時用帳號資料裡的全名，沒有全名就用帳號。"
      },
      "avatar": {
        "type": "string",
        "default": "",
        "label": "頭像",
        "desc": "圖片檔的路徑（可以用 ~/ 開頭）。空白或讀不到時，依序找 /var/lib/AccountsService/icons/帳號、~/.face。"
      }
    }
  }
};
