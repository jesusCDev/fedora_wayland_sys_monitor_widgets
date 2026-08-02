#!/usr/bin/env bash
# Per-process GPU busy % via DRM fdinfo (two samples 0.6s apart).
# Only processes readable by the current user (i.e. your own apps).
# Output: one "name<TAB>pct%" per line, top 3.
set -u

sample() {
    awk '/^drm-engine-(gfx|render|compute|3d|video[^:]*):/ {split(FILENAME, a, "/"); s[a[3]] += $2}
         END {for (p in s) print p, s[p]}' /proc/[0-9]*/fdinfo/* 2>/dev/null | sort
}

A=$(sample)
sleep 0.6
B=$(sample)

join <(echo "$A") <(echo "$B") 2>/dev/null | while read -r pid t1 t2; do
    d=$((t2 - t1))
    [ "$d" -gt 0 ] || continue
    pct=$((d / 6000000))    # delta ns over 0.6e9 ns, times 100
    [ "$pct" -gt 100 ] && pct=100
    name=$(cat "/proc/$pid/comm" 2>/dev/null) || continue
    printf '%s\t%s\n' "$pct" "$name"
done | sort -rn | head -3 | awk -F'\t' '{printf "%s\t%s%%\n", $2, $1}'
