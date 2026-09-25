# Completed

Finished sections moved from `tasks/todo.md` (archived 2026-09-12; oldest first, append newest at the bottom).

## Bugs
- [x] **AI status "now 100%" vs popup "23min" mismatch** — fixed 2026-08-13:
  tick dependency moved inside `claudeFmtReset`/`fmtEpochReset` so every
  countdown binding (popup rows included) re-renders each minute; panel
  exhausted branch now degrades to dim "5h …" when the countdown has expired
  (window rolled, awaiting fresh data) and dim red when data is stale.

## Improvements (ranked)
- [x] **Single aggregated sampler** — done 2026-08-13: `refreshAll()` builds one
  `sh -c` command from enabled sections (`@CPU`/`@RAM`/`@BAT`/`@TEMP`/`@NET`/
  `@DISK`/`@UP` markers), single `sampleSource` DataSource parses once and routes
  to the existing parse functions. 5 per-tick DataSources deleted; hover/popup
  on-demand sources (disk, uptime, batInfo) untouched.
- [x] **Hardware auto-detection** — done 2026-08-13: `probeHardware()` runs one
  shell probe at startup (battery/AC/backlight/kbd-LED names, CPU temp hwmon
  file incl. k10temp/zenpower, GPU temp file preferring thinkpad EC over
  amdgpu/nouveau/radeon, internal display via kscreen-doctor). Results in `hw*`
  properties, ThinkPad values as defaults. No cache — probe is milliseconds.
- [x] **Light-panel safety** — done 2026-08-13: README note under Colors
  section (defaults tuned for dark panel; override per metric on light themes).
  Theme-aware fallback palette skipped — per-metric overrides already exist.
- [x] **Workspace tooltip cap** — done 2026-08-13: tooltip shows first 4 apps
  per row, then "+N more".

## Open after the 2026-08-18 validation sweep
- [x] **Hover tooltip retest** — user confirmed working across all segments
  2026-08-23 (first plasmashell instance to actually load the fix).
- [x] **Right-edge clipping** — user confirmed no clipping 2026-08-23; Plasma's
  own Dialog clamping covers it. Revisit only if a better approach appears.
- [x] First tick after re-enabling a hidden metric is bogus — fixed 2026-08-23:
  `onShowCpuChanged`/`onShowNetChanged` reset the firstRun flags on re-enable.
- [x] Dropped-tick double-interval division — fixed 2026-08-23: NET rate now
  divides by wall-clock elapsed (`netPrevStampMs`) instead of the nominal
  interval. CPU needs nothing (dIdle/dTotal is self-normalizing).
- [x] `claude-mascot@2x.png` deleted 2026-08-23.

## Optional / parked (ask before doing)
- [x] Codex/Claude icon animation — done 2026-08-13 as attention-only blink:
  mascots swap normal/red variant every 700ms while any window sits in the red
  band (>= claudeCritThreshold, live data only). No RichText restructure needed.
  Verified live via threshold-drop test, then restored to default 85.
- [x] System/battery icon animation — done 2026-08-16 using the same shared
  700ms attention blink: CPU/GPU/RAM/disk swap their normal/red PNGs above the
  warning threshold, and an unplugged low battery swaps its glyph color. Values
  remain solid red; a low battery already on AC remains solid red without blinking.
- [x] Battery segment scroll-wheel = screen brightness — user approved and
  done 2026-08-23: wheel on either battery segment invokes powerdevil's
  Increase/Decrease Screen Brightness shortcut via qdbus (OSD + clamping for
  free), with one-notch (120-delta) accumulation so touchpads don't spawn a
  process per micro-event.
- [x] ~~AI segment width reservation~~ — user passed 2026-08-13: countdown
  width changes at most every ~10 minutes, not worth it.
- [x] RAM icon size — done 2026-08-13: wide icons (ram/gpu) now render at
  roughly equal visual area to the square ones (height scaled by
  sqrt(1.2/aspect)); RAM no longer dwarfs the row.

## Done (this round)
- [x] One-shot usage alerts (100% / reset / red-threshold) + toggles
- [x] Fable 5 allowance tracking with transcript denial detection
- [x] Burn-rate projection in popup (window-bounded)
- [x] Codex 5h staleness dim
- [x] Exhausted panel display -> red time-to-reset countdown
- [x] AC/battery display auto-switch in sysmonitor + battery hover rows
- [x] Brightened metric palette + matching icons; wide RAM/GPU icons
- [x] Workspaces: hover tooltip, panel scaling, brighter current, occupancy fix
- [x] Atomic cache writes in fetch scripts

