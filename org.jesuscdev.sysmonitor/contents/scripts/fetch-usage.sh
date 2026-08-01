#!/usr/bin/env bash
# Fetch Claude subscription usage. Prints exactly one JSON object; always exits 0.
# Token read via jq (stdout only) and passed to curl via stdin — never in argv.
set -u

CREDS="$HOME/.claude/.credentials.json"

if [[ ! -r "$CREDS" ]]; then
    echo '{"ok":false,"error":"no-credentials"}'
    exit 0
fi

TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null)
if [[ -z "$TOKEN" ]]; then
    echo '{"ok":false,"error":"no-credentials"}'
    exit 0
fi

# ponytail: beta header speculative — endpoint works without it; drop if it ever 4xxes
RESP=$(curl -sS --max-time 10 -w $'\n%{http_code}' \
    -H @- https://api.anthropic.com/api/oauth/usage <<EOF
Authorization: Bearer $TOKEN
anthropic-beta: oauth-2025-04-20
EOF
) || { echo '{"ok":false,"error":"network"}'; exit 0; }

CODE=${RESP##*$'\n'}
BODY=${RESP%$'\n'*}

case "$CODE" in
    200)
        jq -n --argjson usage "$BODY" \
            --arg plan "$(jq -r '.claudeAiOauth.subscriptionType // ""' "$CREDS")" \
            --arg tier "$(jq -r '.claudeAiOauth.rateLimitTier // ""' "$CREDS")" \
            '{ok:true, plan:$plan, tier:$tier, fetched_at:(now|floor), usage:$usage}' \
            2>/dev/null || echo '{"ok":false,"error":"network","code":200}'
        ;;
    401|403)
        echo '{"ok":false,"error":"auth"}'
        ;;
    *)
        echo "{\"ok\":false,\"error\":\"network\",\"code\":$CODE}"
        ;;
esac
exit 0
