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

## Optional / parked (ask before doing)
- [ ] Codex/Claude icon animation — requires restructuring AI segment from
  RichText into separate Image elements (RichText `<img>` can't animate).
- [ ] Battery segment scroll-wheel = screen brightness (user skipped workspace
  scroll; confirm before adding any scroll gesture).
- [ ] AI segment width reservation — "1h 3m" vs "58m" reflows once a minute.
- [ ] Cap RAM icon aspect if 2.46x reads too wide at a glance.

## User-side (needs sudo / manual)
- [ ] `sudo setsebool -P selinuxuser_execheap 1` (Android emulator fix)
- [ ] Remove kmail/kontact suite (confirm package list first)
- [ ] Delete 1.8G theme backup (path lost — locate first)
- [ ] Move session files for `ccr` in widget folder:
  `mv ~/.claude/projects/-home-jesuscdev-Programming/6e5a3aab-* ~/.claude/projects/-home-jesuscdev-Programming-fedora-wayland-sys-monitor-widgets/`

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
