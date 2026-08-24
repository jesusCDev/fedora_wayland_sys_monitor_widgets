
## 2026-08-16 01:29 — System and battery attention blink
reviewer: opus · 2 files changed, 70 insertions(+), 18 deletions(-)
Plan file can't be written — `Write` is disabled this session. Plan inline:

## What's in the diff

Two things. Icon attention blink (CPU/GPU/RAM/disk PNG swap + battery glyph color) — done, already logged in `tasks/todo.md`. Tooltip anchor follow — **unfinished**, still carries three `[tipdbg]` `console.log` lines.

## Proposed changes — `org.jesuscdev.sysmonitor/contents/ui/main.qml`

**1. Rearm must round-trip event loop.** `segHovered()` (main.qml:402) clears `tipRearming` via `Qt.callLater`. That fires after current script evaluation but inside same event-loop pass — Dialog can coalesce hide+show and never recompute position, which is the exact bug. Swap for zero-interval Timer:

```qml
Timer { id: tipRearmTimer; interval: 0; onTriggered: root.tipRearming = false }
```
`segHovered`: `tipRearming = true; tipRearmTimer.restart()`.

**2. Delete debug logs** — main.qml:43, main.qml:44, main.qml:403.

**3. Keep the `onExited` guards** (6 sites). Correct as written: fast slide delivers next segment's `onEntered` before previous `onExited`; unguarded clear blanks a tooltip another segment now owns.

**4. `tasks/todo.md`** — one line under Bugs: tooltip re-anchors on segment slide, 2026-08-16.

## Verification

No harness for a plasmoid. Live check:
1. `kquitapp6 plasmashell && kstart plasmashell`
2. Slide pointer CPU → GPU → RAM → NET → BAT → AI without leaving widget. Tooltip must move under each segment, title/body must match.
3. Reverse, then jump non-adjacent (CPU → BAT).
4. Leave widget — tooltip gone, no orphan window.
5. `journalctl --user -u plasma-plasmashell -n 100 | grep tipdbg` returns nothing.

Still stuck at step 2 → bump `interval: 16` (one frame). Still stuck → fallback: anchor `visualParent` to whole compact representation, drop `hoverAnchor`, tooltip stops moving at all.

Skipped: `/xreview` (single file, under multi-file trigger). Battery scroll-wheel brightness stays parked per todo.md.

Say go and I'll apply it — or tell me you wanted something else from the diff (review, commit), since no request text came with it.

### Resolution

- [x] Attention-blink implementation: accepted. The reviewer described the
  CPU/GPU/RAM/disk PNG swap and battery glyph-color swap as done and raised no
  correctness or security finding against this feature.
- [x] Tooltip rearm Timer suggestion: dismissed for this feature. The tooltip
  experiment predates the attention-blink work and is unrelated user-owned
  working-tree state, so changing its behavior here would exceed this task.
- [x] Tooltip debug-log removal: dismissed for this feature for the same reason;
  the existing diagnostic lines are preserved for the separate tooltip work.
- [x] Guarded tooltip `onExited` handlers: no action required. The reviewer
  explicitly found the existing guards correct.
- [x] Tooltip todo entry: dismissed as unrelated to the attention-blink feature.

## 2026-08-18 02:12 — Validation sweep of 2026-08-13..16 work
reviewer: three parallel opus audits (aggregated sampler + hw probe, panel polish, GPU tooltip anchor)

### Findings and resolution
- [x] Tooltip fix had never run. plasmashell PID 2440 started 2026-08-15 21:20;
  main.qml was edited 2026-08-16 01:22; zero `[tipdbg]` lines in seven days of
  journal. Restarted 2026-08-18 02:12 (PID 2713981) — first instance to load it.
- [x] `Qt.callLater` fires inside the same event-loop pass, so the Dialog can
  coalesce hide+show and skip repositioning. Replaced with a zero-interval
  `Timer` (`tipRearmTimer`).
- [x] Three `[tipdbg]` `console.log` lines removed; `onXChanged` among them,
  which would have logged on every reposition.
- [x] `metricIconAspect` gpu was 1.49; the real file is 78x52 = 1.5 exactly.
  Corrected, along with ram 2.46 -> 2.4615.
- [x] Net hover dropped any part of a connection name after a `|`, because the
  parser read only `f[2]` of an unbounded split. Now `f.slice(2).join("|")`,
  plus a guard for nmcli's literal `--` on a device with no active profile.
- [x] AC probe selected the first power supply exposing `online`, ignoring
  `type`. USB-C PD source ports also expose it, so a machine whose mains supply
  sorts later would have tracked a USB port. Now requires `type` = `Mains`.
- [x] `probeHardware()` is async but `refreshAll()` ran synchronously right
  after it, so the first sample used default paths — wrong battery on any
  machine whose battery is not BAT0. `refreshAll()` now runs on probe
  completion; the tick Timer still drives it if the probe never returns.
- [x] Comment claimed the hw defaults were all ThinkPad values; the temp files
  actually default to `/dev/null`. Corrected.
- [x] NET `maxValue` is not strictly the widest sub-100M string (`1024K/s`
  measures 92.9px vs `99.9M/s` 92.6px). Dismissed: 0.3px, absorbed by
  `Math.ceil`, no visible jiggle.
- [x] Re-enabling a toggled-off metric yields one bogus tick, because
  `netFirstRun`/`cpuFirstRun` stay false across the off period. Dismissed here:
  pre-existing, predates the aggregation refactor. Logged in todo.md.
- [x] A tick still in flight when the timer fires is skipped, and the next
  sample then covers two intervals but is divided by one. Dismissed here:
  unverified at runtime, and an improvement over the old per-metric pile-up.
  Logged in todo.md.
- [x] `claude-mascot@2x.png` is 26x26, half the 52x52 base, and referenced by
  nothing. Dismissed: dead file, no behavior impact. Logged in todo.md.

### Open
None. User retested hover across all segments on the new plasmashell instance
2026-08-23: working as expected, right-edge clipping included.
