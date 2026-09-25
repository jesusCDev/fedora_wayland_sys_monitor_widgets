# Handoff — written 2026-09-13 (evening, local); REMAINING/STATE updated 2026-09-25

## TASK
KDE Plasma 6 panel widgets repo (`~/Programming/fedora_wayland_sys_monitor_widgets`,
each `org.jesuscdev.*` dir symlinked into `~/.local/share/plasma/plasmoids/`).
Main thread: `org.jesuscdev.notify` ("Notify Inline"), a second notification bell
the user runs NEXT TO the stock one, iterated through user feedback rounds. This
session (2026-09-12 → 2026-09-13) also touched the transfers widget and the
bluetooth widget's panel icon. All delivered and reloaded; waiting on the user's
next round or "go" to commit.

User constraints not written elsewhere:
- Commit ONLY when the user says "go". Everything since commit 6cc571e is one
  uncommitted batch (see STATE). Before committing, ask about two generated
  binaries: `org.jesuscdev.sysmonitor/contents/icons/fable-mascot.png` (untracked)
  and the three notify bell PNGs (intent-to-add). `assets/masters/*.png` stays ignored.
- Bell rows stay until the user dismisses them (they said so on 2026-09-13; the
  earlier 60-minute auto-dismiss sweep was removed for that reason).
- No manual tooltip placement (`visualParent` + rearm timer is the accepted way).
- Ask before adding ANY scroll gesture. User declined AI-segment width reservation.
- Hover popups trigger only in the top 60% of the panel (Chrome tab overshoot).
- Caveman (terse prose) + Ponytail (laziest working solution) modes active;
  code/commits/security text in normal prose. Global CLAUDE.md now has an
  "Output Formatting" section: one sentence per line, paths/commands in fenced
  blocks, bold lead words.

## DONE (all verified, all uncommitted)
Batch before this session (2026-08-30 → 2026-09-02): bluetooth plasmoid, sysmonitor
check-now throttle/force + `flock`, Fable banner removal, `fablePanelPct` +
fable-mascot.png, hover/popup restructuring, `codexSparkEnabled`, fableSpent logic,
RAM PSI warn, hover dead zone, NET hover headline; notify rounds 1–4 (seen() rule,
tabs, content-sized popup pinned via Layout.min/max). Details in `tasks/completed.md`.

2026-09-12 / 2026-09-13 (this session), evidence noted per item:
- Panel icons: bell (`Image`, 1.8×panelPt) and bluetooth rune (`Text`, 1.5×panelPt)
  are real items in a `Row`, centred; measured from screenshots at 25px/28px ink,
  centred at 27.5–28 vs text 27. Inline `<img>` had ridden the baseline ~3px high.
- Transfers widget: finished jobs no longer linger — both delegates hide
  `JobStateStopped` rows. Proven with synthetic D-Bus job views (before: A 30% +
  B 100% drawn; after: only A). Script pattern: `org.kde.JobViewServer.requestView`
  + `org.kde.JobViewV2` calls from one persistent Gio connection.
- Notify: auto-dismiss sweep + `maxAgeMin` removed; deprecated injected
  `expanded` param replaced by `root.expanded`.
- Notify popup: tabs replaced by stacked sections (Critical → System → Personal,
  empty ones hidden), fixed footer with count line + "clear all", content width
  340–520, height cap 600, scrollbar lane (20px) only when the list overflows.
