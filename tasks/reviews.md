
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

## 2026-08-23 20:26 — Battery scroll brightness, net rate wall-clock fix, ccusage default off
reviewer: gpt-5.6-terra · 4 files changed, 43 insertions(+), 11 deletions(-)
- [x] no findings

## 2026-08-23 21:15 — New bluetooth widget: panel glyph, connect/disconnect, scan+pair
reviewer: gpt-5.6-terra · 1 file changed, 7 insertions(+)
Superseded: the widget files were untracked, so this run only saw the todo.md
edit. Re-run below with everything staged covers the actual feature.
- [x] org.jesuscdev.bluetooth/contents/ui/main.qml:125 — the scan timeout exits `bluetoothctl` but never sends `scan off`, so adapter discovery can remain active indefinitely despite the configured scan duration — explicitly stop discovery after the timeout (including failure/cancel paths) before refreshing results
  Dismissed: refuted empirically — see the same finding in the full re-run below.

## 2026-08-23 21:16 — New bluetooth widget full review: panel glyph, connect/disconnect, scan+pair
reviewer: gpt-5.6-terra · 7 files changed, 588 insertions(+)
- [x] org.jesuscdev.bluetooth/contents/ui/main.qml:125 — scan timeout does not send `bluetoothctl scan off`, leaving discovery active beyond the configured duration — explicitly disable scanning on completion and failure paths
  Dismissed: refuted live 2026-08-23 — BlueZ discovery is per-client and stops
  when the client disconnects; `bluetoothctl --timeout 5 scan on` followed one
  second later by `bluetoothctl show` reported `Discovering: no`.

## 2026-08-24 03:38 — Check-now feedback: script throttle, force bypass, button hold, footer error
reviewer: gpt-5.6-terra · 9 files changed, 630 insertions(+), 4 deletions(-)
- [x] org.jesuscdev.bluetooth/contents/ui/main.qml:301 — attacker-controlled Bluetooth device names are rendered by `Text` using default `AutoText`, allowing rich-text markup injection in the tooltip and popup — set `textFormat: Text.PlainText` on every device-name `Text` element.
  Fixed 2026-08-24: `textFormat: Text.PlainText` set on all three device-name
  Texts (tooltip row, popup paired row, popup found row); the panel path was
  already escaped via `escapeHtml()`.

## 2026-08-29 08:27 — AI hover/popup rework, Fable panel meter, codex spark toggle, RAM pressure warn, hover dead zone
reviewer: gpt-5.6-terra · 11 files changed, 1060 insertions(+), 305 deletions(-)
- [x] org.jesuscdev.bluetooth/contents/ui/main.qml:345 — hover gating uses scene/window Y rather than the panel item's local Y, so edge panels make the entire widget “live” and the intended dead band never applies — calculate the fraction as `m.y / height` and clear hover when it leaves the live range.
  Dismissed: window Y is intentional — the dead band is a fraction of the
  panel, and the panel window is the panel (38px, non-floating). Local
  `m.y / height` would gate against the centred text item (~22-78% of the
  panel), moving the cut ~1px. Left/right panels degrade to always-live
  (old behaviour), out of scope. Hover is not cleared on leaving the band
  on purpose: the exit path to the desktop crosses it and would flicker.
- [x] org.jesuscdev.sysmonitor/contents/ui/main.qml:605 — `segHoverAt()` receives a scene/window-coordinate fraction, causing its top/bottom panel hover dead zone to be ineffective — pass `m.y / height` from each `MouseArea` (and clear the active hover outside the live range).
  Dismissed: same as above — verified with offscreen qmlscene self-check
  (item at y=9 in a 38px window: local y 13 live, 14 dead at 0.6).

## 2026-09-01 04:22 — Notify Inline widget: org.kde.notificationmanager history, copy chips, per-app colors
reviewer: gpt-5.6-terra · 17 files changed, 1610 insertions(+), 305 deletions(-)
- [x] org.jesuscdev.notify/contents/ui/util.js:48 — `copyCmd()` passes shell redirections and the uniqueness suffix directly to the executable DataSource, which does not interpret shell syntax; `wl-copy` receives them as literal arguments and copying can fail or include unintended text — execute the quoted `wl-copy` command through `sh -c` (with the suffix only in the DataSource key).
  Dismissed: the executable engine runs commands through `sh` (KProcess::setShellCommand). Verified offscreen (scratchpad/ds-test.qml): `Plasma5Support.DataSource` given `printf %s 'it'\''s x' > file 2>&1 #7` wrote `it's x`, exit 0 — redirection, quote escaping and the `#seq` suffix all interpreted. Wrapping in a second `sh -c` would only add a quoting layer.

## 2026-09-01 05:00 — Notify Inline round 2: @other blacklist, own unread recount, PNG bell, text clear link
reviewer: gpt-5.6-terra · 21 files changed, 1655 insertions(+), 305 deletions(-)
- [x] org.jesuscdev.sysmonitor/contents/ui/main.qml:280 — the Claude/Codex/local-spend content was moved into the hover tooltip and removed from `fullRepresentation`; opening the AI popup now shows only its footer rather than usage details — retain/render those sections in the `popupMode === "claude"` popup layout
  Dismissed: intentional — the user asked for the AI usage sections to move from the click popup into the hover tooltip ("is it possible to move the on click pop-up into the hover pop-up? (other then the button)"); the click popup deliberately keeps only the check-now footer.
