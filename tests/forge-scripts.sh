#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
#
# tests/forge-scripts.sh — exercises create-forge-issue.sh and
# query-forge-metadata.sh without touching forge.typo3.org.
#
# A stub `curl` first in PATH records its arguments and answers like Redmine,
# so the tests read the request the scripts would send. create-forge-issue.sh
# is interactive and reads the description up to Ctrl+D, so it runs under
# `script`, which gives it a terminal: the answers after the Ctrl+D reach the
# later prompts, as they do for a person at a keyboard.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$HERE/.." && pwd)/skills/typo3-core-contributions/scripts"
CREATE="$SCRIPTS/create-forge-issue.sh"
QUERY="$SCRIPTS/query-forge-metadata.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail=0
check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then
        echo "  ok   $1"
    else
        echo "  FAIL $1: expected '$2', got '$3'"
        fail=1
    fi
}

mkdir "$WORK/bin" "$WORK/cwd"
cat >"$WORK/bin/curl" <<'STUB'
#!/usr/bin/env bash
# Records one argument per line and prints the canned response.
printf '%s\n' "$@" >"$CURL_LOG"
cat "$CURL_RESPONSE"
STUB
chmod +x "$WORK/bin/curl"
export CURL_LOG="$WORK/curl.log" CURL_RESPONSE="$WORK/response.json"
STUB_PATH="$WORK/bin:$PATH"

# payload <jq filter> — reads the JSON body the stub received after -d
payload() {
    awk 'found { print } $0 == "-d" { found = 1 }' "$CURL_LOG" \
        | sed '$d' | jq -r "$1"
}

create() { # create <keystrokes> — runs create-forge-issue.sh on a terminal
    rm -f "$CURL_LOG"
    printf '%b' "$1" | (cd "$WORK/cwd" && PATH="$STUB_PATH" FORGE_API_KEY=dummy-key \
        script -qec "bash '$CREATE'" /dev/null) >"$WORK/out" 2>&1
}

command -v script >/dev/null || { echo "  FAIL 'script' (util-linux) is required"; exit 1; }
command -v jq >/dev/null || { echo "  FAIL jq is required"; exit 1; }

echo "create-forge-issue.sh"

env -u FORGE_API_KEY PATH="$STUB_PATH" bash "$CREATE" </dev/null >"$WORK/out" 2>&1
check "exits 1 without FORGE_API_KEY" 1 "$?"
check "sends nothing without FORGE_API_KEY" "absent" \
    "$([ -e "$CURL_LOG" ] && echo present || echo absent)"

echo '{"issue":{"id":4242}}' >"$CURL_RESPONSE"
# Subject, two description lines, Ctrl+D, then: Feature, Must have, TYPO3 14,
# Frontend, two tags, confirm.
create 'Fix the thing\nLine one\nLine two\n\x042\n1\n14\n4\nperf, ui\ny\n'
check "creates an issue" 0 "$?"
check "posts to the Forge issues endpoint" 1 "$(grep -cx 'https://forge.typo3.org/issues.json' "$CURL_LOG")"
check "sends the key as a header" 1 "$(grep -cx 'X-Redmine-API-Key: dummy-key' "$CURL_LOG")"
check "subject" "Fix the thing" "$(payload .issue.subject)"
check "multi-line description" "Line one
Line two" "$(payload .issue.description)"
check "project" "typo3cms-core" "$(payload .issue.project_id)"
check "tracker 2 is Feature" "2" "$(payload .issue.tracker_id)"
check "priority 1 is Must have" "3" "$(payload .issue.priority_id)"
check "category 4 is Frontend" "977" "$(payload .issue.category_id)"
check "TYPO3 version field" "14" "$(payload '.issue.custom_fields[] | select(.id == 4) | .value')"
check "tags field" "perf, ui" "$(payload '.issue.custom_fields[] | select(.id == 3) | .value')"
grep -q "Issue #: 4242" "$WORK/out"
check "prints the new issue number" 0 "$?"

