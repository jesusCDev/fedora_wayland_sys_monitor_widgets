#!/usr/bin/env bash
# Codex/ChatGPT rate limits from the newest ~/.codex session log.
# Codex CLI writes a rate_limits event on every API call; live polling isn't
# possible without consuming quota, so this reflects the last codex run.
# Prints exactly one JSON object; always exits 0.
set -u

DIR="$HOME/.codex/sessions"
[[ -d "$DIR" ]] || { echo '{"ok":false,"error":"no-codex"}'; exit 0; }

# Newest few session files; first one containing rate_limits wins
while IFS= read -r F; do
    LINE=$(grep '"rate_limits"' "$F" 2>/dev/null | tail -1)
    if [[ -n "$LINE" ]]; then
        echo "$LINE" | jq -c '{ok:true,
            fetched_at:(.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdate),
            plan:(.payload.rate_limits.plan_type // ""),
            primary:(.payload.rate_limits.primary),
            secondary:(.payload.rate_limits.secondary)}' 2>/dev/null && exit 0
        echo '{"ok":false,"error":"parse"}'
        exit 0
    fi
done < <(find "$DIR" -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -5 | cut -d' ' -f2-)

echo '{"ok":false,"error":"no-data"}'
exit 0