- [x] org.jesuscdev.notify/contents/ui/main.qml:207 — uses `Window.height` without importing `QtQuick.Window`, causing the hover handler to fail at runtime on normal QML import resolution — import `QtQuick.Window` or use the local item’s `height`
  Dismissed: in Qt 6 the `Window` attached type is exported by the QtQuick module itself (`QtQuick/Window 2.0`), so it resolves under `import QtQuick 2.15`. Proven offscreen (scratchpad/hoverzone-test.qml: `Window.height` read fine) and live — the same expression has driven the hover gate in both panel widgets for days with no journal errors.
- [x] org.jesuscdev.bluetooth/contents/ui/main.qml:349 — uses `Window.height` without importing `QtQuick.Window`, causing the hover handler to fail at runtime on normal QML import resolution — import `QtQuick.Window` or use the local item’s `height`
  Dismissed: same as above — attached `Window` resolves from `import QtQuick` in Qt 6; verified offscreen and live.
- [x] org.jesuscdev.notify/contents/ui/main.qml:277 — the “clear all” control passes `ClearExpired`, which leaves active/non-expired notifications (including critical notifications) in the model — use the appropriate clear flags or relabel the action to reflect that it only clears expired history
  Fixed: `clearAll()` clears expired history and then `close()`s every remaining (active) row, which also dismisses their on-screen popups.

## 2026-09-02 08:06 — Notify Inline round 4: seen() rule, Personal/System tabs, auto-dismiss sweep, content-sized popup
reviewer: gpt-5.6-terra · 21 files changed, 1810 insertions(+), 307 deletions(-)
- [x] org.jesuscdev.sysmonitor/contents/scripts/fetch-usage.sh:210 — the 45-second cache window cannot coalesce synchronized 60-second pollers; both instances see a 60-second-old cache and still hit the API together — use a TTL longer than the poll cadence or a shared lock.
  Fixed: `flock` on `$CACHE.lock` before the throttle check serialises the runs; the second instance then reads the cache the first just wrote. Verified with two concurrent runs returning the same `fetched_at`.

## 2026-09-13 07:52 — Panel icons centred/bigger, transfers hides finished jobs, notify sweep removed + scrollbar lane
reviewer: gpt-5.6-terra · 24 files changed, 2058 insertions(+), 489 deletions(-)
- [x] no findings

## 2026-09-13 19:28 — Notify: TSV log, group rules across apps, Critical section, twins under head
reviewer: gpt-5.6-sol · 24 files changed, 2300 insertions(+), 488 deletions(-)
- [x] org.jesuscdev.bluetooth/contents/ui/main.qml:242 — pairing, trusting, and connecting are chained with unconditional semicolons, so a failed authentication can still leave an unpaired device trusted — gate each step on confirmed success, e.g. `pair && trust && connect`
  Fixed: `pair && trust && connect` — bluetoothctl 5.87 exits 1 on failure (checked with `info` on a bogus MAC), so a failed pair no longer trusts the device.
- [x] org.jesuscdev.notify/contents/ui/main.qml:143 — every notification body, including authentication codes and private messages, is persisted by default in a file whose permissions inherit the process umask — make logging opt-in and create the directory/file with 0700/0600 permissions
  Fixed: `umask 077` before creating dir/file (0700/0600), `logEnabled` config toggle added. Default stays on — the user asked for the log in this round; dismissal of the opt-in half on that basis.
- [x] org.jesuscdev.sysmonitor/contents/ui/main.qml:1258 — `fableAlertState()` suppresses a 100% meter when the API still reports `severity=warning`, despite other code treating 100% as exhausted — return `"exhausted"` whenever the parsed percentage is at least 100
  Dismissed: the line above (1257) already returns "exhausted" for `pct >= 100` regardless of severity; the comment about no warning tier is about <100% only.
- [x] org.jesuscdev.sysmonitor/contents/ui/main.qml:290 — the Claude section is gated only by `hoverSeg === "ai"`, so disabling Claude while leaving Codex enabled still displays Claude data — include `showClaude` in every Claude-only section’s visibility condition
  Fixed: the five Claude-only tooltip items (header, stale, alert banner, limits Repeater, sparkline) now also require `root.showClaude`.
- [x] org.jesuscdev.sysmonitor/contents/ui/main.qml:287 — all variable-length AI details were moved into a non-scrollable tooltip, so sufficiently many limits or model breakdowns can extend beyond the screen and become unreachable — retain the bounded click popup or put the tooltip contents in a height-capped Flickable
  Dismissed: the hover move was the user's explicit request (2026-09-01); the rows are bounded (a handful of API limits plus Codex rows), nowhere near screen height.
- [x] org.jesuscdev.notify/contents/ui/main.qml:149 — concurrent log commands share one rotation temporary file and use millisecond timestamps as source uniqueness, allowing burst notifications or simultaneous rotations to coalesce or lose entries — serialize append/rotation with `flock` and use a monotonic sequence plus a per-run temporary file
  Fixed: `flock` on `<log>.lock` serialises append + trim, temp file is `.tmp.$$`, DataSource key uses a monotonic `logSeq` instead of the millisecond clock. Burst-tested: 6 notify-send calls back to back, 6 lines.

## 2026-09-19 11:23 — Transfers lead bar + hover tooltip, notify hashed app colours
reviewer: gpt-5.6-terra · 24 files changed, 2514 insertions(+), 489 deletions(-)
- [x] org.jesuscdev.notify/contents/ui/main.qml:140 — log paths derived from `$XDG_STATE_HOME`/`$HOME` are expanded unquoted, so state directories containing spaces cause logging and rotation to fail — assign the directory in shell and quote every `"$d"`/`"$lp"` path use
  Fixed: dir and file are shell variables now, double-quoted at every use (mkdir, lock, append, wc, tail, mv). Tested the exact command shape with XDG_STATE_HOME set to a directory containing spaces: dir 700, file 600, line written with quotes intact; live reload logged a notification containing quotes and an ampersand.
