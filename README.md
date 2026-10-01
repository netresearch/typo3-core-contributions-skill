<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# TYPO3 Core Contributions Skill

An AI skill for guiding contributions to TYPO3 Core through systematic workflows, automated quality checks, and best practices enforcement.

## 🔌 Compatibility

This is an **Agent Skill** following the [open standard](https://agentskills.io) originally developed by Anthropic and released for cross-platform use.

**Supported Platforms:**
- ✅ Claude Code (Anthropic)
- ✅ Cursor
- ✅ GitHub Copilot
- ✅ Other skills-compatible AI agents

> Skills are portable packages of procedural knowledge that work across any AI agent supporting the Agent Skills specification.


## Overview

This skill provides comprehensive guidance for contributing to TYPO3 Core, including:

- **Gerrit-based code review workflow**
- **Automated CI/CD debugging**
- **Commit message formatting**
- **WIP (Work in Progress) state management**
- **Testing and quality assurance**
- **Account setup and prerequisites**

## Features

### 🔄 Complete Contribution Workflow
- Step-by-step guidance from setup to patch submission
- Automated detection of common issues
- Best practices enforcement at every stage

### 🤖 CI/CD Integration
- Systematic debugging of failed GitLab CI jobs
- Pattern recognition for common failures
- Automated fix suggestions

### ✅ Quality Gates
- Pre-submission validation
- Code style enforcement (CGL)
- PHPStan static analysis
- Comprehensive test coverage

### 📝 Documentation
- Gerrit workflow reference
- Commit message format guidelines
- Troubleshooting guide for the Gerrit-specific failures
- WIP state management

## Quick Start

### Prerequisites

Ensure you have:
- Git configured with your TYPO3.org email
- SSH key uploaded to review.typo3.org
- Docker (for DDEV) or native PHP 8.2+ environment

## Installation

### Marketplace (Recommended)

Add the [Netresearch marketplace](https://github.com/netresearch/claude-code-marketplace) once, then browse and install skills:

```bash
# Claude Code
/plugin marketplace add netresearch/claude-code-marketplace
/plugin install typo3-core-contributions@netresearch-claude-code-marketplace
```

### Without a marketplace

Since Claude Code 2.1.157 a plugin directory under your personal skills directory loads on its own:

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/netresearch/typo3-core-contributions-skill.git \
  ~/.claude/skills/typo3-core-contributions
```

It loads as `typo3-core-contributions@skills-dir` on the next session. Update with `git -C ~/.claude/skills/typo3-core-contributions pull` and start a new session; remove it by deleting the directory. This route has no `claude plugin update`.

### npx ([skills.sh](https://skills.sh))

Install with any [Agent Skills](https://agentskills.io)-compatible agent:

```bash
npx skills add https://github.com/netresearch/typo3-core-contributions-skill --skill typo3-core-contributions
```

### Download Release

Download the [latest release](https://github.com/netresearch/typo3-core-contributions-skill/releases/latest) and extract to your agent's skills directory.

### Git Clone

```bash
git clone https://github.com/netresearch/typo3-core-contributions-skill.git
```

### Composer (PHP Projects)

```bash
composer require netresearch/typo3-core-contributions-skill
```

Requires [netresearch/composer-agent-skill-plugin](https://github.com/netresearch/composer-agent-skill-plugin).

## Scope

**This skill covers**: TYPO3 Core code contributions (PHP, JavaScript, CSS, tests)
- Submission via Gerrit (review.typo3.org)
- Git commit-msg hooks and validation
- Forge issue tracking
- GitLab CI/CD pipeline

**Not covered**: TYPO3 Documentation contributions
- For documentation work, use: https://github.com/netresearch/typo3-docs-skill
- Documentation uses GitHub Pull Requests, not Gerrit
- Different format (reStructuredText) and workflows

## Directory Structure

```
skills/typo3-core-contributions/
├── SKILL.md                         # Main skill definition
├── references/
│   ├── account-setup.md             # Prerequisites and account configuration
│   ├── commit-message-format.md     # Commit message standards
│   ├── commit-msg-hook.md           # What the core commit-msg hook checks
│   ├── ddev-setup-workflow.md       # DDEV environment setup
│   ├── forge-api.md                 # Forge (Redmine) REST API
│   ├── gerrit-review-patterns.md    # Review feedback patterns
│   ├── gerrit-workflow.md           # Complete Gerrit submission workflow
│   ├── modern-typo3-patterns.md     # Current TYPO3 coding patterns
│   ├── proving-a-test.md            # Showing that a test catches the bug
│   ├── t3o-gitlab-workflow.md       # t3o site repositories on git.typo3.org
│   └── troubleshooting.md           # Gerrit-specific failures and their fixes
└── scripts/
    ├── create-commit-message.py     # Commit message generator
    ├── create-forge-issue.sh        # Interactive Forge issue creation
    ├── query-forge-metadata.sh      # Forge trackers and categories
    ├── setup-typo3-coredev.sh       # Automated environment setup
    ├── t3o-gitlab.py                # git.typo3.org helper for t3o sites
    ├── validate-commit-message.py   # Commit message validator
    └── verify-prerequisites.sh      # Prerequisites checker
tests/                               # Offline tests for the scripts
assets/commit-template.txt           # Git commit message template
```

## Key Workflows

### 1. Initial Setup

```bash
# Verify prerequisites
./scripts/verify-prerequisites.sh

# Setup TYPO3 Core development environment
./scripts/setup-typo3-coredev.sh
```

### 2. Create Patch

```bash
# Create feature branch
git checkout -b feature/issue-number-description

# Make changes, commit with proper format
git commit -m "[BUGFIX] Fix indexed search null handling

Resolves: #105737
Releases: main"
```

### 3. Submit to Gerrit

```bash
# Submit as WIP (Work in Progress)
git push origin HEAD:refs/for/main%wip

# After CI passes, mark as ready
git commit --amend --allow-empty --no-edit
git push origin HEAD:refs/for/main%ready
```

### 4. Handle CI Failures

The skill provides systematic debugging:
1. Check ALL failed job logs
2. Identify failure patterns (cgl, phpstan, unit tests)
3. Fix all issues in ONE patchset
4. Re-submit and verify

## WIP State Management

### Command-Line Approach (Recommended)

```bash
# Set WIP state
git push origin HEAD:refs/for/main%wip

# Remove WIP state
git commit --amend --allow-empty --no-edit
git push origin HEAD:refs/for/main%ready
```

### Web UI Alternative

Open review URL and click "Start Review" button.

**Note**: SSH `gerrit review` command does NOT support WIP flags.

## Commit Message Format

Required structure:

```
[TYPE] Short description (max 52 chars)

Extended description explaining the why and how.

Resolves: #12345
Releases: main, 12.4
```

**Types**: BUGFIX, FEATURE, TASK, DOCS, SECURITY; a breaking change puts `[!!!]` in front, as in `[!!!][FEATURE]`

**Required**: a `Resolves:` line and a `Releases:` line; `validate-commit-message.py` rejects a message without either

**Optional**: `Related:` (but cannot be used alone)

## CI/CD Debugging

Common failure patterns:

### CGL (Code Style)
```bash
Build/Scripts/cglFixMyCommit.sh
git commit --amend --no-edit
```

### PHPStan
```bash
Build/Scripts/runTests.sh -s phpstan
# Fix reported issues
```

### Unit Tests
```bash
Build/Scripts/runTests.sh -s unit path/to/test
# Fix test failures
```

## Troubleshooting

The skill includes comprehensive troubleshooting for:

- **Account Issues**: Email mismatch, SSH authentication, commit-msg hook
- **CI Failures**: CGL, PHPStan, unit tests, functional tests
- **Gerrit Issues**: WIP state, patch conflicts, rebase requirements
- **Testing Issues**: Test failures, coverage gaps, fixture setup
- **Code Quality**: Naming conventions, type safety, defensive programming

See `references/troubleshooting.md` for detailed solutions.

## Real-World Testing

This skill was developed and validated through:

- **Forge Issue #105737**: TypeError in indexed search
- **7 patchsets** with iterative CI debugging
- **GitHub PR #397**: Documentation improvements
- **Live Gerrit testing**: WIP workflow validation

All workflows have been tested on actual TYPO3 Core submissions.

## Updates and Enhancements

Recent additions:

### v1.1.0 (2025-10-27)
- ✅ WIP state management (command-line and web UI)
- ✅ CI failure investigation protocol (423 lines)
- ✅ Troubleshooting guide for the Gerrit-specific failures
- ✅ PHPStan error guidance
- ✅ Code style enforcement patterns
- ✅ Documentation scope clarification

## Contributing

To improve this skill:

1. Test on real TYPO3 Core contributions
2. Document edge cases in troubleshooting guide
3. Add automation scripts for common tasks
4. Validate against official TYPO3 documentation

## Resources

### Official TYPO3 Documentation
- [Contribution Guide](https://docs.typo3.org/m/typo3/guide-contributionworkflow/main/en-us/)
- [Gerrit Documentation](https://gerrit-review.googlesource.com/Documentation/user-upload.html)
- [TYPO3 Forge](https://forge.typo3.org/)

### Related Skills
- [TYPO3 Docs Skill](https://github.com/netresearch/typo3-docs-skill) - For documentation contributions

## Tests

`tests/` holds one offline test file per script group. Each runs the shipped script as a user would, with stub `curl` and `ssh` commands first in `PATH`, a throw-away Git configuration and temporary directories, so no test reaches forge.typo3.org, git.typo3.org or review.typo3.org:

- `tests/validate-commit-message.sh`: subject types including `[!!!]` breaking changes, the `Resolves:` and `Releases:` footers, the `EXT:` warning and the body line length.
- `tests/create-commit-message.sh`: the generated subject and footers, a validator run over each generated message, and the `--output` confinement.
- `tests/t3o-gitlab.sh`: argument parsing, the draft-prefix rule, the pipeline wait budget and the refusal of non-numeric ids.
- `tests/forge-scripts.sh`: the request `create-forge-issue.sh` and `query-forge-metadata.sh` send, driven through a terminal with `script`.
- `tests/verify-prerequisites.sh`: the checks against a configured and a misconfigured checkout.

`setup-typo3-coredev.sh` has no test: it clones TYPO3 Core and starts DDEV.

Run them from the repository root; they need `bash`, `python3`, `git`, `jq` and `script` (util-linux):

```bash
rc=0; for t in tests/*.sh; do bash "$t" || { echo "FAILED: $t"; rc=1; }; done; [ "$rc" -eq 0 ]
pre-commit run --all-files
```

Each check prints `ok <check>`, or `FAIL <check>` followed by what was expected and what was found, and a file exits 1 when one of its checks failed. `tests/forge-scripts.sh` uses the util-linux `script -qec`, which the BSD `script` on macOS does not accept. The pre-commit hooks in `.pre-commit-config.yaml` run the skill validator, the version-parity check, markdownlint, yamllint, actionlint, JSON and YAML syntax, ruff and ShellCheck.

In CI, `tests.yml` (Skill Tests) runs every `tests/**/*.sh` on each pull request and push to `main`, marks a failing file with an error annotation, and fails when no test file runs. A change to a script comes with a test in `tests/` that fails without the change.

## Dependencies

- **Scripts:** the Python scripts use the standard library only. The shell scripts need `curl`, `jq`, `git` and `ssh`, and `verify-prerequisites.sh` and `setup-typo3-coredev.sh` also `timeout` from GNU coreutils (macOS has none; Homebrew's coreutils installs it as `gtimeout`, and its `libexec/gnubin` directory on `PATH` provides `timeout`); `setup-typo3-coredev.sh` also needs DDEV and Docker. These are system tools the contributor installs: `verify-prerequisites.sh` checks Git, the Gerrit SSH connection, Composer, PHP and DDEV, `setup-typo3-coredev.sh` checks Git, DDEV and Docker, and the Forge scripts stop when `curl` or `jq` is missing.
- **Composer:** `composer.json` requires `netresearch/composer-agent-skill-plugin` (constraint `*`), the Composer plugin for packages of type `ai-agent-skill`. No lock file is committed: the package is installed as a dependency of other projects, whose lock files pin it.
- **Pre-commit hooks:** each hook repository in `.pre-commit-config.yaml` is pinned by `rev:`.
- **CI:** the workflows call reusable workflows of `netresearch/skill-repo-skill`, `netresearch/.github` and `netresearch/typo3-ci-workflows` at `@main`; those pin their actions by commit SHA.
- **Updates:** Renovate (`renovate.json`, preset `github>netresearch/renovate-config`) opens pull requests for new hook revisions; `auto-merge-deps.yml` merges dependency pull requests once the required checks pass, except those labelled `deps-no-automerge` or `deps-major`. Composer Audit and dependency review check dependency changes on pull requests.
- **Selection:** a new dependency is added only when a script or the tooling needs it, from its upstream source (Packagist, the tool's own repository), under a licence compatible with this repository's.

## Governance and policies

This repository follows the Netresearch organisation policies:

- [Governance](https://github.com/netresearch/.github/blob/main/GOVERNANCE.md): ownership, roles, how decisions are made and disputes resolved.
- [Roadmap](https://github.com/netresearch/.github/blob/main/ROADMAP.md): planned and explicitly excluded work for the coming year.
- [Handling of dependency and code analysis findings](https://github.com/netresearch/.github/blob/main/SECURITY.md#handling-of-dependency-and-code-analysis-findings): thresholds, deadlines and the exception process for dependency (SCA) and static analysis (SAST) findings.
- [Secret management](https://github.com/netresearch/.github/blob/main/SECURITY.md#secret-management): how CI and release credentials are stored, accessed and rotated.
- [Access roster](https://github.com/netresearch/.github/blob/main/docs/access-roster.md): who holds administrative access to this repository and the organisation.

The security assurance case for this skill and its scripts (threat model, trust boundaries, countermeasures and limits) is in [docs/SECURITY-ASSURANCE.md](docs/SECURITY-ASSURANCE.md).

Checks that run on pull requests in this repository:

- Every pull request: Skill Validation (`lint.yml`: skill structure, manifest sync, markdownlint, yamllint, actionlint, JSON syntax, ShellCheck, ruff, checkpoint schemas), Eval Validation (`eval-validate.yml`) and Skill Tests (`tests.yml`).
- Pull requests to `main`: `security.yml` with Composer Audit, SAST (Opengrep; findings handled under the [organisation's static analysis rule](https://github.com/netresearch/.github/blob/main/SECURITY.md#static-analysis-sast)), Betterleaks secret scanning, zizmor and dependency review (`fail-on-severity: high`); Harness Verification (`harness-verify.yml`); Template Drift (`check-template-drift.yml`); CodeQL analysis of Python and the GitHub Actions workflows (default setup) and the DCO sign-off check.
- Also on every pull request: Labeler (`labeler.yml`), the dependency auto-merge job (`auto-merge-deps.yml`, skipped unless a dependency bot opened the pull request), SonarCloud code analysis, Copilot code review (a repository ruleset) and CodeRabbit review.
- Required for merging into `main`: Skill Validation, Eval Validation, Composer Audit, SAST (Opengrep), Secret Scanning (Betterleaks), `Analyze (actions)`, `Analyze (python)` and DCO. GitHub secret scanning with push protection is enabled for the repository.
- The only recorded static-analysis exception is the `nosemgrep` comment on the `urlopen` call in `t3o-gitlab.py`, explained in the assurance case.

## License

This project uses split licensing:

- **Code** (scripts, workflows, configs): [MIT](LICENSE-MIT)
- **Content** (skill definitions, documentation, references): [CC-BY-SA-4.0](LICENSE-CC-BY-SA-4.0)

See the individual license files for full terms.

## Author

Created for use with Claude Code and TYPO3 Core contributions.

Maintained by: Netresearch DTT GmbH

## Support

For issues or questions:
- Open an issue in this repository
- Reference official TYPO3 documentation
- Test workflows on live Gerrit instance

---

**Made with ❤️ for Open Source by [Netresearch](https://www.netresearch.de/)**
