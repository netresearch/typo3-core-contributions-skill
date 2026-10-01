#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
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
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  ok   $name"
    else
        echo "  FAIL $name: expected '$expected', got '$actual'"
        fail=1
    fi
    return 0
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

# `--draft` and `--ready` are one state, not two flags.
env -u GIT_TYPO3_ORG_TOKEN python3 "$SCRIPT" mr update a/b 1 --draft --ready >/dev/null 2>&1
check "mr update rejects --draft with --ready" "2" "$?"

# mr create: --label is wired into the parser and repeatable.
out="$(python3 - "$SCRIPT" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("t3o", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
args = mod.build_parser().parse_args(
    ["mr", "create", "a/b", "--source", "s", "--title", "t", "--label", "Type::Bug", "--label", "Skill:: Backend"]
)
print(args.label)
PY
)"
check "mr create collects repeated --label" "['Type::Bug', 'Skill:: Backend']" "$out"

# The command itself, with the API call replaced: the labels must reach the
# POST it sends, and report_labels() must read them back from the answer.
out="$(python3 - "$SCRIPT" 2>&1 <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("t3o", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
sent = {}
def fake_call(path, method="GET", body=None):
    sent.update(body or {})
    return {"iid": 1, "web_url": "u", "draft": True, "labels": ["Type::Bug"]}
mod.call = fake_call
args = mod.build_parser().parse_args(
    ["mr", "create", "a/b", "--source", "s", "--title", "t", "--description", "Testing",
     "--label", "Type::Bug", "--label", "Skill:: Backend"]
)
mod.cmd_mr_create(args)
print("sent=" + sent.get("labels", "-"))
PY
)"
case "$out" in
    *"sent=Type::Bug,Skill:: Backend"*) echo "  ok   mr create sends --label in its POST" ;;
    *) echo "  FAIL mr create did not send the labels: $out"; fail=1 ;;
esac
case "$out" in
    *"WARNING labels not applied: Skill:: Backend"*) echo "  ok   mr create reports a dropped label" ;;
    *) echo "  FAIL mr create did not report the dropped label: $out"; fail=1 ;;
esac
# A create without --label warns before any request. HOME is redirected so
# the token file fallback cannot find a real token and the call stops right
# after the warning.
warn_home="$(mktemp -d)"
out="$(env -u GIT_TYPO3_ORG_TOKEN HOME="$warn_home" python3 "$SCRIPT" mr create a/b \
    --source s --title t --description "Testing: none" 2>&1)"
case "$out" in
    *"WARNING no --label given"*) echo "  ok   mr create warns without --label" ;;
    *) echo "  FAIL mr create did not warn without --label: $out"; fail=1 ;;
esac
rm -rf "$warn_home"

# A pipeline command with no selector once asked for pipeline "None".
env -u GIT_TYPO3_ORG_TOKEN python3 "$SCRIPT" pipeline status a/b >/dev/null 2>&1
check "pipeline status requires a selector" "2" "$?"

# GitLab derives `draft` from the title prefix; strip_draft() is that rule.
out="$(python3 - "$SCRIPT" <<'PY'
import importlib.util, sys, time
spec = importlib.util.spec_from_file_location("t3o", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
cases = {
    "Draft: [TASK] x": "[TASK] x",
    "draft: [TASK] x": "[TASK] x",
    # no space after the colon: slicing by len("Draft: ") ate the first letter
    "Draft:[TASK] x": "[TASK] x",
    "[TASK] x": "[TASK] x",
}
print(all(mod.strip_draft(k) == v for k, v in cases.items()))
print(mod.mr_path("a/b", "7"))
print(mod.positive_int("60"))
print(mod.time_left(None) is None)
# A budget that is gone must not buy one more request. The refresh timeout
# was clamped to 1s, so every call could still run a second past the
# deadline, and the initial lookup carried no timeout at all.
print(round(mod.time_left(time.monotonic() + 5) or 0))
# mr create sends labels in the create call, or no labels key at all.
print(mod.mr_create_body("s", "develop", "t", "d", ["Type::Bug", "Skill:: Backend"]).get("labels"))
print("labels" in mod.mr_create_body("s", "develop", "t", "d", []))
try:
    mod.time_left(time.monotonic() - 1)
    print("no exit")
except SystemExit as expired:
    print("budget ran out" in str(expired))
PY
)"
check "strip_draft handles both cases and a plain title" "True" "$(echo "$out" | sed -n 1p)"
check "mr_path url-encodes the project" "/projects/a%2Fb/merge_requests/7" "$(echo "$out" | sed -n 2p)"
check "positive_int accepts a plain interval" "60" "$(echo "$out" | sed -n 3p)"
check "time_left is unbounded without a deadline" "True" "$(echo "$out" | sed -n 4p)"
check "time_left reports what is left of the budget" "5" "$(echo "$out" | sed -n 5p)"
check "time_left refuses a request past the deadline" "True" "$(echo "$out" | sed -n 8p)"
check "mr create sends the labels it was given" "Type::Bug,Skill:: Backend" "$(echo "$out" | sed -n 6p)"
check "mr create sends no labels key without --label" "False" "$(echo "$out" | sed -n 7p)"

