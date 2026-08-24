# Handoff — written 2026-08-18 16:10 EDT

## TASK

KDE Plasma 6 panel widgets (repo symlinked into `~/.local/share/plasma/plasmoids/`).
Current thread: finish the hover-tooltip re-anchor work in
`org.jesuscdev.sysmonitor/contents/ui/main.qml` and land the 2026-08-18
validation-sweep fixes (three parallel opus audits of the 08-13..16 work).

User constraints not written elsewhere:
- User rejected manual tooltip placement (mapToGlobal + clamping) on 2026-08-16
  — "this is way worse". Never reintroduce it. `visualParent` + rearm blink is
  the accepted approach.
- User rejected scroll-wheel gestures once (workspaces widget). Ask before
  adding ANY scroll interaction anywhere (battery brightness scroll is parked
  on this).
- User declined AI-segment width reservation (countdown moves ~every 10 min).
- Caveman (terse prose) + Ponytail (laziest working fix) modes active.
  Commits/code in normal prose.

## DONE

- All of `tasks/todo.md` up through the 08-16 attention-blink work (committed
  through `7646042`, pushed).
- 2026-08-18 validation sweep (3 opus audit agents) — findings + resolutions
  recorded in `tasks/reviews.md` section "2026-08-18 02:12". Fixes applied to
  main.qml (UNCOMMITTED, see STATE):
  - `[tipdbg]` debug logs stripped (3 console.log lines).
  - Tooltip rearm: `Qt.callLater` replaced with zero-interval
    `Timer { id: tipRearmTimer }` (main.qml ~:401,408) — callLater fires in the
    same event-loop pass, Dialog can coalesce hide+show and skip repositioning.
  - `metricIconAspect`: gpu 1.49 -> 1.5, ram 2.46 -> 2.4615 (real PNG dims).
  - Net hover SSID: `netConn = f.slice(2).join("|")` (was `f[2]` — truncated
    names containing `|`), plus guard turning nmcli's literal `--` into "".
  - AC probe now requires `type = Mains` (USB-C PD source ports also expose
    `online`; old code picked first alphabetical).
  - `refreshAll()` now called from `parseHwProbe()` completion instead of
    synchronously after async `probeHardware()` — first sample used default
    paths before (wrong battery on non-BAT0 machines). Tick Timer still drives
    later refreshes.
- plasmashell restarted 2026-08-18 02:12 (PID 2713981) — **first instance ever
  to load the tooltip fix** (previous PID 2440 ran since 08-15 21:20, predating
  the 08-16 01:22 main.qml edits; 7-day journal had zero `[tipdbg]` lines).
  Evidence: `systemctl --user show plasma-plasmashell -p ActiveEnterTimestamp`.
- Panel verified rendering clean post-restart (screenshot, no QML errors beyond
  the known-harmless `main.qml:12 Unable to assign [undefined] to
  QQmlComponent*`).
- `tasks/reviews.md` 08-16 attention-blink section: resolution boxes checked.

## IN PROGRESS

Nothing mid-flight. Next action = REMAINING item 1.

## REMAINING (ordered)

1. **User retests hover tooltips** (blocked on user): slide across every
   segment (CPU -> GPU -> RAM -> DISK -> NET -> BAT -> AI, and across the
   battery divider). Prior "works for all but GPU" report was measured against
   pre-fix code, so GPU may already be fine. If GPU still anchors wrong: the
   one real GPU asymmetry is `gpu-top.sh` taking ~700ms (hardcoded `sleep 0.6`)
   while every other hover source is <10ms — tooltip shows with the "GPU idle"
   placeholder width, then resizes when data lands; test by dropping the sleep
   to 0.05 and re-sliding.
2. **Right-edge clipping check**: rightmost segments' tooltips must not run off
   screen. Verify whether Plasma's Dialog already clamps before writing ANY
   code (manual placement is banned, see TASK).
3. **Commit** the uncommitted work (attention blink + tooltip rearm + sweep
   fixes + todo/reviews updates) once item 1 passes. Logical split: one commit
   for attention blink, one for tooltip rearm + sweep fixes — or a single
   commit; user hasn't expressed a preference.
4. Low-value todo items (see "Open after the 2026-08-18 validation sweep" in
   tasks/todo.md): bogus first tick after re-enabling a metric
   (`netFirstRun`/`cpuFirstRun`), dropped-tick double-interval division,
   delete dead `claude-mascot@2x.png` (26x26, referenced by nothing).
5. Parked, needs user go/no-go: battery scroll-wheel = screen brightness.

## STATE

- Branch: `main`, in sync with origin through `7646042`.
- Uncommitted: `org.jesuscdev.sysmonitor/contents/ui/main.qml` (attention blink
  + tooltip rearm + sweep fixes), `tasks/todo.md`, `tasks/reviews.md`
  (untracked). ALL of it is intended for commit after the hover retest passes.
- No background work running. Audit agents finished; results are fully folded
  into tasks/reviews.md.
- Scratch: session scratchpad held panel screenshots only, disposable.
- `/route`'s `agent-routing.sh` is missing from disk (exit 127) — this session
  used `opus` for subagents per the user's explicit instruction.

## GOTCHAS

- **Restart before judging any main.qml change.** The entire "GPU tooltip
  broken" saga was a stale plasmashell instance. Verify
  `ActiveEnterTimestamp` postdates the file's mtime before trusting behavior.
- Restart loop: `systemctl --user restart plasma-plasmashell && sleep 12`,
  then journalctl grep (ignore `QQmlComponent` line-10/12 warnings), then
  `spectacle -b -f -n -o file.png` (a too-early capture returns solid black).
- `qdbus6` does not exist on this box; use `qdbus`.
- `ls` is aliased to colorls (no `-R`); use `find` for recursive listings.
- Live widget config edits: qdbus evaluateScript with
  `w.currentConfigGroup=["Configuration","General"]; w.writeConfig(k,v);
  w.reloadConfig()`. `showBatSpacer` was enabled this way on both live
  instances — it is NOT the config-file default.
- The workspaces tooltip line prefix uses an em-space (U+2003); plain Edit
  fails on it — use a python3 heredoc with an assert on count.
- xreview ledger rule: every feature section in `tasks/reviews.md` needs all
  boxes checked before "done". Both existing sections are fully checked; the
  08-18 section's "Open" note (hover retest) maps to REMAINING item 1.
