#!/usr/bin/env bash
# tests/validate-commit-message.sh — exercises the commit message validator.
#
# The validator ships in every consumer of this skill and had no test: its own
# reference documents rules ("No extension names (EXT:) in subject") that the
# code did not enforce, and a patch carrying exactly that defect went out to
# review.typo3.org before anyone noticed. A rule the validator does not check
# is a rule that only exists in prose.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$(cd "$HERE/.." && pwd)/skills/typo3-core-contributions/scripts/validate-commit-message.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail=0
check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then
        echo "  ok   $1"
    else
        echo "  FAIL $1: expected exit '$2', got '$3'"
        fail=1
    fi
}

write() { # write <file> <subject>
    {
        printf '%s\n\n' "$2"
        printf 'Explains how and why the change was made.\n\n'
        printf 'Resolves: #110437\n'
        printf 'Releases: main, 14.3\n'
        printf 'Change-Id: I0123456789abcdef0123456789abcdef01234567\n'
    } > "$WORK/$1"
}

echo "validate-commit-message.py"

[ -f "$SCRIPT" ] || { echo "  FAIL validator not found at $SCRIPT"; exit 1; }

write good.txt '[BUGFIX] Mark multi checkbox groups as role="group"'
python3 "$SCRIPT" --file "$WORK/good.txt" >/dev/null 2>&1
check "accepts a well-formed subject" 0 "$?"

# EXT: in the subject is a preference, not a rule: 11 of the 500 most recently
# merged core changes keep it. So the validator warns and still exits 0.
write ext.txt '[BUGFIX] Expose EXT:form multi checkbox groups as a group'
python3 "$SCRIPT" --file "$WORK/ext.txt" >/dev/null 2>&1
check "accepts EXT: in the subject" 0 "$?"
python3 "$SCRIPT" --file "$WORK/ext.txt" 2>&1 | grep -q "EXT:"
check "warns about EXT: in the subject" 0 "$?"

# The extension key in the body is not remarked on at all.
{
    printf '[BUGFIX] Mark multi checkbox groups as a group\n\n'
    printf 'The partial in EXT:form carried the wrong role.\n\n'
    printf 'Resolves: #110437\n'
    printf 'Releases: main, 14.3\n'
    printf 'Change-Id: I0123456789abcdef0123456789abcdef01234567\n'
} > "$WORK/body.txt"
python3 "$SCRIPT" --file "$WORK/body.txt" 2>&1 | grep -q "EXT:"
check "stays silent about EXT: in the body" 1 "$?"

write nofooter.txt '[BUGFIX] Mark multi checkbox groups as a group'
sed -i '/^Resolves:/d' "$WORK/nofooter.txt"
python3 "$SCRIPT" --file "$WORK/nofooter.txt" >/dev/null 2>&1
check "rejects a missing Resolves footer" 1 "$?"

write badtype.txt '[FIX] Mark multi checkbox groups as a group'
python3 "$SCRIPT" --file "$WORK/badtype.txt" >/dev/null 2>&1
check "rejects an unknown commit type" 1 "$?"

write norel.txt '[BUGFIX] Mark multi checkbox groups as a group'
sed -i '/^Releases:/d' "$WORK/norel.txt"
python3 "$SCRIPT" --file "$WORK/norel.txt" >/dev/null 2>&1
check "rejects a missing Releases footer" 1 "$?"

echo
if [ "$fail" -eq 0 ]; then
    echo "All validate-commit-message tests passed"
else
    echo "Some validate-commit-message tests FAILED"
fi
exit "$fail"
