#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
#
# tests/verify-prerequisites.sh — exercises verify-prerequisites.sh without
# touching review.typo3.org.
#
# A stub `ssh` first in PATH stands in for the Gerrit connection,
# GIT_CONFIG_GLOBAL points git at a throw-away global config, and the
# "checkout" is an empty repository configured the way the script expects a
# TYPO3 Core clone to be. The Composer, PHP and DDEV checks only warn, so the
# result does not depend on what the machine running the tests has installed.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$(cd "$HERE/.." && pwd)/skills/typo3-core-contributions/scripts/verify-prerequisites.sh"
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
cat >"$WORK/bin/ssh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$SSH_LOG"
exit "${SSH_EXIT:-0}"
STUB
chmod +x "$WORK/bin/ssh"
export SSH_LOG="$WORK/ssh.log"

export GIT_CONFIG_GLOBAL="$WORK/gitconfig" GIT_CONFIG_NOSYSTEM=1

run() { # run <ssh exit> [dir] — prints the script's output, returns its exit code
    (cd "${2:-$WORK/checkout}" && PATH="$WORK/bin:$PATH" SSH_EXIT="$1" bash "$SCRIPT")
}

# An empty repository configured as the TYPO3 contribution guide describes.
git init -q --template= "$WORK/checkout"
git -C "$WORK/checkout" remote add origin https://github.com/typo3/typo3.git
git -C "$WORK/checkout" config branch.autosetuprebase remote
git -C "$WORK/checkout" config remote.origin.pushurl \
    ssh://jane@review.typo3.org:29418/Packages/TYPO3.CMS.git
git -C "$WORK/checkout" config remote.origin.push +refs/heads/main:refs/for/main
mkdir -p "$WORK/checkout/.git/hooks"
printf '#!/bin/sh\n' >"$WORK/checkout/.git/hooks/commit-msg"

echo "verify-prerequisites.sh"

printf '[user]\n\tname = Jane Doe\n\temail = jane@example.org\n' >"$WORK/gitconfig"

out="$(run 0 2>&1)"
check "passes in a configured checkout with a Gerrit connection" 0 "$?"
check "asks Gerrit for its version on port 29418" "29418 review.typo3.org gerrit version" \
    "$(grep -xE '29418|review.typo3.org|gerrit|version' "$SSH_LOG" | tr '\n' ' ' | sed 's/ $//')"
check "accepts a new host key but refuses a changed one" "StrictHostKeyChecking=accept-new" \
    "$(grep -x 'StrictHostKeyChecking=.*' "$SSH_LOG")"
case "$out" in
    *"Jane Doe <jane@example.org>"*) echo "  ok   names the configured identity" ;;
    *) echo "  FAIL identity not reported: $out"; fail=1 ;;
esac
case "$out" in
    *"In TYPO3 repository"*) echo "  ok   recognises the TYPO3 checkout" ;;
    *) echo "  FAIL checkout not recognised: $out"; fail=1 ;;
esac

out="$(run 255 2>&1)"
check "fails when Gerrit cannot be reached" 1 "$?"
case "$out" in
    *"Cannot connect to Gerrit"*) echo "  ok   says the Gerrit connection failed" ;;
    *) echo "  FAIL Gerrit failure not reported"; fail=1 ;;
esac

git -C "$WORK/checkout" config --unset remote.origin.pushurl
out="$(run 0 2>&1)"
check "fails without the Gerrit push URL" 1 "$?"
case "$out" in
    *"Gerrit push URL not configured"*) echo "  ok   says the push URL is missing" ;;
    *) echo "  FAIL missing push URL not reported"; fail=1 ;;
esac

# Outside a checkout the repository checks are skipped with a warning, but
# the commit-msg hook check still runs and fails.
out="$(run 0 "$WORK/cwd" 2>&1)"
check "fails outside a checkout" 1 "$?"
case "$out" in
    *"Not in a git repository"*) echo "  ok   warns outside a checkout" ;;
    *) echo "  FAIL no warning outside a checkout"; fail=1 ;;
esac

git -C "$WORK/checkout" config remote.origin.pushurl \
    ssh://jane@review.typo3.org:29418/Packages/TYPO3.CMS.git
: >"$WORK/gitconfig"
out="$(run 0 2>&1)"
check "fails without a Git identity" 1 "$?"
case "$out" in
    *"Git user not configured"*) echo "  ok   says the Git identity is missing" ;;
    *) echo "  FAIL missing identity not reported"; fail=1 ;;
esac

echo
if [ "$fail" -eq 0 ]; then
    echo "All verify-prerequisites tests passed"
else
    echo "Some verify-prerequisites tests FAILED"
fi
exit "$fail"
