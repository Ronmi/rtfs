---
name: qml-gotchas
description: QML/QuickShell pitfalls hit in this project (on* property names, color needs QtQuick, broken singleton breaks whole config) and a windowless way to test QML
metadata:
  type: project
---

Pitfalls found on QuickShell v0.3.2 / Qt 6.8.2 (2026-11-06):
- Property names matching `on[A-Z]...` are parsed as signal handlers ("Cannot assign a value to a signal"). Generated `Colors.qml` hit this with `onAccent`; the niri palette role was renamed `ON_ACCENT` → `ACCENT_FG`, and `theme-gen` now refuses such names.
- `color` (and `Component.onCompleted`) need `import QtQuick`; `import Quickshell` alone gives "color is not a type" / "Non-existent attached object".
- A singleton in the config dir that fails to compile makes the *whole* config fail to load, even if `shell.qml` never references it.

- QuickShell `Socket` does not reconnect after a disconnect or failed connect (`targetConnected` is cleared once connected); retry yourself on `connectionStateChanged`/`error`. Its change signal is `connectionStateChanged`, so the handler is `onConnectionStateChanged`, not `onConnectedChanged`.
- Unexplained once (2026-11-06): right after adding a new singleton (`Niri.qml`) via hot reload, the bar showed no workspaces although events arrived; it worked after the next reload and on 3 clean restarts. If a newly added singleton seems dead after hot reload, restart qs before debugging.

- Qt 6.8's JS engine rejects `??=` ("Unexpected token `='"); `??` and `?.` work.
- A NEW QML type file (e.g. `MenuEntry.qml`, 2026-11-17) is not picked up by hot reload: users fail with "MenuEntry is not a type" even after `touch shell.qml`; `qs kill; niri msg action spawn -- qs -n` fixes it. Restart qs after adding a component file.
- Pipewire `PwNode.properties` is EMPTY until the node is bound by a `PwObjectTracker` (2026-11-17: only the tracked default sink/source had `media.class`). Filter nodes by `type` (`PwNodeType.AudioSource`, `AudioInStream`, …) instead; track a node first if you need a property (e.g. `stream.monitor`).
- Hot reload triggering is inconsistent: on 2026-11-06 `touch` alone did not trigger a reload; on 2026-11-07 a `sed -i` and an Edit-tool save of `Osd.qml` did NOT trigger one while a following `touch` did. After every edit, check `qs log` for a new "Reloading configuration..." before judging the result; if missing, `touch` the file or make a content change, else restart qs.
- Forcing a `PopupWindow` visible in `Component.onCompleted` (for screenshots) places it wrongly (sized before layout; also logged "popup is not an xdg_popup"); opening it by a real click is fine. For screenshot tests, open it after a short `Timer` delay instead, or ask the user to click.

- Platform menus (`QsMenuAnchor`; no longer used, tray menus are custom since 2026-11-06 and the pragma was removed) need QApplication mode: `//@ pragma UseQApplication` as the first line of `shell.qml`, then restart qs (hot reload is not enough). Without it `open()` only logs an ERROR and nothing appears.

- niri v26.04: an xdg_popup from the bar (`PopupWindow` with `grabFocus`, also waybar's GTK menus) is NOT dismissed by clicking another window, only by clicking the desktop or the bar; root cause not found (niri's grab handler looked fine on reading). `PanelPopup.qml` therefore uses a full-screen transparent `PanelWindow` (Top layer, Exclusive keyboard) with the panel drawn inside; clicking the transparent area closes it. `Tooltip.qml` (no grab needed) still uses an xdg_popup. Tray menus are drawn by `TrayMenu.qml` on top of `PanelPopup`, so they dismiss correctly; the Qt platform menu (`QsMenuAnchor`) was dropped for looks, not for dismissal (user said it closed fine).

- Icons missing from the theme render as a magenta/black checkerboard, not as an empty image (tray menu entries `view-refresh`/`application-exit` from fcitx5). Check `image://icon/<name>` URLs with `Quickshell.hasThemeIcon(name)` before showing them.

- niri v26.04 keyboard focus for layer surfaces (`update_keyboard_focus`, src/niri.rs): checks the *active output* only, Overlay before Top; within a layer, an Exclusive surface beats the on-demand one, and among Exclusive surfaces the first found wins. So anything that must type while kitty's quick-access-terminal (Top, Exclusive) is open must be Overlay + Exclusive (`PanelPopup`, `ConfirmDialog`, banners while replying). Never give an auto-appearing window `OnDemand`: niri hands focus to newly mapped OnDemand surfaces (src/handlers/layer_shell.rs), so every notification banner stole the keyboard (user confirmed 2026-11-06). Banners are `None` and switch to `Exclusive` only while a reply box is open.

- Unexplained (2026-11-06): the qs instance niri spawned at login did not hot-reload at all (no "Reloading" in `qs log`; it also took 20 s to reach "Configuration Loaded"), although it held inotify watches. After `qs kill; niri msg action spawn -- qs -n` hot reload worked, with both in-place writes and the Edit tool's replace-by-rename (inode change is fine). If edits seem ignored right after login, check `qs log` for "Reloading" and restart qs. Watch whether it recurs on the next login.

- A `Repeater` whose model is a JS array recreates *all* delegates whenever the array is reassigned, so `Behavior` animations never run (new delegates start in their final state). Our singletons replace arrays on every update (`Niri.workspaces`), so for animated lists use `model: arr.length` and read `arr[index]` in the delegate; delegates then persist until the count changes.

