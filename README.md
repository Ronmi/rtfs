# rtfs — Ronmi's Twice Flavored Shell

[English](README.en.md)

用 [QuickShell](https://quickshell.org/) 自己打造的 niri 桌面 shell，配色是 TWICE 九人九色，每天在 Framework Laptop 12 上使用。

> **先說清楚**：這是我個人使用的專案，原樣公開出來給大家參考。大部分是跟 AI 一起 vibe coding 寫的，
> 只照我的習慣和硬體調整，想改就改。喜歡就拿去用、fork、拆零件都可以；不喜歡的地方請自己改
> （專案裡的 CLAUDE.md 和 memories/ 就是給 AI 看的，交給你的 AI 處理通常就夠了）。
> issue 和 PR 看心情處理，請不要期待支援。

## 推坑：給 ONCE 的 Framework Laptop 12

我覺得 Framework Laptop 12 裝上 rtfs，非常適合 ONCE 使用：

- **外觀就很 TWICE**：Bubblegum 機身配 Lavender 鍵盤，就是一台 MiSaMo 風格（淺藍綠、紫、桃色）的二合一筆電。Framework 本來就鼓勵客製化，還可以把上蓋中間的 Framework 齒輪換成 CandyBong，TWICE 感直接大幅提升。
- **畫面上隨時都有九人九色**：rtfs 預設讓九人九色和官方漸層一直出現在畫面上（狀態列色塊、視窗外框、選單、OSD）。感謝 JYPE 當初挑選九人九色的用心：每個顏色都貼近成員給人的感覺，九個顏色並排起來也很協調，所以整個畫面都是這些顏色也不會顯得雜亂。
- **二合一在追星時真的用得到**：反折成平板當電子白板或手繪板（需要裝 Rnote、Xournal++ 這類程式）。平常當文書機或寫程式也夠用。
- **便宜**：我找到的同等級硬體裡，比 FW12 便宜的選擇極少，而且全都不是二合一，大多連觸控螢幕都沒有。
- **預設值已經調好**：平板用得到的螢幕鍵盤、自動旋轉、適合觸控的程式啟動器、直立時自動調整的狀態列都已經有不錯的預設值；主要只差觸控螢幕手勢還沒支援。

rtfs 在其他硬體上也能用，見 [README.en.md](README.en.md) 的 Hardware 一節。FW12 是我自己買的，這段推坑沒有收任何人的錢。

## 緣起

從 GNOME 換到 niri（設定在 `~/raoh/niri`）之後，社群常見的現成元件（waybar、swaync、fuzzel……）雖然能用，但跟 GNOME 比起來缺乏一致性，看不順眼的地方不少。這個專案就是用 QuickShell 把這些元件換成符合自己習慣和風格的版本。

## 設計原則

- **一致性優先**：各元件的外觀、互動方式要像同一套系統，這也是當初離不開 GNOME 的原因。
- **配色單一來源**：TWICE 配色定義在 `theme/palette.sh`（2026-11-20 從 niri 專案搬過來），`scripts/theme-gen` 產生 rtfs、GTK、Qt、niri 外框各自的配色檔，不在 QML 裡寫死色碼。
- **逐步替換**：一次只換一個元件，換好之後才在 niri 專案停用舊的元件。
- **只在 niri 下作用**：GNOME session 仍然保留，本專案不能影響它。
- **畫面文字使用繁體中文**：程式裡的原文是繁體中文，其他語言用 `shell/i18n/` 的對照表翻譯（目前沒有附任何翻譯）。

## 聲明

- **粉絲作品**：受 TWICE、GNOME、Framework 啟發，但跟它們（以及 TWICE 所屬的 JYP Entertainment、GNOME Foundation、Framework Computer Inc.）沒有任何關係，也沒有得到它們的認可或贊助。九人九色是 JYPE 選的，`theme/palette.sh` 裡的色碼則是粉絲整理的版本，不是官方色碼。本專案沒有任何贊助，包括 Framework。
- **沒有任何保證**：以 MIT 授權原樣提供（見 [LICENSE](LICENSE)）。
- **跟密碼有關的元件沒有經過審查**：鎖定畫面、polkit 驗證視窗、`rtfs-pinentry` 都會經手密碼，跟其他部分一樣是 vibe coding 寫的；已知還沒查證的一點是 QuickShell 當掉時留下的 crash dump 會不會含有正在輸入的密碼。介意的話請繼續用 swaylock 等鎖定程式、原本的 polkit agent 和 pinentry。

## 元件進度

| 元件 | 取代對象 | 狀態 |
|---|---|---|
| 狀態列 | waybar（含電源選單） | 已取代（2026-11-06）：工作區、溫度、網路、時鐘、無線（Wi-Fi、藍牙、飛航模式，2026-11-17）、系統匣、螢幕鍵盤、系統選單（含音量、電池；原本獨立的音量、電池色塊已於 2026-11-17 移除；2026-11-18 加上媒體控制、桌布輪換與自動旋轉開關，Super+Esc 開關；2026-11-19 加上麥克風／鏡頭隱私圖示），放在 eDP-1 上緣；螢幕轉直時改用精簡版（系統匣收成下拉清單）；細節持續調整 |
| 通知 | swaync | 已取代（2026-11-06）：彈出卡片、時鐘面板裡的通知中心（分組、勿擾、動作、回覆），Mod+N 開關 |
| 啟動器 | fuzzel（含 `nt` 選單） | 已取代（2026-11-06）：程式啟動是全螢幕分頁格狀 launcher（Mod+D）；`nt` 選單等改用 `rtfs-zenity` 對話框 |
| 對話框工具 | zenity、fuzzel 的 dmenu 用法（`nt` 選單等） | 已完成（2026-11-06）：通用 UI 元件 `rtfs-ui`（一般視窗或 modal；輸入、清單、進度、滑桿、日曆、顏色、字型、表單等元件，涵蓋 zenity／yad／kdialog 的需求）＋相容 zenity 4.1.90 的 `rtfs-zenity`（檔案選擇交給 xdg-desktop-portal）；`nt` 選單等已改用。yad／kdialog 相容層、系統匣圖示尚未做 |
| OSD | 音量／亮度提示（原本沒有） | 已完成（2026-11-07）：音量、靜音、麥克風、亮度變化時顯示；`rtfs-ui` 也能顯示 OSD |
| 桌布 | swaybg＋niri 專案的 `scripts/wallpaper` | 已取代（2026-11-07）：QuickShell 畫桌布並輪換，設定在 `~/.config/rtfs/config.yaml`（範例 `config.example.yaml`），支援淡入淡出、推入、擦除過場 |
| 鎖定畫面 | swaylock | 已取代（2026-11-07）：Super+Alt+L、系統選單「鎖定」；背景是該螢幕目前的桌布（變暗，或設定 `lock.background: blur` 模糊）；qs 在鎖定中當掉重啟後自動重新鎖定。閒置 5 分鐘自動鎖定、鎖定後閒置 30 秒關螢幕、睡眠／休眠前先鎖定（都可在設定裡調整）。swaylock 保留當備援（qs 沒在跑時、或從 TTY 救援） |
| 自動旋轉 | （原本沒有） | 已完成（2026-11-18）：跟 GNOME 一樣，平板模式時內建螢幕跟著方向旋轉，回筆電模式轉回正常；系統選單可手動開關（需要 iio-sensor-proxy） |
| 權限視窗 | pinentry、polkit（pkexec）驗證視窗（polkit 原本由 MATE 的 agent 處理） | polkit 已取代（2026-11-06）：QuickShell 的驗證對話框，niri 下停用 MATE agent；pinentry 已取代（2026-11-07）：`rtfs-pinentry`，GNOME／SSH／tty 下自動改用原本的 pinentry |

## 安裝

QuickShell 和 rtfs 都包成 deb，放在自己的 Forgejo 套件庫（git.ronmi.tw，`trixie/main`；需要登入，不對外開放，其他人請照 [README.en.md](README.en.md) 從原始碼安裝）：

```sh
sudo apt install rtfs   # 會一併裝上 quickshell
```

- `quickshell` 套件由另一個 repo（`~/raoh/my-quickshell`）編譯打包，固定使用最新的 release tag（目前是 v0.3.2）。它相依 backports 的 `libcpptrace1`，新機器要先啟用 trixie-backports。
- rtfs 推送 `v*` tag 時由 Forgejo Actions 自動打包發佈（`.forgejo/workflows/release.yml`），版本號就是 tag。
- 套件以外要自己做的設定（niri 設定、gpg-agent 等）寫在套件附的 `/usr/share/doc/rtfs/README.Debian`。
- 開發中的機器：`~/.config/quickshell` 指向本專案的 `shell/`，會優先於套件裝的版本（`/etc/xdg/quickshell`），改了檔案就直接生效。

## 設定目錄與配色

- `shell/` 是 QuickShell 的設定目錄，`~/.config/quickshell` 是指向它的 symlink。
- 使用者設定在 `~/.config/rtfs/config.yaml`（每台機器各自一份），可以直接編輯，或從系統選單的設定按鈕用視窗修改（視窗存檔只寫跟預設值不同的項目，原本的註解不保留）。所有項目與說明見 `config.example.yaml`；它由 `shell/ConfigSchema.js` 產生（`scripts/gen-config-example`），不要直接修改。配色不在設定檔裡。
- `shell/Colors.qml` 由 `scripts/theme-gen` 從 `theme/palette.sh` 產生，QML 裡用 `Colors.nayeon`、`Colors.shellBg` 這類名稱取色。要改顏色就改 `palette.sh` 再執行 `scripts/theme-gen`，不要直接改產生的檔案。
- 介面文字一律寫成 `I18n.tr("原文")`（Python 腳本是 `tr("原文")`），變數用 `%1`、`%2`；其他語言的對照表在 `shell/i18n/`，用 `scripts/i18n-update <語言>` 產生。
