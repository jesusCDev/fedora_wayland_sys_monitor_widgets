#!/usr/bin/env bash
# Fetch Claude subscription usage. Prints exactly one JSON object; always exits 0.
# Token read via jq (stdout only) and passed to curl via stdin — never in argv.
# Last good response cached to disk; on failure emits it with stale:true.
set -u

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CREDS="$CLAUDE_DIR/.credentials.json"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-usage.json"
FABLE_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-fable-access-state.json"

FABLE_LAST_SCAN=0
FABLE_EVENT_EPOCH=0
FABLE_RESET_AT=""
FABLE_RESET_EPOCH=0
FABLE_STATE_CLAUDE_DIR=""

load_fable_state() {
    if [[ -s "$FABLE_STATE" ]]; then
        FABLE_LAST_SCAN=$(jq -r '.last_scan // 0' "$FABLE_STATE" 2>/dev/null)
        FABLE_EVENT_EPOCH=$(jq -r '.event_epoch // 0' "$FABLE_STATE" 2>/dev/null)
        FABLE_RESET_AT=$(jq -r '.reset_at // ""' "$FABLE_STATE" 2>/dev/null)
        FABLE_RESET_EPOCH=$(jq -r '.reset_epoch // 0' "$FABLE_STATE" 2>/dev/null)
        FABLE_STATE_CLAUDE_DIR=$(jq -r '.claude_dir // ""' "$FABLE_STATE" 2>/dev/null)
    fi
    [[ "$FABLE_LAST_SCAN" =~ ^[0-9]+$ ]] || FABLE_LAST_SCAN=0
    [[ "$FABLE_EVENT_EPOCH" =~ ^[0-9]+$ ]] || FABLE_EVENT_EPOCH=0
    [[ "$FABLE_RESET_EPOCH" =~ ^[0-9]+$ ]] || FABLE_RESET_EPOCH=0
    if [[ "$FABLE_STATE_CLAUDE_DIR" != "$CLAUDE_DIR" ]]; then
        FABLE_LAST_SCAN=0
        FABLE_EVENT_EPOCH=0
        FABLE_RESET_AT=""
        FABLE_RESET_EPOCH=0
    fi
}

save_fable_state() {
    local tmp="${FABLE_STATE}.tmp.$$"
    mkdir -p "${FABLE_STATE%/*}" 2>/dev/null || return
    (
        umask 077
        jq -cn --arg claude_dir "$CLAUDE_DIR" \
            --argjson last_scan "$FABLE_LAST_SCAN" \
            --argjson event_epoch "$FABLE_EVENT_EPOCH" \
            --arg reset_at "$FABLE_RESET_AT" \
            --argjson reset_epoch "$FABLE_RESET_EPOCH" \
            '{claude_dir:$claude_dir,last_scan:$last_scan,event_epoch:$event_epoch,
                reset_at:$reset_at,reset_epoch:$reset_epoch}' \
            > "$tmp" && mv "$tmp" "$FABLE_STATE"
    ) 2>/dev/null
}

