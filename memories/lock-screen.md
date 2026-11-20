---
name: lock-screen
description: QuickShell lock screen as built 2026-11-07 (LockScreen/LockContent/LockBlur): verified facts about WlSessionLock/PamContext v0.3.2 and niri, crash relock via flag file, the no-signal-on-unlock bug, safe testing procedure
metadata:
  type: project
---

Built and cut over 2026-11-07 (replaces swaylock). Entry points: niri `Super+Alt+L` → `spawn-sh "qs ipc call lock lock || swaylock"` (niri project), power menu 「鎖定」 → `LockScreen.lock()`. Setting `lock.background: dim|blur` (default dim; blur needs `qml6-module-qtquick-effects`, not installed as of 2026-11-07 — falls back to dim with a log warning, verified).

Verified facts (source or live test, not guesses):
- QuickShell 0.3.2 `WlSessionLock` (`locked`, `secure`, default property = surface component → `WlSessionLockSurface` per screen) survives hot reload (`onReload` hands the manager over); `locked` is bound to a `PersistentProperties` bool.
- **Bug in v0.3.2**: `WlSessionLock::unlock()` (src/wayland/session_lock.cpp ~181) unlocks the manager *before* checking `isLocked()`, so `lockStateChanged` is never emitted on unlock (nor when acquiring the lock fails). Do cleanup in our own code paths (`authenticated()` → `finishUnlock()`); lock failure is detected by a 1 s `lockCheck` timer (`persist.locked && !session.locked`). The first version relied on `onLockedChanged` and left the flag file behind.
- PAM: `PamContext` default config `login` (always exists; `/etc/pam.d/swaylock` would vanish with swaylock). `login` has pam_faildelay 3 s, so a wrong password shows 「密碼錯誤」 after ~3 s. Password is handed over in `onResponseRequiredChanged` after `start()`. Verified by the user (preview and real lock).
- niri 26.04: if qs dies while locked, the session stays locked (solid red); `Niri::lock()` accepts a new lock when the old client is dead (log: "locking session (replacing existing dead lock)").
- niri ignores `niri msg action spawn` (any non-allow-when-locked action, src/input/mod.rs `do_action`) while locked. So after `qs kill` during a lock, qs can only be restarted from a shell directly (`setsid -f qs -n`) or a TTY.
- Crash relock verified 2026-11-07: lock → `kill -SEGV` qs → QuickShell's crash handler restarts it → `LockScreen` sees `$XDG_RUNTIME_DIR/rtfs-locked` → locks again within ~2 s; user unlocked with password. A clean `qs kill` is NOT restarted by the crash handler.
- The crash-restarted qs instance did not hot-reload (same as the login-spawned case in [[qml-gotchas]]); restart it via niri after unlocking.
- `qs ipc call` exits 255 when no instance runs, which is what makes the `|| swaylock` fallback work.

Design notes: no `unlock` IPC (password only). `lock preview` toggles a full-screen Overlay `PanelWindow` (namespace `rtfs-lock-preview`, Exclusive keyboard) with the same content and real PAM, for screenshots and safe PAM testing; notification banners appear above the preview (not above the real lock). Logs `LockScreen: authenticated, unlocking` so unlocks can be audited after the fact.

Aftermath of crash tests: each QuickShell crash opens a crash-report dialog window (app id `org.quickshell`, separate process) that the user sees later — warn the user beforehand and close them (`niri msg action close-window --id`) afterwards. `qs kill` on a crash-restarted instance led to a second crash (SIGABRT "Tried to reinitialize QuickshellTracked" in `QuickshellTracked::init`, report in `~/.cache/quickshell/crashes/<run id>/`). Cleaner: after the test, `kill` the qs process (SIGTERM) and `niri msg action spawn -- qs -n` while unlocked; ensure the final instance's parent is niri/systemd, not Claude's shell.

Safe testing: preview first; real lock only with the user present; keep a recovery path ready (direct `qs -n` from Claude's shell, or TTY `WAYLAND_DISPLAY=wayland-1 swaylock`). Keep swaylock installed.

Auto lock (2026-11-07, `AutoLock.qml`, user chose: lock after idle + screen off while locked; defaults 300 s / 30 s / before-sleep on): niri supports ext-idle-notify (IdleMonitor reported idle in a windowless test); `rtfs-sleep-lock` registers a logind `delay` sleep inhibitor (seen in `systemd-inhibit --list`), InhibitDelayMaxUSec is 5 s; power key = hibernate, lid = suspend, both go through PrepareForSleep. Verified by the user 2026-11-07: suspend → locked on resume, idle lock, screen off while locked. **v0.3.2 IdleMonitor bug:** changing `timeout` while enabled has no effect (and toggling `enabled` off/on in the same handler doesn't help); AutoLock disables it and re-enables via `Qt.callLater` on every timeout change (tested). Hibernate path not tried.

On-screen keyboard (2026-11-08): in-process `OskKeyboard` `direct` mode inside `LockContent`, see [[osk]]. Key press highlight stays on (shoulder-surfing same as a physical keyboard).

Multi-monitor lock confirmed by the user 2026-11-10. Not done / unverified: hotplug while locked, lock-failure path (another locker active) not exercised, caps-lock indicator, whether a qs crash dump (`~/.cache/quickshell/crashes/`) can contain a typed password.

**Why:** security-critical component; these facts cost live tests and source digging.
**How to apply:** read before touching `LockScreen.qml`; re-check the unlock-signal bug and niri `lock()` behavior when upgrading QuickShell or niri. Related: [[dialog-tool]], [[qml-gotchas]], [[open-work]].
