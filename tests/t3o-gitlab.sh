#!/usr/bin/env bash
# tests/t3o-gitlab.sh — exercises t3o-gitlab.py without touching the network.
#
# The script grew merge-request updates and pipeline waiting because a session
# hand-rolled those as curl about sixty times, each call re-inlining the token.
# A wrapper nobody tests is a wrapper that silently stops matching the API it
# wraps, so the offline surface — argument parsing, the draft-prefix rule and
# the "nothing to update" guard — is pinned here.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$(cd "$HERE/.." && pwd)/skills/typo3-core-contributions/scripts/t3o-gitlab.py"

fail=0
check() { # check <name> <expected> <actual>
    if [[ "$2" == "$3" ]]; then
        echo "  ok   $1"
    else
        echo "  FAIL $1: expected '$2', got '$3'"
        fail=1
    fi
}

echo "t3o-gitlab.py"

[[ -f "$SCRIPT" ]] || { echo "  FAIL script not found at $SCRIPT"; exit 1; }

# Parsing must not need a token: an argument mistake should not depend on
# whether a PAT happens to be present.
out="$(env -u GIT_TYPO3_ORG_TOKEN python3 "$SCRIPT" --help 2>&1)"
for sub in "mr" "pipeline" "issue" "note" "link" "probe" "access"; do
    case "$out" in
        *"$sub"*) echo "  ok   --help lists $sub" ;;
        *) echo "  FAIL --help does not list $sub"; fail=1 ;;
    esac
done

out="$(python3 "$SCRIPT" mr --help 2>&1)"
for sub in "create" "update" "show"; do
    case "$out" in
        *"$sub"*) echo "  ok   mr --help lists $sub" ;;
        *) echo "  FAIL mr --help does not list $sub"; fail=1 ;;
    esac
done

# An update with no field is a user error, caught before any request.
env -u GIT_TYPO3_ORG_TOKEN python3 "$SCRIPT" mr update a/b 1 >/dev/null 2>&1
check "mr update without a field exits non-zero" "1" "$?"

out="$(env -u GIT_TYPO3_ORG_TOKEN python3 "$SCRIPT" mr update a/b 1 2>&1)"
case "$out" in
    *"Nothing to update"*) echo "  ok   mr update names what to pass" ;;
    *) echo "  FAIL mr update message unhelpful: $out"; fail=1 ;;
esac

# GitLab derives `draft` from the title prefix; strip_draft() is that rule.
out="$(python3 - "$SCRIPT" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("t3o", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
cases = {
    "Draft: [TASK] x": "[TASK] x",
    "draft: [TASK] x": "[TASK] x",
    "[TASK] x": "[TASK] x",
}
print(all(mod.strip_draft(k) == v for k, v in cases.items()))
print(mod.mr_path("a/b", "7"))
PY
)"
check "strip_draft handles both cases and a plain title" "True" "$(echo "$out" | sed -n 1p)"
check "mr_path url-encodes the project" "/projects/a%2Fb/merge_requests/7" "$(echo "$out" | sed -n 2p)"

[[ "$fail" -eq 0 ]] && echo "  all checks passed"
exit "$fail"