## User-side (needs sudo / manual)
- [x] ~~SELinux execheap bool~~ — user passed 2026-08-13 (no emulator need).
- [x] ~~Remove kmail/kontact~~ — user passed 2026-08-13; verified no akonadi/
  kmail processes running and no autostart entries, so they cost nothing idle.
- [x] Delete 1.8G theme backup — done 2026-08-13: located
  `~/.local/share/theme-backup-2026-08-02` (aurorae/color-schemes/desktoptheme/
  icons/look-and-feel), confirmed with user, deleted.
- [x] ccr session move — already done in an earlier session: `6e5a3aab-*` lives
  in the widget project dir. The 3 sessions still under
  `-home-jesuscdev-Programming/` have cwd `/home/jesuscdev/Programming` — they
  belong to that project, left in place.

## New (2026-08-13 evening)
- [x] Net hover shows connection name (SSID) via nmcli, before iface/IP.
- [x] AI popup capped at 940px with Flickable + scrollbar — growing model
  lists scroll instead of clipping.

## New (2026-08-23)
- [x] `ccusageEnabled` default flipped to false — local spend (API-cost stats)
  hidden by default; most users care about session utilization, not API spend.
  Toggle already exists in Metrics config page.
- [x] **org.jesuscdev.bluetooth widget** — built 2026-08-23 per approved plan:
  panel glyph (Hack Nerd Font f294; dim=off, white=on, #4FC3F7=connected) +
  connected name/battery/+N; popup with paired list (click connect/disconnect),
  Scan button (10s discovery, found unpaired click = pair+trust+connect);
  middle-click opens kcm_bluetooth; custom hover tooltip; bluetoothctl backend,
  MACs only in commands. Symlinked + added to panel. Pending: user clicks
  through connect/scan/tooltip, then commit.

## New (2026-08-24)
- [x] Check-now dead-button fix: endpoint was fine (URL unchanged) — bursts of
  requests (2 instances x 60s poll + click spam) drew 429s, and the script's
  cache fallback returned in ~100ms with no visible change. Fixes:
  fetch-usage.sh serves cache <45s old without a network hit ("force"
  bypasses, used by the button); button now disabled 5s per check; footer
  shows the fetch error (e.g. "· rate-limited") whenever the last fetch
  failed, instead of only after 10min staleness.
- [x] Bluetooth widget: device-name Texts forced to PlainText (xreview catch —
  hostile BT names could inject rich-text markup into tooltip/popup).

## New (2026-08-25)
- [x] RAM never turned red before a thrash-freeze: `ramValue` is
  (MemTotal - MemAvailable) and MemAvailable keeps counting the file cache the
  kernel is churning through, so used% stalls high-80s (threshold 90% =
  27.7G of the 30.8G MemTotal) while the box is already unusable; no OOM/oomd
  kill in any prior boot (23G swap, swappiness 10 -> pure thrash). Fix: RAM
  sample now also reads `/proc/pressure/memory`; `ramWarning` fires on
  `some avg10 >= 10%` too (`memPressureWarn`, hardcoded). Hover RAM line
  shows swap used + pressure. Verified with parser harness (real sample +
  thrash/calm cases) and clean plasmashell reload.

## New (2026-08-29)
- [x] Hover tooltip fires when overshooting Chrome's tab strip into the panel.
  Fix: hover is now gated by pointer height in the panel — `onPositionChanged`
  + `segHoverAt()` (sysmonitor) / inline check (bluetooth); only the top 60%
  of the panel is live (`hoverLiveFrac`, mirrored for a bottom panel). Panel
  text already spans ~22-78% of a 38px panel, so a literal 3/4 cut would move
  ~1px; 0.6 leaves the lower third of the text dead. Verified with offscreen
  qmlscene self-check (scratchpad/hoverzone-test.qml) and clean plasmashell
  reload; no pointer injection available on Wayland for a live hover test.

## New (2026-09-01)
- [x] **Notify Inline widget** (`org.jesuscdev.notify`) — second notification bell next to the stock one (applet 49, right of 43 in `AppletOrder`). Reads the same history via `org.kde.notificationmanager` (`Notifications` model, `Settings` for the KCM blacklist); no D-Bus/polling. Panel: Nerd Font bell, dim/white+count/red-when-critical-unread; middle-click opens `kcm_notifications`; top-60% hover gate reused. Popup: compact rows (per-app color tag, relative time, bold summary, body 1 line → hover expands, red bar for critical, read rows dim), row click copies the plain body via `wl-copy`, chips for URLs/emails/4–8 digit codes copy just that, `×` closes a row, `Clear` = `hist.clear(ClearExpired)`, closing the popup marks all read (`lastRead = undefined`, setting). Pure helpers in `contents/ui/util.js` shared with `scratchpad/notify-test.qml` (19/19 offscreen checks; `wl-copy` round trip byte-exact). Screenshot verification blocked by a fullscreen window over the panel; journal clean after reload. Three test notifications left in history for the live check (Chrome code 482913 + URL, critical Test, Discord long body).

- [x] **Notify Inline round 2** (user feedback). (a) Empty history root-caused: Fedora's `/etc/xdg/plasmanotifyrc` ships `[Applications][@other] ShowInHistory=false`, so honoring `Settings.historyBlacklistedApplications` verbatim dropped every notification without a desktop-entry hint (notify-send, scripts, CLI). `historyBlacklist()` now keeps per-app KCM choices but drops `@other`. (b) KDE's `unreadNotificationsCount` skips non-expired rows (`if (!active && !read)`), so critical notifications (never expire) were never unread; replaced with own `recount()` over `ReadRole`/`UrgencyRole`, second model dropped. `lastRead` is process-wide (shared `NotificationsModel`) — closing either bell's popup marks both read; the stock applet also flags a notification read once its popup was shown. (c) Tooltip lists the 3 newest regardless of read state, header `None unread · N in history`. (d) `Clear` Button → dim `clear all` text link. (e) Panel glyph → PNG bell in the metric-icon style: master + prompt in `assets/masters/icon-bell*`, `contents/icons/bell{,-dim,-warn}.png` (alpha binarized at 50, PIL HSV recolours), rendered at `panelPt*1.3` like sysmonitor. Verified with a temporary file-logging timer through the widget's own DataSource (journal never showed `console.warn` from the plasmoid). The persistent toast the user saw was the stock critical popup (criticals never time out; normal ones use their `PopupTimeout=3000`).

- [x] **Notify Inline round 3.** "copied" flashed on every row — the per-row key from `model.id` collapsed to one value; flash now keys on the delegate item itself (`flashRow === row`). Ctrl+click opens: row → the notification's default action if `HasDefaultActionRole`, else its first link; chip → `xdg-open` for URLs / `mailto:` for emails (codes still copy). Bell swapped for an outline-only version (yellow / grey idle / red critical) derived from the master's silhouette (ring = mask minus 34px erosion at 8×, LANCZOS to 52), stroke ≈1.3px at the 16px panel size. Single code file changed, so no xreview this round. SELinux alert in the user's history: `systemd-logind` read on `/var/swapfile` (mislabeled swapfile).

- [x] **NET hover: network name is the headline** — connection name (SSID / NM profile) bold in NET's cyan, interface + IP dim after it; falls back to bolding the interface when NM has no profile name. SSIDs are untrusted, so the line went RichText with a new `escapeHtml()` in sysmonitor. Same block serves hover and pinned click popup.

## New (2026-09-02)
- [x] **Notify: seen() matches KDE's unread rule** — `ReadRole` is only a
  flag the stock toast sets (never under fullscreen inhibition); KDE's
  `updateCount` also treats rows older than `lastRead` as read. Own `seen()`
  now does both, so closing the popup actually dims rows and the bell.
  Verified via debug log: `nu` dropped to 0 on lastRead reset.
- [x] **Notify: Personal / System tabs** — regex `systemApps` (config,
  default seeds SELinux/abrt/Discover/KDE service notifyrc names) matched
  against app name + desktop entry + notifyrc name. Counts per tab, "clear
  all" scoped to the visible tab, popup opens on the tab that has unread.
- [x] **Notify: auto-dismiss** — `maxAgeMin` (default 60, 0 = never): 30s
  sweep closes seen rows older than that; unread rows wait to be seen. Shared
  model, so they leave the stock bell's history too. Verified live with a
  1-minute setting.
- [x] **Notify: popup sizes to content** — width follows the widest row's
  unwrapped text (300–480 content), summary wraps to 2 lines, body shows 4
  (hover 40). Chips excluded from the width hint so they wrap instead.
  Follow-up: Plasma saves the popup size on every close
  (`AppletPopup::hideEvent` → `popupWidth/popupHeight` in appletsrc) and then
  ignores implicit size for good; `Layout.minimum*/maximum*` pinned to the
  content size force the resize anyway. Offscreen check confirmed wrapped
  `Text.implicitWidth` is the unwrapped width (long row → 480, short → 300).
- [x] New kcfg keys go live after a plasmashell restart (verified) — no
  widget re-add; fallbacks dropped.


## New (2026-09-12)
- [x] **Bell + bluetooth panel icons: bigger, centred** — both compact views
  now use real items in a `Row` (bell `Image` at 1.8×panelPt, rune `Text` at
  1.5×panelPt) each `anchors.verticalCenter`ed. The inline `<img>`/glyph in a
  RichText line rode the text baseline and sat ~3px high. Measured from
  screenshots (panel finally visible): bell 18→25px ink, rune 21→28px, both
  centred at 27.5–28 vs text 27, panel 28. Sysmonitor's inline icons still sit
  at 24.5 (baseline-bottomed) — untouched, offer to centre if asked.
- [x] `onExpandedChanged` used the injected `expanded` signal parameter
  (deprecation warning in journal); now reads `root.expanded`.
- [x] TEMP debug logging removed again; "stuck" turned out to be the
  transfers widget, not bell rows (user clarified 2026-09-13).
- [x] **Transfers: finished jobs no longer linger** — KDE keeps a terminated
  job in the model as `JobStateStopped` until the stock bell's toast calls
  `expire()`, which never happens under fullscreen inhibition; while another
  job is active the widget stayed visible and showed the finished bar at 100%.
  Both delegates now `visible` only for non-Stopped jobs. Proven with two
  synthetic D-Bus job views (`scratchpad/twojobs.py`): before, A 30% + B 100%
  both drawn; after, only A. Bars stuck at 0% are jobs whose owner never
  terminates (browser downloads); the popup's cancel button kills those.
- [x] **Notify: auto-dismiss sweep removed** (`maxAgeMin` key + config row
  gone). User wants rows kept until dismissed; the sweep was built on a
  misread of "alerts aren't going away".
- [x] **Notify: log, group rules, Critical section** (2026-09-13 round) —
  (a) every inserted row appends a TSV line (time, app, desktop entry,
  notifyrc, urgency, summary, body) to the state-dir log, trimmed to 2000
  lines past 3000. (b) `groupPatterns` config (default "claude, youtube"):
  comma-separated regexes matched on app + summary; a hit folds rows from any
  app into a group named after the rule, tag shows the rule name; section is
  part of the key. Twins show their own summary when it differs. (c) Critical
  urgency rows form a red-headed top section. Proven via temp debug: Chrome
  "Claude" + notify-send "Claude finished" one group, YouTube HD its own,
  critical row alone on top, setroubleshoot in System; log file populated.
- [x] **Notify popup: twins render inside the head** (2026-09-13 fix) —
  unfolding had shown the older twins at their own chronological spots
  further down, not under the head. Now the list always folds them and an
  open head hosts a compact Repeater (`membersOf`: time + body, click copies,
  own ×). Scrollbar lane reserved only when the list overflows the 600px
  cap; row right padding 8px. × extracted to an inline `CloseButton`
  component. Proven: temp log showed 5 members with the right bodies.
- [x] **Notify popup: double-click unfolds a group** (2026-09-13) — `openGroups`
  map keyed by app+summary; members render indented under the head, head
  body shows in full while open, pill tints accent. Head × still dismisses
  the group, a member's × only itself. First click of the double still
  copies (no delay timer, by choice). Single file.
- [x] **Notify popup: duplicate folding + real close button** (2026-09-13,
  user round) — rows sharing app + summary fold into the newest one, which
  carries a "+N" pill; its × closes the whole group (`closeKey`). Row
  bindings read a `rev` counter bumped in `recount()` so lookups refresh on
  any model change (linear scans over ≤ historyLimit rows, ponytail-marked).
  × is now two drawn strokes in a 20px hit box with hover ring, 12px right
  padding on rows keeps it clear of the scrollbar lane. Single file.
- [x] **Notify popup: sections + fixed footer** (2026-09-13, user round) —
  tabs gone; System section first (few, urgent), Personal below, each with a
  dim header + unread count, an empty section hides entirely. "clear all"
  moved into a footer outside the Flickable with a count line, so it never
  scrolls away. Content width 340–520 (popup 396–576), height cap 600.
  Single file, no xreview; journal clean after reload.
- [x] **Notify popup: 20px lane for the ScrollBar** — the attached ScrollBar
  overlays the Flickable's right edge and covered "clear all"; popup is
  `popupCol.width + 56` now.

## New (2026-09-14)
- [x] **xreview round (6 findings)** — fixed: bluetooth pair chain now
  `&&`-gated; notify log 0600/0700 via `umask 077`, `flock` serialised
  append + trim, monotonic `logSeq` key, `logEnabled` toggle (default on,
  user asked); sysmonitor Claude-only tooltip items gated by `showClaude`.
  Dismissed: 100% already returns exhausted one line above; tooltip move was
  user-requested with bounded rows. Burst of 6 notify-send → 6 log lines.
  Ledger 0 open.

## Root todo.md inbox, closed 2026-09-19
- [x] to have distinct colors per program, you can use the program name to generate a color (make sure it never matches the backgorund of our current theme though, that way it's hard to see)
- [x] when i hover over the progress bar, it doesn't show any relevante data.
- [x] when our yt program is downloading content and we are moving files, we have multiple download bars. I think they should stack, and the one closes to being done takes presedent, while the others on hover show under it, or we switch to like a ring system to show progress instead of a bar to avoid squishing.
  Closed by: notify hashed per-app colours (util.js), transfers hover tooltip + lead bar with "+N" (transfers main.qml); see tasks/todo.md 2026-09-19 section for evidence.

## New (2026-09-19) — root todo.md inbox
- [x] **Distinct colour per program** (notify tags/bars): hue hashed from the
  app name in 24 steps, lightness 62% so it never nears the dark ground;
  replaces the 8-entry palette. Verified offscreen 2026-09-19 (util.js via
  qmlscene): 10 common names → 10 distinct hex colours, luminance 107–209 on
  a ~16 ground. Live reload pending with the transfers change.
- [x] **Transfers: hover shows the data** — tooltip (house pattern, top-60%
  gate) listing every active job: percent, name, speed, size, ETA, destination.
  Done 2026-09-19 by a sonnet subagent (transfers main.qml +145); qmllint
  clean, journal clean after reload. Hover itself is a user-side check.
- [x] **Transfers: one bar, precedence to the closest-to-done** — panel shows
  only the active job with the highest percentage plus a "+N" for the rest;
  the others live in the hover tooltip. Ring variant not taken (bar keeps the
  house look and the existing popup). Proven 2026-09-19 with three synthetic
  D-Bus jobs at 30/75/55%: screenshot shows one bar at 75% and "+2".

## Waiting on user (2026-09-12)
- [x] Verdict on notify popup width, icon sizes, transfers fix (2026-09-13 round)
  Implicitly accepted 2026-09-19: user said "go to commit" with everything in place.
- [x] "go" to commit the batch since 6cc571e (ask about `fable-mascot.png` and the three bell PNGs first)
  Done 2026-09-19: asked, user chose to include both; commit 6f62e6a (26 files, +2554/−500), masters not staged, not pushed.

## 2026-09-24 — push, sysmonitor icon centring, notify per-section clear

- [x] Push the 2026-09-19 batch commit to origin.
  2026-09-24 · b66a2fc · push 6cc571e..b66a2fc accepted, main level with origin/main; secret scan of added lines clean.
- [x] Sysmonitor: centre the inline panel icons on the text line (they ride ~3px high, inline `<img>` on the baseline).
  2026-09-25 · sysmonitor main.qml (uncommitted) · align="middle" on codex + metric img tags only; live screenshot 00:23: cpu/gpu/net/codex from -3/-2/-3/-3 px (sim baseline) to +0.5/+0.5/+1.0/+0.5, ram/claude/fable/battery within 0.5; text rows and applet widths unchanged; journal clean.
- [x] Notify: per-section "clear" control in each popup section header, scoped to that section's rows and group twins.
  2026-09-25 · notify main.qml (uncommitted) · live TEMP run: clearing Personal took all 3 rows incl. twin to 0 with System 2 / Critical 1 unchanged; clearing System left Critical 1 and hid its control; margin 14 puts "clear" on the × glyph ink (0 px); TEMP removed, file cmp-identical to baseline, journal clean.
- [x] UX audit (ux-designer) of the new section clear control.
  2026-09-25 · popup crops · hit box 51x30 (51x24 worst), label matches footer verb, accessible name per section, grey on red header, ~8.8:1 contrast, label/header height unchanged. Keyboard: popup has none anywhere (pre-existing), control matches footer.
- [x] Cross-review (xreview) of the combined diff; `tasks/reviews.md` section fully checked.
  2026-09-25 · reviews.md "Sysmonitor icon centring + Notify per-section clear" · gpt-6-luna, no findings.