# A redirect from the API must not carry the token to the host it names:
# urllib copies every request header to the redirect target.
out="$(GIT_TYPO3_ORG_TOKEN=test-token python3 - "$SCRIPT" <<'PY'
import http.server, importlib.util, sys, threading
spec = importlib.util.spec_from_file_location("t3o", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
seen = []
class Other(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        seen.append(self.headers.get("PRIVATE-TOKEN"))
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"{}")
    def log_message(self, *args):
        pass
other = http.server.HTTPServer(("127.0.0.1", 0), Other)
class Api(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(302)
        self.send_header("Location", f"http://127.0.0.1:{other.server_port}/x")
        self.end_headers()
    def log_message(self, *args):
        pass
api = http.server.HTTPServer(("127.0.0.1", 0), Api)
for server in (other, api):
    threading.Thread(target=server.serve_forever, daemon=True).start()
mod.API = f"http://127.0.0.1:{api.server_port}/api/v4"
try:
    mod.call("/user", timeout=5)
    print("followed")
except SystemExit as stop:
    print("HTTP 302" in str(stop))
print(seen == [])
PY
)"
check "an API redirect ends the call" "True" "$(echo "$out" | sed -n 1p)"
check "the redirect target never receives the token" "True" "$(echo "$out" | sed -n 2p)"

# An interval is seconds, and seconds are positive: -1 reached time.sleep(-1)
# as a traceback, 0 made the poll a tight loop.
for bad in "-1" "0" "x"; do
    env -u GIT_TYPO3_ORG_TOKEN python3 "$SCRIPT" pipeline wait a/b --id 1 \
        --interval "$bad" >/dev/null 2>&1
    check "pipeline wait rejects --interval $bad" "2" "$?"
done

# isdigit() accepts "²" and Arabic-Indic digits; neither is an id. Assert the
# message, not the exit code: a traceback from int("²") also exits non-zero,
# so a status-only check passes against the very bug this pins.
for bad in "²" "١٢٣" "1/../2" "" "-1"; do
    out="$(env -u GIT_TYPO3_ORG_TOKEN python3 "$SCRIPT" mr show a/b "$bad" 2>&1)"
    case "$out" in
        *"Not a numeric"*) echo "  ok   mr show refuses iid '$bad' with a message" ;;
        *) echo "  FAIL mr show on iid '$bad' did not report it: $out"; fail=1 ;;
    esac
done

# `link` builds two paths from iids, and every other subcommand passes its ids
# through numeric(). HOME points at an empty directory so that no token file
# is found: a check that got as far as a request would stop at "No token"
# instead, and fail the assertion rather than reach git.typo3.org.
empty_home="$(mktemp -d)"
for bad in "²" "1/../2" "-1"; do
    out="$(env -u GIT_TYPO3_ORG_TOKEN HOME="$empty_home" python3 "$SCRIPT" \
        link a/b "$bad" --to c/d#3 2>&1)"
    case "$out" in
        *"Not a numeric"*) echo "  ok   link refuses iid '$bad' with a message" ;;
        *) echo "  FAIL link on iid '$bad' did not report it: $out"; fail=1 ;;
    esac
done
for bad in "c/d#²" "c/d#١٢٣" "c/d#" "#3"; do
    out="$(env -u GIT_TYPO3_ORG_TOKEN HOME="$empty_home" python3 "$SCRIPT" \
        link a/b 1 --to "$bad" 2>&1)"
    case "$out" in
        *"--to must look like"*) echo "  ok   link refuses --to '$bad' with a message" ;;
        *) echo "  FAIL link on --to '$bad' did not report it: $out"; fail=1 ;;
    esac
done
rm -rf "$empty_home"

[[ "$fail" -eq 0 ]] && echo "  all checks passed"
exit "$fail"