# Every prompt left at its default, no tags: Bug, Should have, 13, Misc.
create 'Fix the thing\nOnly line\n\x04\n\n\n\n\n\n'
check "creates an issue with the defaults" 0 "$?"
check "default tracker is Bug" "1" "$(payload .issue.tracker_id)"
check "default priority is Should have" "4" "$(payload .issue.priority_id)"
check "default category is Miscellaneous" "975" "$(payload .issue.category_id)"
check "default TYPO3 version" "13" "$(payload '.issue.custom_fields[] | select(.id == 4) | .value')"
check "no tags field without tags" "0" "$(payload '[.issue.custom_fields[] | select(.id == 3)] | length')"

create 'Fix the thing\nOnly line\n\x04\n\n\n\n\nn\n'
check "a declined confirmation exits 0" 0 "$?"
check "a declined confirmation sends nothing" "absent" \
    "$([ -e "$CURL_LOG" ] && echo present || echo absent)"

create 'Fix the thing\nOnly line\n\x047\n'
check "an unknown tracker choice exits 1" 1 "$?"

echo '{"errors":["Subject cannot be blank"]}' >"$CURL_RESPONSE"
create 'Fix the thing\nOnly line\n\x04\n\n\n\n\n\n'
check "a Redmine error exits 1" 1 "$?"
grep -q "Subject cannot be blank" "$WORK/out"
check "prints the Redmine error" 0 "$?"

echo "query-forge-metadata.sh"

cat >"$CURL_RESPONSE" <<'JSON'
{"project":{"trackers":[{"id":1,"name":"Bug"},{"id":2,"name":"Feature"}],
 "issue_categories":[{"id":971,"name":"Backend API"},{"id":975,"name":"Miscellaneous"}]}}
JSON

rm -f "$CURL_LOG"
env -u FORGE_API_KEY PATH="$STUB_PATH" bash "$QUERY" >/dev/null 2>&1
check "exits 1 without FORGE_API_KEY" 1 "$?"
check "sends nothing without FORGE_API_KEY" "absent" \
    "$([ -e "$CURL_LOG" ] && echo present || echo absent)"

out="$(cd "$WORK/cwd" && PATH="$STUB_PATH" FORGE_API_KEY=dummy-key bash "$QUERY" trackers 2>&1)"
check "trackers exits 0" 0 "$?"
check "reads the core project" 1 "$(grep -cx 'https://forge.typo3.org/projects/typo3cms-core.json' "$CURL_LOG")"
case "$out" in
    *"2    Feature"*) echo "  ok   lists the trackers" ;;
    *) echo "  FAIL trackers not listed: $out"; fail=1 ;;
esac
case "$out" in
    *"Backend API"*) echo "  FAIL trackers also lists categories"; fail=1 ;;
    *) echo "  ok   trackers lists no categories" ;;
esac

out="$(cd "$WORK/cwd" && PATH="$STUB_PATH" FORGE_API_KEY=dummy-key bash "$QUERY" all 2>&1)"
case "$out" in
    *"971    Backend API"*) echo "  ok   all lists the categories" ;;
    *) echo "  FAIL categories not listed: $out"; fail=1 ;;
esac
case "$out" in
    *"-H \"X-Redmine-API-Key: \$FORGE_API_KEY\""*) echo "  ok   the example keeps \$FORGE_API_KEY unexpanded" ;;
    *) echo "  FAIL the example does not show \$FORGE_API_KEY verbatim"; fail=1 ;;
esac
case "$out" in
    *dummy-key*) echo "  FAIL the output contains the key"; fail=1 ;;
    *) echo "  ok   the output does not contain the key" ;;
esac

(cd "$WORK/cwd" && PATH="$STUB_PATH" FORGE_API_KEY=dummy-key bash "$QUERY" categories --save >/dev/null 2>&1)
saved="$(find "$WORK/cwd" -name 'forge-metadata-*.json' | head -n1)"
check "--save writes the response into the working directory" "Bug" \
    "$([ -n "$saved" ] && jq -r '.project.trackers[0].name' "$saved")"

echo '{"errors":["Not authorized"]}' >"$CURL_RESPONSE"
(cd "$WORK/cwd" && PATH="$STUB_PATH" FORGE_API_KEY=dummy-key bash "$QUERY" all >"$WORK/out" 2>&1)
check "a Redmine error exits 1" 1 "$?"

echo
if [ "$fail" -eq 0 ]; then
    echo "All Forge script tests passed"
else
    echo "Some Forge script tests FAILED"
fi
exit "$fail"
