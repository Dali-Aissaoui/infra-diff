#!/bin/bash
set -euo pipefail

# compares two snapshot JSON files and outputs categorized drift as JSON
# usage: diff.sh <snapshot1.json> <snapshot2.json>
# exit code: 0 = no drift, 1 = drift detected, 2 = error

usage() {
    echo "Usage: $0 <snapshot1.json> <snapshot2.json>" >&2
}

if [ "$#" -ne 2 ]; then
    usage
    exit 2
fi

SNAP1="$1"
SNAP2="$2"

if ! [ -f "$SNAP1" ] || ! [ -f "$SNAP2" ]; then
    echo "Both snapshot files must exist." >&2
    exit 2
fi

diff_section() {
    local section="$1"
    jq -n \
      --argfile a "$SNAP1" \
      --argfile b "$SNAP2" \
      --arg section "$section" \
      '
      def diff(a; b):
        if (a == null and b == null) then null
        elif (a == null) then {added: b}
        elif (b == null) then {removed: a}
        elif (a == b) then null
        elif ((a|type) == "array" and (b|type) == "array") then
          {added: (b - a), removed: (a - b)} | select(.added != [] or .removed != [])
        elif ((a|type) == "object" and (b|type) == "object") then
          reduce (a|keys_unsorted + b|keys_unsorted | unique[]) as $k ({};
            . + (if (a[$k] == null) then {($k): {added: b[$k]}}
                 elif (b[$k] == null) then {($k): {removed: a[$k]}}
                 elif (a[$k] != b[$k]) then {($k): {from: a[$k], to: b[$k]}}
                 else {} end)
          ) | select(length > 0)
        else {from: a, to: b}
      end;
      {
        section: $section,
        diff: diff($a[$section]; $b[$section])
      } | select(.diff != null)'


# --- compare all top-level sections ---
SECTIONS=(
  "metadata" "docker" "network" "services" "os" "users_groups" "scheduled_tasks" "integrity"
)

has_drift=0
diff_output="["
first=1
for section in "${SECTIONS[@]}"; do
    section_diff=$(diff_section "$section")
    if [ -n "$section_diff" ]; then
        has_drift=1
        if [ $first -eq 0 ]; then
            diff_output+="\n,"
        fi
        diff_output+="$section_diff"
        first=0
    fi
done
diff_output+=']'

if [ "$has_drift" -eq 1 ]; then
    echo "$diff_output" | jq '.'
    exit 1
else
    echo '{"result": "no drift detected"}'
    exit 0
fi