scan_fable_denials() {
    local projects="$CLAUDE_DIR/projects"
    local latest found_at found_epoch
    [[ -d "$projects" ]] || return

    if (( FABLE_LAST_SCAN > 0 )); then
        # A transcript can be very large and is appended in place. New denial
        # events are at its tail, so bound recurring reads while the initial
        # eight-day scan below remains exhaustive.
        latest=$({
                while IFS= read -r -d '' file; do
                    tail -c 16777216 -- "$file" 2>/dev/null
                    printf '\n'
                done < <(find "$projects" -type f -name '*.jsonl' \
                    -newermt "@$FABLE_LAST_SCAN" -print0 2>/dev/null)
            } | grep -hF 'model_consent_fallback' 2>/dev/null \
            | jq -Rr 'fromjson?
                | select(.type == "system" and .subtype == "model_consent_fallback")
                | select(((.originalModel // "") | ascii_downcase | contains("fable"))
                    and ((.content // "") | ascii_downcase | contains("requires usage credits")))
                | [(.timestamp // ""),
                    (((.timestamp // "") | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601?) // 0)]
                    | @tsv' 2>/dev/null \
            | sort -t $'\t' -k2,2nr | head -1)
    else
        latest=$(find "$projects" -type f -name '*.jsonl' -mtime -8 -print0 2>/dev/null \
            | xargs -0 -r grep -hF 'model_consent_fallback' 2>/dev/null \
            | jq -Rr 'fromjson?
                | select(.type == "system" and .subtype == "model_consent_fallback")
                | select(((.originalModel // "") | ascii_downcase | contains("fable"))
                    and ((.content // "") | ascii_downcase | contains("requires usage credits")))
                | [(.timestamp // ""),
                    (((.timestamp // "") | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601?) // 0)]
                    | @tsv' 2>/dev/null \
            | sort -t $'\t' -k2,2nr | head -1)
    fi

    if [[ -n "$latest" ]]; then
        IFS=$'\t' read -r found_at found_epoch <<< "$latest"
        if [[ "$found_epoch" == "0" && -n "$found_at" ]]; then
            found_epoch=$(date -d "$found_at" +%s 2>/dev/null || echo 0)
        fi
        if [[ "$found_epoch" =~ ^[0-9]+$ ]] && (( found_epoch > FABLE_EVENT_EPOCH )); then
            FABLE_EVENT_EPOCH="$found_epoch"
        fi
    fi
}

set_fable_reset_from_usage() {
    local usage="$1" new_reset new_epoch
    new_reset=$(jq -r '
        . as $usage
        | [.limits[]? | select(.kind == "weekly_scoped")
            | select(((.scope.model.display_name // "") | ascii_downcase | contains("fable")))
            | select((.resets_at // "") != "")] as $scoped
        | (($scoped | map(select(.is_active == true)) | first)
            // ($scoped | sort_by(.percent // 0) | last)
            // ([.limits[]? | select(.kind == "weekly_all")
                    | select((.resets_at // "") != "")] | first)
            // {})
        | .resets_at // $usage.seven_day.resets_at // empty' <<< "$usage" 2>/dev/null)
    # A partial/legacy cached payload should not erase a reset that was already
    # correlated with the local denial event.
    [[ -n "$new_reset" ]] || return
    new_epoch=$(date -d "$new_reset" +%s 2>/dev/null || echo 0)
    [[ "$new_epoch" =~ ^[0-9]+$ ]] && (( new_epoch > 0 )) || return
    FABLE_RESET_AT="$new_reset"
    FABLE_RESET_EPOCH="$new_epoch"
}

fable_state_active() {
    local now window_start
    now=$(date +%s)
    window_start=$(( FABLE_RESET_EPOCH - 604800 ))
    (( FABLE_RESET_EPOCH > now
        && FABLE_EVENT_EPOCH >= window_start
        && FABLE_EVENT_EPOCH < FABLE_RESET_EPOCH ))
}

fable_access_for_usage() {
    local usage="$1" now active=false
    now=$(date +%s)
    load_fable_state
    set_fable_reset_from_usage "$usage"

    if ! fable_state_active; then
        scan_fable_denials
        fable_state_active && active=true
    else
        active=true
    fi

    # Keep a two-second overlap so a transcript append racing this scan is
    # reconsidered next time. Once exhausted, advancing the checkpoint avoids
    # rescanning active Claude transcripts until the weekly window changes.
    FABLE_LAST_SCAN=$(( now > 2 ? now - 2 : 0 ))
    save_fable_state

    if [[ "$active" == true ]]; then
        jq -cn --arg resets_at "$FABLE_RESET_AT" \
            '{exhausted:true,reason:"usage_credits_required",
                source:"claude_code_model_consent_fallback",
                resets_at:$resets_at}'
    else
        jq -cn --arg resets_at "$FABLE_RESET_AT" '{exhausted:false,resets_at:$resets_at}'
    fi
}

fable_access_from_state() {
    load_fable_state
    if fable_state_active; then
        jq -cn --arg resets_at "$FABLE_RESET_AT" \
            '{exhausted:true,reason:"usage_credits_required",
                source:"claude_code_model_consent_fallback",resets_at:$resets_at}'
    else
        jq -cn --arg resets_at "$FABLE_RESET_AT" '{exhausted:false,resets_at:$resets_at}'
    fi
}

fail() { # $1 = error name
    if [[ -s "$CACHE" ]]; then
        local usage access
        if usage=$(jq -c . "$CACHE" 2>/dev/null); then
            access=$(fable_access_for_usage "$usage") || access='{"exhausted":false}'
            jq -n --argjson usage "$usage" \
                --argjson fable_access "$access" \
                --arg err "$1" \
                --argjson ft "$(stat -c %Y "$CACHE")" \
                --arg plan "$(jq -r '.claudeAiOauth.subscriptionType // ""' "$CREDS" 2>/dev/null)" \
                --arg tier "$(jq -r '.claudeAiOauth.rateLimitTier // ""' "$CREDS" 2>/dev/null)" \
                '{ok:true, stale:true, error:$err, fetched_at:$ft, plan:$plan, tier:$tier,
                    fable_access:$fable_access, usage:$usage}' 2>/dev/null && exit 0
        fi
    fi
    # Keep a previously correlated denial visible even if the raw usage cache
    # is unavailable. The stored reset bounds it, so it cannot survive forever.
    local state_access
    state_access=$(fable_access_from_state) || state_access='{"exhausted":false}'
    if jq -e '.exhausted == true' <<< "$state_access" >/dev/null 2>&1; then
        jq -n --argjson fable_access "$state_access" \
            --arg err "$1" \
            --arg plan "$(jq -r '.claudeAiOauth.subscriptionType // ""' "$CREDS" 2>/dev/null)" \
            --arg tier "$(jq -r '.claudeAiOauth.rateLimitTier // ""' "$CREDS" 2>/dev/null)" \
            '{ok:true,stale:true,error:$err,fetched_at:0,plan:$plan,tier:$tier,
                fable_access:$fable_access,usage:{}}' 2>/dev/null && exit 0
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
        FABLE_ACCESS=$(fable_access_for_usage "$BODY") || FABLE_ACCESS='{"exhausted":false}'
        OUT=$(jq -n --argjson usage "$BODY" \
            --argjson fable_access "$FABLE_ACCESS" \
            --arg plan "$(jq -r '.claudeAiOauth.subscriptionType // ""' "$CREDS")" \
            --arg tier "$(jq -r '.claudeAiOauth.rateLimitTier // ""' "$CREDS")" \
            '{ok:true, plan:$plan, tier:$tier, fetched_at:(now|floor),
                fable_access:$fable_access, usage:$usage}' 2>/dev/null) || fail "bad-json"
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
