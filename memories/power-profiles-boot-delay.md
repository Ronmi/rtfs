---
name: power-profiles-boot-delay
description: Never touch Quickshell PowerProfiles directly — it blocks QML load ~20s at boot (gdm's 20s plymouth timer → ppd late); use PowerProfileState
metadata:
  type: project
---

Use the `PowerProfileState` singleton (`shell/PowerProfileState.qml`) for power profiles; never reference `PowerProfiles` from `Quickshell.Services.UPower` anywhere else. Reading `PowerProfile.*` enums is fine (does not instantiate the singleton).

Chain found 2026-11-07 (bar appeared ~20s after wallpaper):
1. gdm 48 hard-codes a 20s timer before `plymouth quit` in the login path used on this machine (`daemon/gdm-manager.c` `on_user_session_started`), independent of session registration — calling `RegisterSession` early from niri was tried and did NOT help.
2. `multi-user.target` waits for `plymouth-quit-wait`, and `power-profiles-daemon.service` has `After=multi-user.target`, so ppd starts ~20s after login.
3. QuickShell v0.3.2 `PowerProfiles` constructor builds a `QDBusInterface`, which introspects synchronously → triggers D-Bus activation and blocks the whole config load until ppd is up.

`PowerProfileState` runs `gdbus wait --system org.freedesktop.UPower.PowerProfiles` (no activation, no timeout) and only evaluates `PowerProfiles` after it exits 0. Before that the bar shows a dim question-mark placeholder and the popup hides the profile section (user's choice). Verified after reboot: config loads in <1s.

**Why:** any early binding on `PowerProfiles` (even in a hidden popup) brings back the 20s blank bar at boot.
**How to apply:** new power-profile UI goes through `PowerProfileState` (`ready`, `profile`, `hasPerformanceProfile`, `set()`). If another QuickShell service ever blocks load at boot, check `qs log --log-times` for a gap and the service's start time (`systemctl show -p ActiveEnterTimestamp`). System-side alternatives rejected for now: overriding ppd's `After=` (full unit copy), neutering plymouth-quit-wait; upstream report deferred by the user. See [[qml-gotchas]], [[open-work]].