- `PolkitAgent` does not survive hot reloads cleanly: after a reload it still reported `isRegistered: true`, but `pkexec` requests hung with no dialog (went to a stale agent). The first registration also fails if another agent (MATE's, from xdg autostart) holds the session, and reloads don't retry. After editing `PolkitDialog.qml`, restart qs (`qs kill; niri msg action spawn -- qs -n`) before testing.

- `qs kill` right after a save (while a hot reload was in progress) crashed qs during shutdown (2026-11-06): `EngineGeneration::shutdown` → destroying a layer-shell window → a `Text` recomputes its size → `QFontDatabase` fatal (font DB already gone). Exit-time only; the crash handler restarted qs (which then holds the instance, so a following `qs -n` spawn exits). Wait a few seconds after saving before `qs kill`; report: `~/.cache/quickshell/crashes/<id>/report.txt`.

Windowless test: put a `shell.qml` with `import QtQuick` / `import Quickshell` and `ShellRoot { Component.onCompleted: { console.log(...); Qt.quit() } }` (plus copies of the files under test) in a scratchpad dir, run `timeout 15 qs -p <dir>`, grep output for `ERROR` and the log line. `qs -p shell/` with `timeout 5` checks that the real config reaches "Configuration Loaded"; it starts a second instance, so do this only while `shell.qml` creates no windows (later: ask the user or use the hot-reloading running instance).

`qs log` of the running instance hides `console.log` (debug level; seen 2026-11-17): use `console.warn` for temporary probes in the hot-reloaded shell, or the probe looks like it never ran.

- A JS `const`/`let` in a binding or function that has the same name as an element `id` in the file shadows the id for the whole block, so earlier uses of the id hit the temporal dead zone: `ReferenceError:  is not defined` (empty name) at the binding's line (SystemPopup battery line, 2026-11-20). Pick local names that are not ids.

- A mouse click on a `MouseArea` button does not take focus from a `TextInput`, so `editingFinished` never fires; values committed only on editingFinished are lost when the user types and clicks a button (fixed in `FieldNumber` 2026-11-07: `value` parses the live text).

- Do not switch an Item between top and bottom with conditional `anchors.top: c ? parent.top : undefined` / `anchors.bottom: c ? undefined : parent.bottom`: the old anchor is not reliably released first, so the item got stretched to full height or stuck (OSK in `DialogFrame`, 2026-11-08). Bind `y` instead (or use `AnchorChanges` in states). `PanelWindow.anchors` (layer-shell edges) is a different thing and switches fine.

- `SettingsWindow.qml[181]: Unable to assign QQuickWindowAttached to QQuickItem` (one per settings page) appears only when a hot reload happens while the settings window is open (measured 2026-11-08: open/close via IPC 0, reload while closed 0, reload while open 10). Likely the window hand-over during reload; `Window.activeFocusItem` is a normal `null` otherwise. Harmless dev-time noise; the user chose not to loosen the property type to `var` to silence it. Don't investigate again.

**Why:** these errors cost several iterations; the user has no QML background, so explain them when they come up.
**How to apply:** check new QML (especially generated files) with the windowless test before asking the user to look at anything on screen.

- IpcHandler signals (v0.3.2): a signal emitted during load is not delivered to `qs ipc listen`, not from `Component.onCompleted`, not from `Quickshell.onReloadCompleted`, not even with `Qt.callLater` there (the forwarding is connected in `IpcHandler::onPostReload`, apparently later). A 500 ms `Timer` worked (2026-11-06). Listeners themselves survive reloads (matched by target name). `qs ipc listen`/`call` fail and exit while the target is not registered yet (startup/reload), so clients must retry. Script tests against the live qs show real dialogs — `QS_CONFIG_PATH=/nonexistent` does NOT isolate them; fake `qs` on PATH to test the no-instance path.

- New QML files added while qs runs are sometimes "X is not a type" for other files until one more reload that happens *after* they exist (2026-11-06: reloads right after creation still missed `DialogScrollBar`/`DialogCheckBox`). Force a reload (change any file's content) before debugging.
- Objects passed through `Loader.setSource(url, {prop: obj})` (and `createObject`) arrive with nested arrays as Qt sequence types: `Array.isArray` is false, `String(row)` gives "a,b,c". Normalize with `JSON.parse(JSON.stringify(x))` before treating them as JS arrays (`FieldList`).
- `Text.fontInfo.family` reports the default font, not the resolved one, when the Text has no text; give the probe some text (it may stay invisible). `Qt.fontFamilies()` lists localized names (「芫荽」, 「文泉驛微米黑」), so match a configured English name through such a probe (`FieldFont`).
- `visible` is the *effective* visibility: a child's `visible` reads false while its parent is hidden. So `parent.visible: childA.visible || childB.visible` deadlocks hidden forever (hit in `Osd.qml` 2026-11-07); base such bindings on the data, not on children's `visible`.

- `PersistentProperties` (v0.3.2): `var` properties holding JS objects/arrays come back `undefined` after a hot reload (the objects belong to the old engine); strings and bools survive. Store objects as JSON strings (`Wallpaper.qml`, 2026-11-07).

- `WlSessionLock` (v0.3.2) never emits `lockedChanged` on unlock or on a failed lock; see [[lock-screen]].
