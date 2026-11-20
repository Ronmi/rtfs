# rtfs — Ronmi's Twice Flavored Shell

[繁體中文](README.md)

A desktop shell for the [niri](https://github.com/niri-wm/niri) Wayland compositor, built with
[QuickShell](https://quickshell.org/) and dressed in TWICE's nine member colors.
It is the shell I use every day on a Framework Laptop 12.

> **Read this first.** rtfs is a personal project that I am sharing as-is.
> It was largely vibe-coded together with an AI assistant, it fits my habits and my hardware,
> and I change it whenever I feel like it. Take it, fork it, rip parts out of it.
> I may or may not look at issues and pull requests; please don't expect support.

## A Framework Laptop 12 for ONCEs

I think a Framework Laptop 12 running rtfs makes a great laptop for a ONCE. Here is why:

- **It looks the part.** Pick the Bubblegum chassis with the Lavender keyboard and you have a 2-in-1
  in MiSaMo-ish colors (mint, lavender, peach). Framework laptops are made to be customized, so you can
  go further: replace the Framework gear in the middle of the lid with a CandyBong and it becomes
  unmistakably a TWICE laptop.
- **TWICE is on screen all the time.** By default rtfs keeps all nine member colors and the official
  gradient visible: the bar blocks, window borders, menus and OSD. Thanks to JYPE for the care that went
  into choosing the nine colors: each one fits its member, and all nine sit well side by side, so a
  screen full of them still looks calm rather than noisy.
- **A 2-in-1 is useful for fandom.** Fold it into a tablet and use it as a digital whiteboard or sketchbook
  (with an app such as Rnote or Xournal++). It is also plenty for everyday office work and for software
  development.
- **It is affordable.** I found very few cheaper laptops with comparable hardware, and none of them were
  2-in-1s; most did not even have a touchscreen.
- **The defaults are ready for it.** rtfs already has sensible defaults for tablet use: on-screen keyboard,
  auto-rotation, a touch-friendly launcher, and a bar that adapts to portrait. Touchscreen gestures are the
  main thing it does not handle.

rtfs runs on other hardware too; see [Hardware](#hardware). I bought my Framework myself, and nobody
pays me for saying this.

## What's in it

- **Bar** with eight blocks in member colors (in TWICE's age order from the right):
  system menu, wireless, on-screen keyboard, tray, clock, network, temperature, workspaces.
  A compact layout kicks in when the screen is rotated to portrait.
- **System menu** in the style of GNOME quick settings: volume and audio devices, brightness,
  media controls (MPRIS), keep-awake, screen mirroring, wallpaper rotation, auto-rotate,
  batteries, screenshots, power actions. Microphone/camera privacy indicators on the bar.
- **Notifications**: banners and a notification center (grouping, do-not-disturb, actions, inline reply).
- **Launcher**: full-screen, paged app grid, also usable by touch in tablet mode.
- **Lock screen** with PAM, idle lock, screen off, lock before suspend, relock after a crash.
- **OSD** for volume, mute, microphone and brightness.
- **Wallpaper** rotation with transitions.
- **On-screen keyboard** (full laptop layout) for tablet mode, plus **auto-rotation** of the built-in panel.
- **polkit agent** and a **pinentry** for gpg.
- **Dialog toolkit** `rtfs-ui`, with a zenity-compatible adapter (`rtfs-zenity`) and `rtfs-pinentry`.
- **Settings window** for `~/.config/rtfs/config.yaml` (all options: [config.example.yaml](config.example.yaml)).
- **One palette for the whole desktop**: `theme/palette.sh` also generates GTK 3/4 CSS,
  a qt6ct color scheme and niri window borders.

There are no screenshots yet.

## Disclaimers

- **Fan-made.** rtfs is inspired by TWICE, GNOME and Framework, and is not affiliated with,
  endorsed by or sponsored by any of them. TWICE is associated with JYP Entertainment;
  GNOME is a trademark of the GNOME Foundation; Framework is a trademark of Framework Computer Inc.
  The nine member colors were chosen by JYPE; the exact color values in `theme/palette.sh` are a
  fan-compiled version, not official ones. Nobody sponsors this project, Framework included.
- **No warranty.** rtfs is provided "as is" under the MIT license (see [LICENSE](LICENSE)).
- **Security-sensitive parts are not audited.** The lock screen, the polkit agent and `rtfs-pinentry`
  handle your password. They were written the same vibe-coded way as everything else and nobody has
  reviewed them. One known open question: whether a QuickShell crash dump can contain a password
  being typed. If that matters to you, keep using swaylock (or another locker), your desktop's
  polkit agent and a regular pinentry instead. Disabling these parts is a small edit; see
  [Customizing](#customizing-with-an-ai-agent).

## Requirements

- **niri** — developed against niri 26.04 + later main. The on-screen keyboard needs niri with
  [PR #4548](https://github.com/niri-wm/niri/pull/4548) (after 26.04) to trigger niri shortcuts
  and input-method switching.
- **QuickShell 0.3.2** exactly-ish: rtfs uses the 0.3.2 API. Newer versions may break things; older ones will.
- Debian 13 (trixie) is what I run. Other distributions should work if you get the dependencies
  below; package names differ.
- Runtime (Debian names): `qml6-module-qtquick`, `qml6-module-qtquick-controls`,
  `qml6-module-qtquick-layouts`, `python3`, `python3-yaml`, `python3-gi`, `gir1.2-glib-2.0`,
  `libglib2.0-bin`, `fonts-font-awesome`, `fonts-material-design-icons-iconfont`.
  Optional: `qml6-module-qtquick-effects` (lock screen blur), `brightnessctl`, `wl-mirror`, `rfkill`,
  `iio-sensor-proxy` (auto-rotate), `nm-connection-editor`, `blueman`, `xdg-desktop-portal`, `swaylock` (fallback).
- NetworkManager, BlueZ, PipeWire and UPower for the corresponding blocks.

## Installing

My Debian package registry is private, so install from source:

```sh
git clone <this repository> ~/src/rtfs
ln -s ~/src/rtfs/shell ~/.config/quickshell   # rtfs becomes your default QuickShell config
qs -n                                          # try it
```

The scripts in `scripts/` are found relative to `shell/`, so keep the two directories together.
To build a Debian package instead: `dpkg-buildpackage -b -us -uc` (needs `debhelper`).

Then add to your niri `config.kdl`:

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
    Super+Alt+L { spawn-sh "qs ipc call lock lock || swaylock"; }
}
```

Stop whatever bar, notification daemon, wallpaper tool and polkit agent you used before.
[debian/README.Debian](debian/README.Debian) (Chinese) has the rest: tablet-mode switch events,
the gpg pinentry, the Framework microphone switch, and wiring GTK/Qt/niri to the palette.
Ask your AI agent to translate it if you need to.

## Hardware

Tested only on a **Framework Laptop 12** (Intel). Nothing requires it:

| Feature | Needs | Without it |
|---|---|---|
| Hardware microphone switch indicator | A Framework laptop's EC (`/dev/cros_ec`, needs a udev `uaccess` rule) | The mic icon shows whenever a microphone exists |
| Fan speed and chassis temperatures | `cros_ec` hwmon (Framework / Chromebook) | Not shown |
| CPU temperature | `coretemp` (Intel) or `k10temp` / `zenpower` (AMD) | Not shown |
| Tablet mode, OSK button, auto-rotate | A convertible reporting tablet-mode switch events, an accelerometer via iio-sensor-proxy | Hidden |
| Battery, brightness | UPower battery, `/sys/class/backlight` | Hidden (works on desktops) |

## Customizing with an AI agent

rtfs is meant to be adapted, and the repository is set up so that an AI coding agent can do it:
[CLAUDE.md](CLAUDE.md) (also linked as `AGENTS.md`) describes the architecture and conventions,
and `memories/` holds the notes from building it. Most changes below are small enough for the free
tier of a mainstream agent. Some prompts to start from:

**Translate the interface** (the source language is Traditional Chinese):

> Read CLAUDE.md and shell/i18n/README.md. Run `scripts/i18n-update en` and fill in every empty value
> of shell/i18n/en.json with a natural English translation suitable for a desktop shell UI. Keep
> placeholders like %1, `\n` and HTML tags, and translate Qt date formats into English formats.
> Then run `scripts/i18n-update en --check`.

**Change the colors:**

> Read CLAUDE.md. I want <describe your palette, e.g. "a Catppuccin Mocha look" or "my favorite group's
> member colors: ...">. Edit theme/palette.sh only, keep every role name, keep text contrast at least
> 4.5:1 on its background, and run `scripts/theme-gen`.

**Fix something for your hardware:**

> Read CLAUDE.md. On my machine <the temperature block shows nothing / the battery is missing / ...>.
> Here is the output of `ls /sys/class/hwmon/*/name` and `cat /sys/class/hwmon/*/name`: ... Fix
> shell/Sensors.qml (or the relevant file) so it works here without breaking other machines.

**Drop a component you don't want:**

> Read CLAUDE.md. Remove the lock screen from rtfs (I use swaylock): stop it from starting, remove its
> IPC target and the idle/sleep lock, and update the menu and docs accordingly.

**Rearrange the bar:**

> Read CLAUDE.md. Give the bar blocks these colors from left to right: ... and swap the clock and
> network blocks.

(Bar position, fonts, timeouts and the like are plain settings: open the settings window from the system menu.)

Before an agent changes anything, have it read the "For forks" section at the top of CLAUDE.md:
some rules there only apply to my machine.

## License

MIT — see [LICENSE](LICENSE).
