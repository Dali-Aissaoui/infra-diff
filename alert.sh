#!/bin/bash
set -euo pipefail

# load environment variables from .env
if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

# sends a webhook alert if drift is detected in the diff JSON
# usage: alert.sh <diff.json> <webhook_url>
# or set WEBHOOK_URL env var
# exit code: 0 = alert sent or no drift, 1 = HTTP error, 2 = usage error

usage() {
    echo "usage: $0 <diff.json>" >&2
    echo "WEBHOOK_URL environment variable must be set." >&2
}

if [ "$#" -ne 1 ]; then
    usage
    exit 2
fi

DIFF_FILE="$1"

if [ ! -f "$DIFF_FILE" ]; then
    echo "diff file not found: $DIFF_FILE" >&2
    exit 2
fi

if [ -z "${WEBHOOK_URL:-}" ]; then
    echo "WEBHOOK_URL environment variable must be set." >&2
    exit 2
fi


if jq -e 'length == 0 or (.[0].result? == "no drift detected")' "$DIFF_FILE" >/dev/null; then
    echo "no drift detected. no alert sent."
    exit 0
fi


SUMMARY=$(jq -r '[.[] | select(.diff != null) | {section, changes: (.diff | length)}] | {drift_sections: .}' "$DIFF_FILE")


HTTP_CODE=$(curl -s -o /tmp/alert_response.txt -w "%{http_code}" -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    --data-binary "@$DIFF_FILE")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo "alert sent successfully. webhook response:"
    cat /tmp/alert_response.txt
    echo "summary: $SUMMARY"
    exit 0
else
    echo "failed to send alert. HTTP code: $HTTP_CODE" >&2
    cat /tmp/alert_response.txt >&2
    exit 1
fi
