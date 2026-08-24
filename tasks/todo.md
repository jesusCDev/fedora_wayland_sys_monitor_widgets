# Widget TODO

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
- [ ] First tick after re-enabling a hidden metric is bogus: `netFirstRun` /
  `cpuFirstRun` stay false across the off period, so the delta spans the whole
  gap. Pre-existing, predates the aggregation refactor.
- [ ] A sample still in flight when the tick timer fires is dropped, and the
  next one covers two intervals but is divided by one. Unverified at runtime.
- [ ] `claude-mascot@2x.png` is 26x26 (half the 52x52 base, misnamed) and
  referenced by nothing — delete it.

## Optional / parked (ask before doing)
- [x] Codex/Claude icon animation — done 2026-08-13 as attention-only blink:
  mascots swap normal/red variant every 700ms while any window sits in the red
  band (>= claudeCritThreshold, live data only). No RichText restructure needed.
  Verified live via threshold-drop test, then restored to default 85.
- [x] System/battery icon animation — done 2026-08-16 using the same shared
  700ms attention blink: CPU/GPU/RAM/disk swap their normal/red PNGs above the
  warning threshold, and an unplugged low battery swaps its glyph color. Values
  remain solid red; a low battery already on AC remains solid red without blinking.
- [ ] Battery segment scroll-wheel = screen brightness (user skipped workspace
  scroll; confirm before adding any scroll gesture).
- [x] ~~AI segment width reservation~~ — user passed 2026-08-13: countdown
  width changes at most every ~10 minutes, not worth it.
- [x] RAM icon size — done 2026-08-13: wide icons (ram/gpu) now render at
  roughly equal visual area to the square ones (height scaled by
  sqrt(1.2/aspect)); RAM no longer dwarfs the row.

## New (2026-08-13 evening)
- [x] Net hover shows connection name (SSID) via nmcli, before iface/IP.
- [x] AI popup capped at 940px with Flickable + scrollbar — growing model
  lists scroll instead of clipping.

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
