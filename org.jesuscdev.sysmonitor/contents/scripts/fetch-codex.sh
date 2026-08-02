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
) && echo "$BODY" | jq -e '.rate_limit' >/dev/null 2>&1 && printf '%s' "$BODY" > "$CACHE"
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
        used_percent: ($wham.rate_limit.primary_window.used_percent // 0),
        resets_at: ($wham.rate_limit.primary_window.reset_at // 0),
        fetched_at: $wham_at
    } else null end),
    session5h: (if $sess != null and $sess.primary != null and ($sess.primary.window_minutes // 0) == 300 then {
        used_percent: ($sess.primary.used_percent // 0),
        resets_at: ($sess.primary.resets_at // 0),
        fetched_at: $sess.fetched_at
    } else null end)
}' 2>/dev/null || echo '{"ok":false,"error":"parse"}'
exit 0
