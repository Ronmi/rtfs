# Twice 桌面配色：應用程式淺色、終端機與外殼元件深色，外殼用九人九色填色。
# 這是唯一的色彩來源；改完執行 `scripts/theme-gen` 重新產生各元件設定。
# 調整時改「角色」，不要在個別元件裡改色碼。

# --- 九人九色（粉絲整理版）與官方漸層 ---
NAYEON=#49C0EC
JEONGYEON=#A3CC54
MOMO=#E67EA3
SANA=#8C79B4
JIHYO=#F9CC85
MINA=#71C7D4
DAHYUN=#FEFEFE
CHAEYOUNG=#E62722
TZUYU=#2253A3
OFFICIAL_FROM=#F9C596  # 官方漸層起點
OFFICIAL_TO=#FC5D9D    # 官方漸層終點

# --- 色塊上的文字：成員色填色時用深灰或淺灰 ---
INK_DARK=#1F2024
INK_LIGHT=#F5F5F7

# --- 淺色應用程式（GTK、Qt） ---
BG=#FAFAFA         # 視窗底
VIEW=#FFFFFF       # 內容區、卡片、輸入框、popover
HEADER=#EBEBEB     # headerbar、Qt 選單列
SIDEBAR=#F0F0F2    # 側欄
BUTTON=#E4E4E8     # 一般按鈕、關閉的開關
LINE=#DCDCE0       # 分隔線
FG=#1F2024         # 主要文字
DIM=#6E7078        # 次要文字
ACCENT=$NAYEON     # 焦點、開關、主要按鈕、選取列（填色）
ACCENT_FG=$INK_DARK
ACCENT_TEXT=#117EA6  # 娜璉色壓暗，淺色底上的連結與強調文字（娜璉原色當文字太淡）
SEL=$NAYEON        # 選取列、反白文字
SEL_FG=$INK_DARK
OK=$JEONGYEON      # 成功（填色）
OK_TEXT=#2E7D32    # 成功文字（淺色底上）
WARN=$JIHYO        # 警告（填色）
WARN_TEXT=#A15C00  # 警告文字（淺色底上）
ERR=$CHAEYOUNG     # 錯誤、危險按鈕（填色，配淺色字）
ERR_TEXT=#C4161C   # 錯誤文字（淺色底上）

# --- 深色外殼（沿用 kitty twice.conf）：waybar tooltip 與選單 ---
SHELL_BG=#1A1512
SHELL_RAISED=#2A231E
SHELL_FG=#EDE6DF
SHELL_DIM=#8A7F75  # 也用於 waybar 未選中的 workspace 數字（刻意低對比）

# --- 通知總覽面板：子瑜色壓暗的深藍，跟 kitty 的暖棕分開 ---
PANEL_BG=#141B2D
PANEL_RAISED=#1E2840  # 面板上的按鈕、關閉的開關

# --- niri 視窗外框 ---
BORDER_INACTIVE=#9E9AA4  # 未聚焦視窗；聚焦視窗用官方漸層
