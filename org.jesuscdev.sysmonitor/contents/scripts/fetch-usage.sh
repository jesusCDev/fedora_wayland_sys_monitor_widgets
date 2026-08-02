#!/usr/bin/env bash
# Fetch Claude subscription usage. Prints exactly one JSON object; always exits 0.
# Token read via jq (stdout only) and passed to curl via stdin — never in argv.
# Last good response cached to disk; on failure emits it with stale:true.
set -u

CREDS="$HOME/.claude/.credentials.json"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-usage.json"

fail() { # $1 = error name
    if [[ -s "$CACHE" ]]; then
        jq -n --argjson usage "$(cat "$CACHE")" \
            --arg err "$1" \
            --argjson ft "$(stat -c %Y "$CACHE")" \
            --arg plan "$(jq -r '.claudeAiOauth.subscriptionType // ""' "$CREDS" 2>/dev/null)" \
            --arg tier "$(jq -r '.claudeAiOauth.rateLimitTier // ""' "$CREDS" 2>/dev/null)" \
            '{ok:true, stale:true, error:$err, fetched_at:$ft, plan:$plan, tier:$tier, usage:$usage}' 2>/dev/null && exit 0
    fi
    echo "{\"ok\":false,\"error\":\"$1\"}"
    exit 0
}

[[ -r "$CREDS" ]] || fail "no-credentials"

TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null)
[[ -n "$TOKEN" ]] || fail "no-credentials"

# ponytail: beta header speculative — endpoint works without it; drop if it ever 4xxes
RESP=$(curl -sS --max-time 10 -w $'\n%{http_code}' \
    -H @- https://api.anthropic.com/api/oauth/usage <<EOF
Authorization: Bearer $TOKEN
anthropic-beta: oauth-2025-04-20
EOF
) || fail "network"

CODE=${RESP##*$'\n'}
BODY=${RESP%$'\n'*}

case "$CODE" in
    200)
        OUT=$(jq -n --argjson usage "$BODY" \
            --arg plan "$(jq -r '.claudeAiOauth.subscriptionType // ""' "$CREDS")" \
            --arg tier "$(jq -r '.claudeAiOauth.rateLimitTier // ""' "$CREDS")" \
            '{ok:true, plan:$plan, tier:$tier, fetched_at:(now|floor), usage:$usage}' 2>/dev/null) || fail "bad-json"
        printf '%s' "$BODY" > "$CACHE"
        # Append sample for the popup sparkline (epoch, session %, weekly %)
        HIST="${XDG_CACHE_HOME:-$HOME/.cache}/claude-usage-history.tsv"
        SP=$(echo "$BODY" | jq -r '[.limits[]? | select(.kind=="session") | .percent][0] // ""')
        WP=$(echo "$BODY" | jq -r '[.limits[]? | select(.kind=="weekly_all") | .percent][0] // ""')
        printf '%s\t%s\t%s\n' "$(date +%s)" "$SP" "$WP" >> "$HIST"
        if (( $(wc -l < "$HIST") > 2000 )); then
            tail -n 1500 "$HIST" > "$HIST.tmp" && mv "$HIST.tmp" "$HIST"
        fi
        echo "$OUT"
        ;;
    401|403) fail "auth" ;;
    429)     fail "rate-limited" ;;
    *)       fail "http-$CODE" ;;
esac
exit 0
