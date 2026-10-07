#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
#
# tests/setup-typo3-coredev.sh — exercises the TYPO3 setup step of
# setup-typo3-coredev.sh without DDEV.
#
# The script is sourced, so only setup_typo3 runs. A stub `ddev` first in PATH
# records its arguments and runs the `ddev exec` that calls `typo3 setup` with
# a local bash, where a stub `typo3` records its arguments and the
# TYPO3_SETUP_ADMIN_PASSWORD it sees: that is what the web container would
# do with the same command and stdin.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$(cd "$HERE/.." && pwd)/skills/typo3-core-contributions/scripts/setup-typo3-coredev.sh"
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

mkdir "$WORK/bin"
cat >"$WORK/bin/ddev" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >>"$DDEV_LOG"
# Only the setup command runs; the trigger-file commands name container paths.
if [ "$1" = "exec" ] && [[ "$*" == *"typo3 setup"* ]]; then
    shift
    exec bash -c "$*"
fi
STUB
cat >"$WORK/bin/typo3" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$TYPO3_LOG"
printf '%s' "${TYPO3_SETUP_ADMIN_PASSWORD-unset}" >"$TYPO3_PASSWORD_LOG"
STUB
chmod +x "$WORK/bin/ddev" "$WORK/bin/typo3"
export DDEV_LOG="$WORK/ddev.log" TYPO3_LOG="$WORK/typo3.log" TYPO3_PASSWORD_LOG="$WORK/password"

echo "setup-typo3-coredev.sh: setup_typo3"

# shellcheck disable=SC2016 # the $(...) must stay literal: it tests that it is not run
PASSWORD='s3cret pass$(touch pwned)'
(
    cd "$WORK" || exit 1
    export PATH="$WORK/bin:$PATH"
    # shellcheck source=/dev/null
    source "$SCRIPT"
    # Globals the sourced script reads.
    # shellcheck disable=SC2034
    ADMIN_PASSWORD="$PASSWORD" GIT_EMAIL="dev@example.org" PHP_VERSION="8.4"
    setup_typo3
) >"$WORK/out" 2>&1
check "setup succeeds" 0 "$?"
check "the password is on no ddev command line" 0 "$(grep -cF 's3cret' "$DDEV_LOG")"
check "the password is on no typo3 command line" 0 "$(grep -cF 's3cret' "$TYPO3_LOG")"
check "typo3 setup reads the password from its environment" "$PASSWORD" "$(cat "$WORK/password")"
check "the password is not run as shell code" "absent" "$([ -e "$WORK/pwned" ] && echo present || echo absent)"
check "typo3 runs setup" "setup" "$(head -n1 "$TYPO3_LOG")"
check "the admin email is passed as one argument" 1 "$(grep -cx -- '--admin-email=dev@example.org' "$TYPO3_LOG")"
check "the project name keeps its spaces" 1 "$(grep -cx -- '--project-name=TYPO3 Core Dev v14 PHP 8.4' "$TYPO3_LOG")"
check "no admin password option" 0 "$(grep -c -- '--admin-user-password' "$TYPO3_LOG")"

echo
if [ "$fail" -eq 0 ]; then
    echo "All setup-typo3-coredev tests passed"
else
    echo "Some setup-typo3-coredev tests FAILED"
fi
exit "$fail"
