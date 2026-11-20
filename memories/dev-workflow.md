---
name: dev-workflow
description: How to run, inspect and visually check the QuickShell shell during development (niri spawn, qs log, niri screenshot with clipboard side effect, no grim)
metadata:
  type: project
---

- `qs kill` does not stop the shell for good (2026-11-18): the long-lived `/usr/bin/quickshell` process restarts the instance under a new id, so `niri msg action spawn -- qs -n` afterwards starts a SECOND instance (`-n` races the restart). Check `qs list` after a restart and `qs kill -i <id>` the extra one. The opposite also happens (2026-11-19): after `qs kill; niri msg action spawn -- qs -n` no instance was running at all; spawning again fixed it. Always confirm exactly one instance in `qs list`. A reload can also leave a child `Process` running from the old config (seen with monitor-sensor).
- Start: niri spawns `qs -n` at startup since 2026-11-06 (niri project config). To restart by hand: `qs kill; niri msg action spawn -- qs -n` — owned by niri (so it gets niri's `environment`), not Claude's shell; `-n` refuses a duplicate instance. QuickShell hot-reloads on file save, so no restart is needed after edits.
- Hot reload can silently not fire after an edit (seen 2026-11-18 with a file rewritten by a script): before telling the user to look, check that the count of `Reloading configuration` in `qs log` went up — take the count BEFORE the edit, the reload often lands within milliseconds; if it did not go up, `touch` the file.
- Inspect: `qs list` (running instances), `qs log --no-color | tail` (current instance's log; look for "Configuration Loaded" or ERROR after each save), `qs kill` to stop.
- Visual check: grim is not installed. Use `niri msg action screenshot-screen -p false --path <scratchpad>/shot.png` (captures the *focused* output only, and also overwrites the user's clipboard — mention it). Crop with PIL and Read the image. eDP-1 screenshots are 1920x1200 physical (scale 1.25, logical 1536x960).
- The QuickShell bar was at the bottom of eDP-1 for side-by-side comparison, then moved to the top on 2026-11-06 (`Theme.barAtBottom: false`) while waybar still runs there until cutover.

- Test notifications: `notify-send` is not installed. Use `gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify -- APP 0 ICON SUMMARY BODY '[]' '{"urgency": <byte 1>}' -1` (the `--` is required, otherwise `-1` is parsed as an option). Only one notification server can own the name: swaync is no longer started (replaced 2026-11-06); QuickShell re-registers automatically whenever the name frees up.

**Why:** Claude can't see the screen; this is the loop that lets it verify UI changes itself.
**How to apply:** after a QML change, check `qs log` first, then screenshot only when appearance matters. See also [[qml-gotchas]].
