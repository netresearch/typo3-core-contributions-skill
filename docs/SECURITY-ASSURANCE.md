<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Security assurance case — typo3-core-contributions-skill

This document states what a user can expect from this repository in terms of security, and argues why that expectation holds. Every claim names the file or setting that implements it. Reporting a vulnerability: see the [security policy](https://github.com/netresearch/.github/blob/main/SECURITY.md). Components: [ARCHITECTURE.md](ARCHITECTURE.md).

## What the repository ships

| Part | Files | Runs where |
| --- | --- | --- |
| Skill instructions for an AI agent | `skills/typo3-core-contributions/SKILL.md`, `skills/typo3-core-contributions/references/*.md` | Read by the agent as instructions; not executed. |
| Helper scripts | `skills/typo3-core-contributions/scripts/*.py`, `skills/typo3-core-contributions/scripts/*.sh` | On the contributor's machine, started by the contributor or by the agent, with the contributor's user rights and credentials. |
| Commit message template | `assets/commit-template.txt` | Installed by the contributor as a Git commit template; plain text. |
| Package metadata | `composer.json`, `plugin.json`, `.claude-plugin/plugin.json` | Read by Composer and by Claude Code when the skill is installed. |
| Repository tooling | `.github/workflows/*.yml`, `tests/*.sh`, the root `scripts/verify-harness.sh`, `Build/`, `.pre-commit-config.yaml`, `evals/evals.json` | In this repository's CI and on contributors' machines. |

The scripts talk to three services of the TYPO3 project: `forge.typo3.org` (Redmine, `create-forge-issue.sh`, `query-forge-metadata.sh`), `git.typo3.org` (GitLab, `t3o-gitlab.py`) and `review.typo3.org` (Gerrit SSH, `verify-prerequisites.sh`, `setup-typo3-coredev.sh`). The repository runs no server and stores no data; the scripts keep no state beyond the files and Git configuration they are asked to write.

In the tables below, `scripts/<name>` stands for `skills/typo3-core-contributions/scripts/<name>`.

## Security requirements

1. A credential the user gives a script is sent only to the service it belongs to.
2. A value the user or a remote service supplies cannot change which API endpoint a script calls or which local file it opens beyond what the user asked for.
3. A script does not write outside the place the user named, and asks before it deletes or publishes.
4. A change reaches `main` through a pull request with signed, signed-off commits that passes the required checks.
5. Nothing committed to this repository contains a secret.
6. A release carries the version that `.claude-plugin/plugin.json` states, and its archives can be verified against the build that produced them.

## Actors and trust boundaries

- **Contributor and agent.** The agent reads `SKILL.md` and the references and runs the scripts with the tools the contributor has given it. `SKILL.md` declares no `allowed-tools`. What the agent runs, and with which arguments, is decided by the agent and the contributor, not by this repository. The scripts trust their arguments as the contributor's intent and validate them only where a value becomes part of a URL path or a file path.
- **Credentials.** `t3o-gitlab.py` reads a git.typo3.org personal access token from `GIT_TYPO3_ORG_TOKEN`, else from `~/.secrets/git.typo3.org` (`token()`). The Forge scripts read `FORGE_API_KEY` from the environment and stop when it is empty. The Gerrit checks use the contributor's SSH setup. No script writes a credential to a file or prints it.
- **TYPO3 services.** Responses from Forge, git.typo3.org and Gerrit are remote input. `t3o-gitlab.py` passes ids it reads from a response through `numeric()` before it puts them into a path, and prints fields rather than executing anything from them.
- **Contributors to this repository.** Changes reach `main` through pull requests, checked by the workflows in `.github/workflows/`. The pre-commit hooks in `.pre-commit-config.yaml` run the same linters locally.
- **CI.** Workflows run on GitHub-hosted runners with `permissions: {}` at the top level; each job grants the scopes its reusable needs. The two `pull_request_target` callers (`auto-merge-deps.yml`, `labeler.yml`) call reusables that merge or label without checking out pull request code, as their header comments state.
- **Dependency bot.** Renovate (`renovate.json`, preset `github>netresearch/renovate-config`) opens pull requests that bump the pinned `rev:` of the pre-commit hooks; `auto-merge-deps.yml` merges dependency pull requests once the required checks pass.

## Threats and countermeasures

| Threat | Countermeasure | Evidence |
| --- | --- | --- |
| The git.typo3.org token is sent to another host | `call()` is the only function that adds the `PRIVATE-TOKEN` header. It builds the URL from the fixed `https://git.typo3.org/api/v4` base and refuses a path that does not start with `/` or contains `://`. `probe`, which fetches any URL, sends no token | `scripts/t3o-gitlab.py` (`call()`, `fetch()`) |
| An id carries `../` or another path segment and addresses a different API endpoint (CWE-22, CWE-20) | Every iid or id put into a path goes through `numeric()`, which accepts ASCII decimal digits only and returns an `int`; project paths are percent-encoded with `quote(safe="")` | `scripts/t3o-gitlab.py` (`numeric()`, `encoded()`), `tests/t3o-gitlab.sh` |
| A `file://` URL makes urllib read a local file (CWE-73) | `https_request()` refuses any scheme other than `http` and `https`; `open_checked()` is the only call that opens a request | `scripts/t3o-gitlab.py` |
| A request hangs and a wait never ends (CWE-400) | `pipeline wait` has a `--timeout` budget; every request inside it carries the remaining time as its socket timeout; `--interval` and `--timeout` must be positive integers | `scripts/t3o-gitlab.py` (`time_left()`, `positive_int()`), `tests/t3o-gitlab.sh` |
| `--output` writes a commit message outside the checkout (CWE-22) | `resolve_output_file()` resolves the path against the working directory and refuses anything outside it | `scripts/create-commit-message.py`, `tests/create-commit-message.sh` |
| `--file` points the validator at a device or directory | `resolve_input_file()` accepts only an existing regular file | `scripts/validate-commit-message.py` |
| Command injection through a message or path (CWE-78) | The Python scripts start no shell: the validator runs `git log` through `subprocess.run` with an argument list. In the shell scripts, ShellCheck, which reports unquoted expansions, passes at severity style | `scripts/validate-commit-message.py`, `scripts/*.sh` |
| Issue text changes the structure of the Forge request (CWE-74) | `create-forge-issue.sh` builds the JSON body with `jq --arg`, which encodes subject, description, version and tags as strings | `scripts/create-forge-issue.sh`, `tests/forge-scripts.sh` |
| The Forge key is sent to another host | Both Forge scripts send `X-Redmine-API-Key` only to the fixed `https://forge.typo3.org` URLs in the script | `scripts/create-forge-issue.sh`, `scripts/query-forge-metadata.sh`, `tests/forge-scripts.sh` |
| An issue or merge request is created by mistake | `create-forge-issue.sh` shows a summary and asks before it sends; `t3o-gitlab.py mr create` opens a draft by default and refuses `main` as target | `scripts/create-forge-issue.sh`, `scripts/t3o-gitlab.py` (`cmd_mr_create()`) |
| A change to the scripts, skill or CI is merged without its checks | Branch protection of `main` requires the status checks Skill Validation, Eval Validation, Composer Audit, SAST (Opengrep), Secret Scanning (Betterleaks), `Analyze (actions)`, `Analyze (python)` and DCO, up to date with `main`, signed commits and resolved conversations, and blocks force pushes and branch deletion (repository settings, read 2026-09-30) | `.github/workflows/lint.yml`, `.github/workflows/eval-validate.yml`, `.github/workflows/security.yml` |
| A coding weakness in the Python scripts | CodeQL default setup analyses Python and GitHub Actions with the extended query suite (`Analyze (python)`, `Analyze (actions)`, required); Opengrep (`--config auto --error --severity WARNING`) fails the SAST check on a finding of severity WARNING or higher; ruff runs in Skill Validation | repository settings; `.github/workflows/security.yml`, `.github/workflows/lint.yml` |
| A defect in the shell scripts | ShellCheck runs in Skill Validation and in the pre-commit hook; every tracked shell script passes `shellcheck -x -S style` | `.github/workflows/lint.yml`, `.pre-commit-config.yaml` |
| A secret is committed | Betterleaks scans every pull request to `main` and every push to `main` (`Secret Scanning`, required); GitHub secret scanning with push protection is enabled for the repository | `.github/workflows/security.yml`; repository settings, read 2026-09-30 |
| A vulnerable dependency is added | Composer Audit (required) checks the Composer dependency; dependency review runs on pull requests to `main` with `fail-on-severity: high` | `.github/workflows/security.yml` |
| A release is built from a forged tag or with a version that disagrees with `plugin.json` | The release reusable accepts only annotated tags that GitHub reports as signed, and fails when the tag differs from `.claude-plugin/plugin.json` | `.github/workflows/release.yml` |
| A released archive is tampered with | The release reusable publishes a Cosign-signed (keyless) `SHA256SUMS.txt` and build-provenance attestations for the archives | `.github/workflows/release.yml` |

The one recorded static-analysis exception is `# nosemgrep: dynamic-urllib-use-detected` on the `urlopen` call in `open_checked()`: the rule concerns `file://` URLs, which `https_request()` refuses before any request is built.

## Secure design principles applied

- **Complete mediation:** each script has one place where a credential leaves the machine (`call()` in `t3o-gitlab.py`, the single `curl` call in each Forge script), so the checks sit in one place.
- **Input validation at the boundary:** ids are converted to integers and URL schemes, paths and output locations are checked before they are used, whether they come from an argument or from a response.
- **Fail-safe defaults:** merge requests start as drafts, issue creation and directory deletion ask first, a cancelled or failed pipeline makes `pipeline status` and `pipeline wait` exit non-zero, and an expired wait says it is not a result.
- **Economy of mechanism:** the Python scripts use the standard library only; the shell scripts need `curl`, `jq`, `git` and `ssh`.
- **Least privilege in CI:** every workflow sets `permissions: {}` and grants each job only what its reusable needs; read-only checks run with `contents: read`.

## Dynamic analysis

The scripts take input, and their tests in `tests/` run them with fixed example inputs, offline, against stub `curl` and `ssh` commands and throw-away Git configuration. No fuzzer or other input-varying tool runs, and branch coverage is not measured. The tests are not a dynamic analysis in the OpenSSF sense.

## What a user cannot expect

- The scripts are not a sandbox. They run with the rights and credentials of the user who starts them, and they do what their arguments say: `t3o-gitlab.py` reads any file named with `--description-file` or `--body-file`, and `setup-typo3-coredev.sh` deletes an existing directory of the chosen project name after a confirmation prompt, clones TYPO3 Core, installs the commit-msg hook from that clone and runs DDEV.
- The skill gives guidance; it does not enforce it. The agent decides what to run, and the patches it helps to write need the same review as any other change.
- `t3o-gitlab.py probe` also accepts plain `http://` URLs; it sends no credential with them.
- Branch protection requires no approving review, and repository administrators are exempt from it. The test suite (Skill Tests), Harness Verification, Template Drift, zizmor and dependency review run on pull requests but are not required checks (repository settings, read 2026-09-30).
- The reusable workflows are referenced at `@main` of `netresearch/skill-repo-skill`, `netresearch/.github` and `netresearch/typo3-ci-workflows`, so a change there applies here without a change in this repository.
- Security fixes follow the supported-versions rules of the organisation's security policy; older releases may not receive them.
