#!/bin/bash
set -euo pipefail

if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

SNAPSHOT_DIR="${SNAPSHOT_DIR:-/infra-diff/snapshots}"
INTERVAL="${INTERVAL:-300}"
mkdir -p "$SNAPSHOT_DIR"

LAST_SNAPSHOT=""

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

while true; do
    TIMESTAMP=$(date -u +'%Y%m%dT%H%M%SZ')
    SNAPSHOT_FILE="$SNAPSHOT_DIR/snapshot_$TIMESTAMP.json"
    log "taking snapshot: $SNAPSHOT_FILE"
    ./snapshot.sh > "$SNAPSHOT_FILE"

    if [ -n "$LAST_SNAPSHOT" ]; then
        DIFF_FILE="$SNAPSHOT_DIR/diff_$TIMESTAMP.json"
        log "comparing $LAST_SNAPSHOT to $SNAPSHOT_FILE"
        ./diff.sh "$LAST_SNAPSHOT" "$SNAPSHOT_FILE" > "$DIFF_FILE" || true
        log "alerting if drift detected..."
        ./alert.sh "$DIFF_FILE"
        rm -f "$LAST_SNAPSHOT"
    fi
    LAST_SNAPSHOT="$SNAPSHOT_FILE"
    log "sleeping for $INTERVAL seconds (5 min default)"
    sleep "$INTERVAL"

done
