#!/usr/bin/env bash
# Codex/ChatGPT usage, two sources merged:
#  - wham/usage endpoint: FREE read-only, account-wide (covers other machines),
#    weekly window + plan. Throttled to one request per 5 min via cache mtime.
#  - newest ~/.codex session log: 5h window (written by codex runs incl. the
#    hourly ping timer, which also keeps the auth token refreshed).
# Prints exactly one JSON object; always exits 0. Token never in argv.
set -u

AUTH="$HOME/.codex/auth.json"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/codex-usage.json"
THROTTLE=300
[[ "${1:-}" == "force" ]] && THROTTLE=0

cache_age() { echo $(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) )); }

if [[ -r "$AUTH" ]] && { [[ ! -s "$CACHE" ]] || (( $(cache_age) > THROTTLE )); }; then
    TOKEN=$(jq -r '.tokens.access_token // empty' "$AUTH" 2>/dev/null)
    ACC=$(jq -r '.tokens.account_id // empty' "$AUTH" 2>/dev/null)
    if [[ -n "$TOKEN" ]]; then
        BODY=$(curl -sS --max-time 10 -H @- https://chatgpt.com/backend-api/wham/usage <<EOF
Authorization: Bearer $TOKEN
chatgpt-account-id: $ACC
EOF
) && echo "$BODY" | jq -e '.rate_limit' >/dev/null 2>&1 && {
            printf '%s' "$BODY" > "$CACHE"
            HIST="${XDG_CACHE_HOME:-$HOME/.cache}/codex-usage-history.tsv"
            printf '%s\t%s\n' "$(date +%s)" "$(echo "$BODY" | jq -r '.rate_limit.primary_window.used_percent // ""')" >> "$HIST"
            if (( $(wc -l < "$HIST") > 2000 )); then
                tail -n 1500 "$HIST" > "$HIST.tmp" && mv "$HIST.tmp" "$HIST"
            fi
        }
    fi
fi

WHAM=null; WHAM_AT=0
if [[ -s "$CACHE" ]]; then
    WHAM=$(cat "$CACHE")
    WHAM_AT=$(stat -c %Y "$CACHE")
fi

SESS=null
DIR="$HOME/.codex/sessions"
if [[ -d "$DIR" ]]; then
    while IFS= read -r F; do
        LINE=$(grep '"rate_limits"' "$F" 2>/dev/null | tail -1)
        if [[ -n "$LINE" ]]; then
            SESS=$(echo "$LINE" | jq -c '{fetched_at:(.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdate),
                primary:(.payload.rate_limits.primary)}' 2>/dev/null) || SESS=null
            break
        fi
    done < <(find "$DIR" -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -5 | cut -d' ' -f2-)
fi

jq -n --argjson wham "$WHAM" --argjson wham_at "$WHAM_AT" --argjson sess "$SESS" '{
    ok: (($wham != null) or ($sess != null)),
    plan: ($wham.plan_type // ""),
    weekly: (if $wham != null then {
        used_percent: ($wham.rate_limit.primary_window.used_percent // null),
        resets_at: ($wham.rate_limit.primary_window.reset_at // null),
        allowed: $wham.rate_limit.allowed,
        limit_reached: $wham.rate_limit.limit_reached,
        fetched_at: $wham_at
    } else null end),
    session5h: (if $sess != null and $sess.primary != null and ($sess.primary.window_minutes // 0) == 300 then {
        used_percent: ($sess.primary.used_percent // null),
        resets_at: ($sess.primary.resets_at // null),
        fetched_at: $sess.fetched_at
    } else null end),
    features: ([$wham.additional_rate_limits[]? | {
        name: (.limit_name // .metered_feature),
        metered_feature: (.metered_feature // null),
        used_percent: (.rate_limit.primary_window.used_percent // null),
        resets_at: (.rate_limit.primary_window.reset_at // null),
        allowed: .rate_limit.allowed,
        limit_reached: .rate_limit.limit_reached
    }])
}' 2>/dev/null || echo '{"ok":false,"error":"parse"}'
exit 0
