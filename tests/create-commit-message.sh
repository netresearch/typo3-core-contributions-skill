#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
#
# tests/create-commit-message.sh — exercises the commit message generator.
#
# The generator reads the subject and the description from stdin, so each case
# pipes them in and reads back the file written with --output. A generated
# message must pass the validator shipped next to it.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$HERE/.." && pwd)/skills/typo3-core-contributions/scripts"
SCRIPT="$SCRIPTS/create-commit-message.py"
VALIDATOR="$SCRIPTS/validate-commit-message.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/tree"

fail=0
check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then
        echo "  ok   $1"
    else
        echo "  FAIL $1: expected '$2', got '$3'"
        fail=1
    fi
}

generate() { # generate <subject> <args...> — runs inside $WORK/tree
    local subject="$1"
    shift
    (cd "$WORK/tree" && printf '%s\nExplains how and why.\n' "$subject" \
        | python3 "$SCRIPT" "$@" >"$WORK/stdout" 2>&1)
}

echo "create-commit-message.py"

[ -f "$SCRIPT" ] || { echo "  FAIL generator not found at $SCRIPT"; exit 1; }

generate 'Mark checkbox groups as a group' --type BUGFIX --issue 110437 \
    --releases 'main, 14.3' --output msg.txt
check "writes a message" 0 "$?"
check "puts the type in brackets" "[BUGFIX] Mark checkbox groups as a group" \
    "$(head -n1 "$WORK/tree/msg.txt")"
check "adds the Resolves footer" 1 "$(grep -c '^Resolves: #110437$' "$WORK/tree/msg.txt")"
check "adds the Releases footer" 1 "$(grep -c '^Releases: main, 14.3$' "$WORK/tree/msg.txt")"
python3 "$VALIDATOR" --file "$WORK/tree/msg.txt" >/dev/null 2>&1
check "the validator accepts the generated message" 0 "$?"

# A breaking change is written `[!!!][TYPE]`; the generator once wrote the
# marker inside the type brackets, which the validator rejects.
generate 'Remove deprecated syntax' --type FEATURE --breaking --issue 12345 \
    --output breaking.txt
check "writes a breaking change" 0 "$?"
check "puts [!!!] in front of the type" "[!!!][FEATURE] Remove deprecated syntax" \
    "$(head -n1 "$WORK/tree/breaking.txt")"
python3 "$VALIDATOR" --file "$WORK/tree/breaking.txt" >/dev/null 2>&1
check "the validator accepts the generated breaking change" 0 "$?"

generate 'fix the thing' --type BUGFIX --issue 1 --output lower.txt
check "rejects a subject that starts in lower case" 1 "$?"
check "writes nothing for a rejected subject" "absent" \
    "$([ -e "$WORK/tree/lower.txt" ] && echo present || echo absent)"

# --output is confined to the working directory.
for target in "../escape.txt" "$WORK/escape.txt"; do
    generate 'Mark checkbox groups as a group' --type BUGFIX --issue 1 \
        --output "$target"
    check "refuses --output $target" 1 "$?"
done
check "wrote nothing outside the working directory" "absent" \
    "$([ -e "$WORK/escape.txt" ] && echo present || echo absent)"
grep -q "must stay inside" "$WORK/stdout"
check "names the reason for the refusal" 0 "$?"

echo
if [ "$fail" -eq 0 ]; then
    echo "All create-commit-message tests passed"
else
    echo "Some create-commit-message tests FAILED"
fi
exit "$fail"
