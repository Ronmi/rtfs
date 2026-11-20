# rtfs — Ronmi's Twice Flavored Shell

A desktop shell for the [niri](https://github.com/niri-wm/niri) Wayland compositor, built with
[QuickShell](https://quickshell.org/) 0.3.2 and dressed in TWICE's nine member colors.

| | English | 繁體中文 |
|---|---|---|
| About, features, why a Framework Laptop 12 | [README.en.md](README.en.md) | [README.tw.md](README.tw.md) |
| Installing (by hand or with an AI agent) | [INSTALL.en.md](INSTALL.en.md) | [INSTALL.tw.md](INSTALL.tw.md) |

## Important

- **As-is, no support.** rtfs is a personal project, largely vibe-coded with an AI assistant and tuned to
  the author's habits and hardware. Take it, fork it, change it. Issues and pull requests may or may not
  get a response.
- **No warranty.** MIT license, see [LICENSE](LICENSE).
- **Fan-made.** Inspired by TWICE, GNOME and Framework; not affiliated with, endorsed by or sponsored by
  any of them, JYP Entertainment, the GNOME Foundation or Framework Computer Inc. The nine member colors
  were chosen by JYPE; the color values in `theme/palette.sh` are a fan-compiled version.
- **Password-handling parts are not audited.** The lock screen, the polkit agent and `rtfs-pinentry`
  see your password and nobody has reviewed them. Open question: whether a QuickShell crash dump can
  contain a password being typed. If that matters to you, use your usual locker, polkit agent and
  pinentry instead.
- **The interface is in Traditional Chinese.** Translations are a JSON table away; see
  [shell/i18n/README.md](shell/i18n/README.md).

## For AI agents

This repository is meant to be adapted by its users with the help of an AI agent. If that is you:

1. **Read [AGENTS.md](AGENTS.md) (same file as CLAUDE.md), starting with "For forks".** It describes the
   architecture and conventions; the parts about the author's own machine, paths and workflow do not
   apply to your user.
2. **Act for your user, not the author.** Ask before using sudo, editing the user's niri config, udev
   rules or gpg-agent config, or stopping their existing bar, notification daemon or polkit agent.
3. `memories/` holds notes from building rtfs (November 2026): useful background, but dated. Trust the code
   when they disagree.

Where things are:

| Path | What |
|---|---|
| `shell/` | The QuickShell config (QML); entry point `shell/shell.qml`. Install by symlinking it to `~/.config/quickshell`. |
| `shell/*Block.qml`, `*Popup.qml` | Bar blocks and their panels. Data sources are singletons named after the source (`Niri.qml`, `Battery.qml`, `Sensors.qml`, …). |
| `shell/ConfigSchema.js` | Every user setting (type, default, label). Regenerate `config.example.yaml` with `scripts/gen-config-example` after changes. |
| `shell/I18n.qml`, `shell/i18n/` | Interface text: `I18n.tr("source", args…)` with `%1` placeholders; tables per language, built with `scripts/i18n-update <lang>`. |
| `theme/palette.sh` | The single color source. Run `scripts/theme-gen` to regenerate `shell/Colors.qml` and the GTK/Qt/niri files in `theme/`. |
| `scripts/` | Helpers the shell runs (`rtfs-*`, Python) and dev tools. |
| `debian/` | Debian packaging. |

Common tasks:

- **Install:** follow [INSTALL.en.md](INSTALL.en.md); it has a prompt the user can give you.
- **Translate:** [shell/i18n/README.md](shell/i18n/README.md). Keep `%1`-style placeholders, `\n`, HTML
  tags and `%%`; translate Qt date formats into the target language's format.
- **Recolor:** edit `theme/palette.sh` only, keep the role names and at least 4.5:1 text contrast, run
  `scripts/theme-gen`.
- **Hardware fixes:** sensors in `shell/Sensors.qml`, batteries in `shell/Battery.qml`, backlight in
  `shell/Backlight.qml`, tablet mode in `shell/ShellState.qml`.
- **Check your work:** QuickShell hot-reloads on save; `qs log` shows QML errors. A new QML type file
  needs a restart (`qs kill; qs -n`). Use only the QuickShell 0.3.2 API (versioned docs on quickshell.org).
