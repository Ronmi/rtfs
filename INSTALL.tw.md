# 安裝 rtfs

[English](INSTALL.en.md) · [README](README.tw.md)

rtfs 是原樣公開的個人專案（見 [README.tw.md](README.tw.md) 的聲明）。下面是我確定在自己機器上可行的步驟；
你的發行版可能要用不同的套件名稱或多做幾步。

需要先準備好：

- **niri**，而且已經能正常登入使用。螢幕鍵盤需要包含 [PR #4548](https://github.com/niri-wm/niri/pull/4548)
  的 niri（v26.04 之後的版本）。
- **QuickShell 0.3.2**。rtfs 用的是 0.3.2 的 API，更新的版本可能會壞，更舊的一定會壞。
  Debian 13 的 backports 只有 0.3.0，所以在 Debian 上大概要自己編譯（見 [quickshell.org](https://quickshell.org/)）。
  其他發行版可能有現成的套件。
- **大約 30 分鐘**，以及動手改 niri 設定的意願。

下面的指令裡，`$RTFS` 代表 rtfs clone 下來的位置（例如 `~/src/rtfs`）。

## 方法一：交給 AI agent

如果你有用 AI coding agent（Claude Code、Codex、Gemini CLI……），把 repo clone 下來、在裡面開啟 agent，
然後給它類似這樣的指示：

> 在這台電腦上安裝 rtfs。先讀 README.md、AGENTS.md 的「For forks」段落和 INSTALL.tw.md。
> 接著檢查我的發行版、niri 版本，以及有沒有 QuickShell 0.3.2 可以用，在改任何東西之前先給我看計畫。
> 用 sudo、改 niri 設定、gpg-agent 設定或 udev 規則，或是停掉我現在的狀態列、通知程式、polkit agent 之前，
> 都要先問我。改到的檔案都要先備份。改完 niri 設定要執行 `niri validate`。rtfs 跑起來之後，
> 檢查 `qs log` 有沒有錯誤，並告訴我跳過了哪些選用步驟。

同意之前請先看過計畫：agent 會動到你的桌面環境。

## 方法二：手動安裝

### 1. 安裝相依套件

以下是 Debian 的套件名稱（其他發行版請找對應的套件）：

- 必要：`qml6-module-qtquick`、`qml6-module-qtquick-controls`、`qml6-module-qtquick-layouts`、
  `python3`、`python3-yaml`、`python3-gi`、`gir1.2-glib-2.0`、`libglib2.0-bin`、
  `fonts-font-awesome`、`fonts-material-design-icons-iconfont`。
- 建議：`xdg-desktop-portal`（檔案選擇）、`qml6-module-qtquick-effects`（鎖定畫面模糊）、
  `swaylock`（備援鎖定程式）、`brightnessctl`（亮度滑桿）、`wl-mirror`（螢幕鏡像）、
  `rfkill`（飛航模式）、`nm-connection-editor` 和 `blueman`（網路、藍牙設定）、
  `iio-sensor-proxy`（自動旋轉）、`pavucontrol`（音效設定）。
- 各色塊讀取資料的服務：NetworkManager、BlueZ、PipeWire、UPower。

### 2. 取得 rtfs

```sh
git clone https://github.com/Ronmi/rtfs.git "$RTFS"
ln -s "$RTFS/shell" ~/.config/quickshell     # rtfs 成為 QuickShell 的預設設定
```

shell 是從 `shell/../scripts` 找輔助程式的，所以這兩個目錄要放在一起。
如果 `~/.config/quickshell` 已經存在，先把它移走。

把命令列工具放進 `PATH`（任何在 `PATH` 裡的目錄都可以）：

```sh
mkdir -p ~/.local/bin
ln -s "$RTFS"/scripts/rtfs-{ui,zenity,pinentry,type} ~/.local/bin/
```

**改用 Debian 套件**（只限 Debian／Ubuntu）：在 `$RTFS` 執行 `dpkg-buildpackage -b -us -uc`（需要 `debhelper`），
會產生 `rtfs_*.deb`。套件會裝到 `/usr/share/rtfs`、讓 rtfs 成為 QuickShell 的系統預設設定、
把工具放進 `/usr/bin`，並把 `rtfs-pinentry` 註冊成預設的 pinentry。它相依名為 `quickshell (>= 0.3.2)` 的套件，
所以你的 QuickShell 也要用這個名稱打包。用套件安裝的話，本文中的 `$RTFS` 都換成 `/usr/share/rtfs`。

### 3. 設定 niri

加到 `~/.config/niri/config.kdl`：

```kdl
spawn-at-startup "qs" "-n"

// rtfs-ui／rtfs-zenity 的對話框一律浮動。
window-rule {
    match app-id=r#"^org\.quickshell$"#
    open-floating true
}

// 桌布也顯示在 overview 的背景。
layer-rule {
    match namespace="^wallpaper$"
    place-within-backdrop true
}

binds {
    Mod+D { spawn "qs" "ipc" "call" "launcher" "toggle"; }
    Mod+N { spawn "qs" "ipc" "call" "notifications" "toggleCenter"; }
    // rtfs 沒在跑時退回 swaylock，確保一定鎖得起來。
    Super+Alt+L { spawn-sh "qs ipc call lock lock || swaylock"; }
}
```

二合一筆電要讓 rtfs 知道平板模式；螢幕鍵盤按鈕和自動旋轉都靠它：

```kdl
switch-events {
    tablet-mode-on { spawn "sh" "-c" "echo 1 > \"$XDG_RUNTIME_DIR/rtfs-tablet-mode\"; qs ipc call shell setTabletMode true"; }
    tablet-mode-off { spawn "sh" "-c" "echo 0 > \"$XDG_RUNTIME_DIR/rtfs-tablet-mode\"; qs ipc call shell setTabletMode false"; }
}
```

選用的快捷鍵：`qs ipc call menu toggle`（系統選單；niri 預設把 `Mod+Escape` 綁在
`toggle-keyboard-shortcuts-inhibit`，想用這個鍵要先把它移走）、`qs ipc call osk toggle`（螢幕鍵盤）。

改完執行 `niri validate`。

### 4. 停掉 rtfs 取代的元件

rtfs 本身就是狀態列、通知程式、桌布、程式啟動器、鎖定畫面和 polkit agent。把原本這些元件的
`spawn-at-startup`（或服務）拿掉，例如 waybar、mako／swaync、swaybg、fuzzel。swaylock 留著當備援。

一個 session 只能有一個 polkit agent。透過 XDG autostart 啟動的 agent 要設定成不在 niri 下啟動。
以 MATE 的 agent 為例：把 `/etc/xdg/autostart/polkit-mate-authentication-agent-1.desktop` 複製到
`~/.config/autostart/`，把 `NotShowIn=GNOME;KDE;` 改成 `NotShowIn=GNOME;KDE;niri;`。

### 5. 啟動

登出再登入 niri，或先執行一次 `qs -n` 試試看。錯誤訊息用 `qs log` 查看。
設定視窗在系統選單裡（狀態列最右邊的色塊）。所有設定項目見 [config.example.yaml](config.example.yaml)，
你的設定存在 `~/.config/rtfs/config.yaml`。常用的有：`bar.output`（狀態列放在哪個螢幕）、
`appearance.wallpaper.dirs`（桌布目錄）、`appearance.fonts`（字型）、`launcher.terminal`（執行終端機程式用的終端機）。

### 6. 選用項目

**gpg pinentry**：`rtfs-pinentry` 讓 gpg 的密碼輸入框由 rtfs 顯示，不在 rtfs 下（GNOME、SSH、tty）時
自動改用原本的 pinentry。Debian 套件會自動設定。從原始碼安裝的話，在 `~/.gnupg/gpg-agent.conf` 加上
`pinentry-program /home/<你的帳號>/.local/bin/rtfs-pinentry`，再執行 `gpgconf --kill gpg-agent`。
退回原本 pinentry 的功能靠 `update-alternatives` 找程式，所以只適用 Debian 系的發行版。
使用前請先看 [README.tw.md](README.tw.md) 聲明裡的安全提醒。

**Framework 的麥克風開關**：Framework 筆電上，狀態列可以顯示硬體麥克風開關的狀態。它要從 EC（`/dev/cros_ec`）讀，
這個裝置預設只有 root 能開。要開放的話，建立 `/etc/udev/rules.d/60-rtfs-cros-ec.rules`，內容是
`KERNEL=="cros_ec", TAG+="uaccess"`（這會讓你的帳號能送任何 EC 指令；yafi 也帶了一樣的規則）。
沒有這條規則時，只要有麥克風就顯示麥克風圖示。

**讓整個桌面用同一套配色**：rtfs 的配色也產生給其他程式用，放在 `$RTFS/theme`：

```sh
# GTK 3／4（libadwaita、adw-gtk3 的具名顏色）；在其他桌面環境下也會生效
ln -s "$RTFS/theme/gtk3.css" ~/.config/gtk-3.0/gtk.css
ln -s "$RTFS/theme/gtk4.css" ~/.config/gtk-4.0/gtk.css
```

- Qt 6（透過 qt6ct）：在 `~/.config/qt6ct/qt6ct.conf` 的 `[Appearance]` 設定
  `color_scheme_path=$RTFS/theme/qt6ct/twice.conf`（寫完整路徑）和 `custom_palette=true`，
  並在 niri 的 `environment` 區塊設定 `QT_QPA_PLATFORMTHEME "qt6ct"`。
- niri 視窗外框用官方漸層：在 `config.kdl` 的 `layout` 區塊之後加上
  `include "$RTFS/theme/niri-colors.kdl"`（寫完整路徑）。

**介面語言**：介面原文是繁體中文。其他語言用 `shell/i18n/<語言>.json` 對照表翻譯，依 `LANGUAGE`／`LC_ALL`／
`LC_MESSAGES`／`LANG` 挑選。目前沒有附任何翻譯；做法見 [shell/i18n/README.md](shell/i18n/README.md)
（可以交給 AI agent，範例 prompt 見 [README.en.md](README.en.md#customizing-with-an-ai-agent)）。

## 硬體支援

只在 **Framework Laptop 12**（Intel）上測試過，但不是非它不可：

| 功能 | 需要 | 沒有的話 |
|---|---|---|
| 硬體麥克風開關圖示 | Framework 筆電的 EC（`/dev/cros_ec`，需要上面的 udev 規則） | 只要有麥克風就顯示麥克風圖示 |
| 風扇轉速、機身溫度 | `cros_ec` hwmon（Framework／Chromebook） | 不顯示 |
| CPU 溫度 | `coretemp`（Intel）或 `k10temp`／`zenpower`（AMD） | 不顯示 |
| 平板模式、螢幕鍵盤按鈕、自動旋轉 | 會送出平板模式 switch 事件的二合一筆電，以及透過 iio-sensor-proxy 讀取的加速度計 | 不顯示 |
| 電池、亮度 | UPower 電池、`/sys/class/backlight` | 不顯示（桌機也能用） |

## 還原

從 niri 設定拿掉 `spawn-at-startup "qs" "-n"` 和 rtfs 的快捷鍵，把第 4 步停掉的元件恢復，
再刪掉 `~/.config/quickshell` 這個 symlink（或移除套件）。
