# Installing rtfs

[繁體中文](INSTALL.tw.md) · [README](README.en.md)

rtfs is a personal project shared as-is (see [README.md](README.md)). These steps are what I know works
on my machine; your distribution may need different package names or extra steps.

What you need:

- **niri** with the session already working. The on-screen keyboard needs a niri build that includes
  [PR #4548](https://github.com/niri-wm/niri/pull/4548) (after 26.04).
- **QuickShell 0.3.2.** rtfs uses the 0.3.2 API; newer versions may break things, older ones will.
  Debian 13 only has 0.3.0 in backports, so on Debian you will probably build QuickShell yourself
  (see [quickshell.org](https://quickshell.org/)). Other distributions may package it.
- **About 30 minutes**, and willingness to edit your niri config.

In the commands below, `$RTFS` is where you cloned rtfs (for example `~/src/rtfs`).

## Option A: let an AI agent do it

If you use an AI coding agent (Claude Code, Codex, Gemini CLI, …), clone the repository, open the
agent in it, and give it something like:

> Install rtfs on this machine. First read README.md, the "For forks" section of AGENTS.md, and
> INSTALL.en.md. Then check my distribution, my niri version and whether QuickShell 0.3.2 is available,
> and show me a plan before changing anything. Ask me before you use sudo, edit my niri config,
> gpg-agent config or udev rules, or stop my current bar, notification daemon or polkit agent.
> Back up every file you change. Run `niri validate` after editing the niri config. When rtfs is
> running, check `qs log` for errors and tell me which optional steps I skipped.

Read the plan before you approve it: the agent will be editing your desktop session.

## Option B: by hand

### 1. Install the dependencies

Debian package names (find the equivalents on other distributions):

- Required: `qml6-module-qtquick`, `qml6-module-qtquick-controls`, `qml6-module-qtquick-layouts`,
  `python3`, `python3-yaml`, `python3-gi`, `gir1.2-glib-2.0`, `libglib2.0-bin`,
  `fonts-font-awesome`, `fonts-material-design-icons-iconfont`.
- Recommended: `xdg-desktop-portal` (file chooser), `qml6-module-qtquick-effects` (lock screen blur),
  `swaylock` (fallback locker), `brightnessctl` (brightness slider), `wl-mirror` (screen mirroring),
  `rfkill` (airplane mode), `nm-connection-editor` and `blueman` (network and Bluetooth settings),
  `iio-sensor-proxy` (auto-rotation), `pavucontrol` (sound settings).
- Services the blocks read from: NetworkManager, BlueZ, PipeWire, UPower.

### 2. Get rtfs

```sh
git clone https://github.com/Ronmi/rtfs.git "$RTFS"
ln -s "$RTFS/shell" ~/.config/quickshell     # QuickShell's default config is now rtfs
```

The shell finds its helper scripts at `shell/../scripts`, so keep the two directories together.
If `~/.config/quickshell` already exists, move it away first.

Put the command-line tools on your `PATH` (any directory on `PATH` works):

```sh
mkdir -p ~/.local/bin
ln -s "$RTFS"/scripts/rtfs-{ui,zenity,pinentry,type} ~/.local/bin/
```

**Debian package instead** (Debian/Ubuntu only): `dpkg-buildpackage -b -us -uc` in `$RTFS` (needs
`debhelper`) builds `rtfs_*.deb`. It installs to `/usr/share/rtfs`, makes rtfs QuickShell's system-wide
default, puts the tools in `/usr/bin` and registers `rtfs-pinentry` as the default pinentry. It depends on
a package named `quickshell (>= 0.3.2)`, so you need your QuickShell packaged under that name.
With the package, use `/usr/share/rtfs` wherever this guide says `$RTFS`.

### 3. Configure niri

Add to `~/.config/niri/config.kdl`:

```kdl
spawn-at-startup "qs" "-n"

// rtfs-ui / rtfs-zenity dialogs float.
window-rule {
    match app-id=r#"^org\.quickshell$"#
    open-floating true
}

// Show the wallpaper behind the overview too.
layer-rule {
    match namespace="^wallpaper$"
    place-within-backdrop true
}

binds {
    Mod+D { spawn "qs" "ipc" "call" "launcher" "toggle"; }
    Mod+N { spawn "qs" "ipc" "call" "notifications" "toggleCenter"; }
    // Falls back to swaylock when rtfs is not running, so locking always works.
    Super+Alt+L { spawn-sh "qs ipc call lock lock || swaylock"; }
}
```

On a convertible (2-in-1), let rtfs know about tablet mode; this drives the on-screen keyboard button
and auto-rotation:

```kdl
switch-events {
    tablet-mode-on { spawn "sh" "-c" "echo 1 > \"$XDG_RUNTIME_DIR/rtfs-tablet-mode\"; qs ipc call shell setTabletMode true"; }
    tablet-mode-off { spawn "sh" "-c" "echo 0 > \"$XDG_RUNTIME_DIR/rtfs-tablet-mode\"; qs ipc call shell setTabletMode false"; }
}
```

Optional hotkeys: `qs ipc call menu toggle` (system menu; niri binds `Mod+Escape` to
`toggle-keyboard-shortcuts-inhibit` by default, move that one first if you want this key) and
`qs ipc call osk toggle` (on-screen keyboard).

Then run `niri validate`.

### 4. Stop what rtfs replaces

rtfs is your bar, notification daemon, wallpaper, launcher, lock screen and polkit agent. Remove the
`spawn-at-startup` lines (or services) of what you used before, e.g. waybar, mako/swaync, swaybg,
fuzzel. Keep swaylock installed as the fallback.

Only one polkit agent can run per session. Agents started by XDG autostart need to be told not to start
under niri. For MATE's agent: copy `/etc/xdg/autostart/polkit-mate-authentication-agent-1.desktop` to
`~/.config/autostart/` and change `NotShowIn=GNOME;KDE;` to `NotShowIn=GNOME;KDE;niri;`.

### 5. Start it

Log out and back into niri, or run `qs -n` once to try it. `qs log` shows errors.
The settings window is in the system menu (the right-most bar block). All options are in
[config.example.yaml](config.example.yaml); your settings live in `~/.config/rtfs/config.yaml`.
Common ones: `bar.output` (which screen gets the bar), `appearance.wallpaper.dirs` (wallpaper folders),
`appearance.fonts` (fonts), `launcher.terminal` (terminal for terminal apps).

### 6. Optional extras

**gpg pinentry.** `rtfs-pinentry` shows gpg passphrase prompts in rtfs and falls back to your normal
pinentry outside rtfs (GNOME, SSH, tty). The Debian package sets this up. From a clone, add
`pinentry-program /home/<you>/.local/bin/rtfs-pinentry` to `~/.gnupg/gpg-agent.conf` and run
`gpgconf --kill gpg-agent`. The fallback is found with `update-alternatives`, so it only works on
Debian-based systems. Read the security note in [README.md](README.md) first.

**Framework microphone switch.** On Framework laptops the bar can show the hardware microphone switch.
It is read from the embedded controller (`/dev/cros_ec`), which only root can open by default. To allow
it, create `/etc/udev/rules.d/60-rtfs-cros-ec.rules` with `KERNEL=="cros_ec", TAG+="uaccess"`
(this lets your user send any EC command; yafi ships the same rule). Without it the mic icon simply
shows whenever a microphone exists.

**One palette for the whole desktop.** rtfs's colors are also generated for other programs in
`$RTFS/theme`:

```sh
# GTK 3 / 4 (named colors used by libadwaita and adw-gtk3); also applies under other desktops
ln -s "$RTFS/theme/gtk3.css" ~/.config/gtk-3.0/gtk.css
ln -s "$RTFS/theme/gtk4.css" ~/.config/gtk-4.0/gtk.css
```

- Qt 6 via qt6ct: in `~/.config/qt6ct/qt6ct.conf`, under `[Appearance]`, set
  `color_scheme_path=$RTFS/theme/qt6ct/twice.conf` (written out in full) and `custom_palette=true`,
  and set `QT_QPA_PLATFORMTHEME "qt6ct"` in niri's `environment` block.
- niri window borders in the official gradient: `include "$RTFS/theme/niri-colors.kdl"` (written out in
  full) after the `layout` block of `config.kdl`.

**Interface language.** The interface is written in Traditional Chinese. Translations are tables in
`shell/i18n/<lang>.json`, picked from `LANGUAGE` / `LC_ALL` / `LC_MESSAGES` / `LANG`. None ship yet;
[shell/i18n/README.md](shell/i18n/README.md) explains how to make one (an AI agent can do it, see the
prompts in [README.en.md](README.en.md#customizing-with-an-ai-agent)).

## Hardware support

Tested only on a **Framework Laptop 12** (Intel). Nothing requires it:

| Feature | Needs | Without it |
|---|---|---|
| Hardware microphone switch indicator | A Framework laptop's EC (`/dev/cros_ec`, udev rule above) | The mic icon shows whenever a microphone exists |
| Fan speed and chassis temperatures | `cros_ec` hwmon (Framework / Chromebook) | Not shown |
| CPU temperature | `coretemp` (Intel) or `k10temp` / `zenpower` (AMD) | Not shown |
| Tablet mode, OSK button, auto-rotation | A convertible reporting tablet-mode switch events, an accelerometer via iio-sensor-proxy | Hidden |
| Battery, brightness | UPower battery, `/sys/class/backlight` | Hidden (works on desktops) |

## Going back

Remove `spawn-at-startup "qs" "-n"` and the rtfs binds from your niri config, restore the components you
removed in step 4, and delete the `~/.config/quickshell` symlink (or uninstall the package).