- Notify grouping: rows fold by key = section + (matched group rule | app + summary).
  Head shows "+N" pill; head × dismisses the group; double-click unfolds twins
  INSIDE the head (time, own summary if different, body, own ×, click copies).
  Group rules config `groupPatterns` (default "claude, youtube") fold rows from
  any app. Proven via temp debug log (Chrome "Claude" + notify-send "Claude
  finished" one group; YouTube HD its own; critical row alone on top).
- Notify Critical section: `urgency === Critical` → section 2, red header, pinned top.
- Notify logging: every inserted row → TSV line (time, app, desktop entry,
  notifyrc, urgency 1/2/4, summary, body) in `~/.local/state/notify-inline.log`,
  0600/0700 via `umask 077`, `flock` serialised, trimmed 3000→2000 lines,
  `logEnabled` toggle (default on). Burst of 6 → 6 lines.
- Drawn × (`CloseButton` inline component, 20px hit box, hover ring); rows have
  8px right padding.
- xreview 2026-09-14 section: 6 findings, 4 fixed (bluetooth `pair && trust &&
  connect`; log hardening; sysmonitor Claude tooltip gated by `showClaude`), 2
  dismissed with reasons. Ledger 0 open. Earlier session xreviews also clean.
- Docs: `tasks/completed.md` created (all finished sections archived),
  `tasks/lessons.md` gained 2026-09-02 and 2026-09-13 entries, memory notes updated
  (popup size sticky, panel icon centring, log path).

## IN PROGRESS
Nothing mid-flight. Last action: plasmashell restarted 2026-09-13 ~22:45 local
with the clean tree; test rows seeded in the bell (one Critical, a Claude group,
YouTube HD, Signal, six "Burst" rows). Journal clean.

## REMAINING (ordered)
0. (2026-09-25) b66a2fc, the amended 2026-09-19 batch, is pushed; main is level with origin/main.
   The 2026-09-13 rounds stand: the user said "move forward with these all".
1. Sysmonitor icon centring and the notify per-section "clear" are done, verified live
   and xreviewed (tasks/completed.md 2026-09-24 section; reviews.md 2026-09-25 00:23),
   committed and pushed 2026-09-25 on the user's "go". Nothing open.
2. Parked, not planned: the six `ponytail:` markers show no symptoms; act only if one bites.

## STATE
- Branch `main`, HEAD = origin/main after the 2026-09-25 commit (icon centring + section clear).
  Working tree clean except the untracked root `todo.md` inbox (empty, on purpose).
  Must NOT be committed: `assets/masters/*.png` (gitignored), any credentials.
- 2026-09-25 scratch (session eda6e086…/scratchpad): `sysmon-valign/` (PySide6 panel
  replica `harness.py`, live `measure.py`), `notify-p2/` (popup crops), `fswatch/probe.sh`
  (prints full|normal|none for KWin's active window).
- No background work. plasmashell live with the current tree.
- Scratch dir (session-specific, may be gone):
  `/tmp/claude-1000/-home-jesuscdev-Programming-fedora-wayland-sys-monitor-widgets/62e10e0b-bf24-4a15-a731-ae0ba78cb9a8/scratchpad`
  held `twojobs.py`/`fakejob.py` (synthetic KDE jobs), `width-test.qml`,
  screenshots, pre-change copies of notify/bluetooth main.qml, fetched KDE sources
  (`appletpopup.cpp`, `jobsmodel_p.cpp`, `job_p.cpp`, `notifications.cpp`, …).
- Panel layout: notify is applet 49, `AppletOrder=3;37;35;46;28;47;43;49;45;22;48;29;30`.
  Its config in appletsrc sits under a doubled group
  `[Containments][2][Applets][49][Configuration][Configuration][General]`; that
  is where `Plasmoid.configuration` reads on this box (verified 2026-09-02).

## GOTCHAS
- Restart loop: `systemctl --user restart plasma-plasmashell && sleep 18`, then
  `journalctl --user -u plasma-plasmashell --since <time> | grep -iE 'jesuscdev\.(notify|bluetooth|transfers)|util\.js' | grep -v 'Unable to assign'`.
  Clean journal only proves the QML parsed. `console.warn` never reaches journald;
  debug by appending to a scratch file through the widget's own executable
  DataSource (`fire("printf '%s\\n' '...' >> file #" + seq)`), then restore the
  clean copy — keep a `cp` of main.qml before adding TEMP lines.
- A plasmashell restart EMPTIES notification history and job views.
- KDE unread rule: `ReadRole` is a flag only the stock toast sets; real rule is
  `!read && (updated||created) > lastRead`; `lastRead` is process-wide.
- Fedora ships `[Applications][@other] ShowInHistory=false`; `historyBlacklist()`
  drops `@other` or notify-send rows vanish.
- Plasma `AppletPopup` saves popup size on every close and then ignores implicit
  size; only `Layout.minimum*/maximum*` on `fullRepresentation` still resize it.
- Finished KDE jobs stay in the model as `JobStateStopped` until the stock
  toast calls `expire()`, which never happens under fullscreen inhibition.
- Panel is 38 logical = 57 physical px (scale 1.5). Screenshots via
  `spectacle -b -f -n -o file` work when no fullscreen window covers the panel;
  measure ink runs with PIL/numpy (see scratch scripts) — cheaper than guessing.
- Executable DataSource runs through `sh`; every command string must be unique
  (`#<seq>` suffix, monotonic — not the millisecond clock, bursts coalesce).
- Cutting a QML block with a substring search for `"    }\n"` matched an inner
  8-space brace first and left a dangling `}` once; cut by exact text or regex
  anchored at line start.
- `ls` is aliased to colorls (breaks `-R`/paths); use find/echo.
- `/route` before dispatching subagents; max two at once.
- Stop hook blocks "done" while `tasks/reviews.md` has unchecked boxes (0 now).
