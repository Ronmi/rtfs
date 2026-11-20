---
name: quick-terminal-overview
description: kitty quick-access-terminal covers niri's overview (Top layer); QuickTerminalAutoHide.qml hides it while the overview is open and restores it; detects the panel state by keyboard interactivity (Exclusive = shown)
metadata:
  type: project
---

niri v26.04 draws Top/Overlay layers above the overview whenever the overview is open (`render_above_top_layer` is false during overview/workspace-switch animations), and `place-within-backdrop` only works for background-layer surfaces. kitty's quick-access-terminal is Top layer (niri project's memories/quick-access-terminal.md), so it covered the overview.

The hidden panel's layer surface stays in niri's `Layers` list. 2026-11-06 (niri v26.04): hidden = `Background` + keyboard `None`, shown = `Top` + `Exclusive`. 2026-11-10 (niri main 9955d92, same kitty 0.50.0): the layer stays `Top` in both states, only keyboard interactivity flips; the old layer check then saw a hidden panel as "Top" and *opened* it on overview. So the check uses `keyboard_interactivity === "Exclusive"` (relies on the bind's `--focus-policy=exclusive`). `kitten quick-access-terminal` only toggles, so state must be checked first.

`shell/QuickTerminalAutoHide.qml`: on overview open, `Niri.query("Layers")`; if the panel is Exclusive, toggle it and remember. On close, only if we hid it and it is still not Exclusive, toggle it back (user wanted it restored, 2026-11-06). Verified both "panel open" and "panel already hidden" cases (again 2026-11-10 after the switch to keyboard interactivity).

**Why:** user asked whether the overlap is normal and preferred auto-hide with restore.
**How to apply:** if kitty or niri change what `Layers` reports for a hidden panel, the check must change too; re-measure by toggling and diffing `niri msg -j layers`. Restored panel gets keyboard focus only if eDP-1 is the active output (same niri limitation as the Ctrl+F12 bind). Related: [[qml-gotchas]].
