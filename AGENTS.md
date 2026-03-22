# AGENTS.md — TYPO3 Core Contributions Skill

## Repo Structure

```
├── skills/typo3-core-contributions/
│   ├── SKILL.md                         # Main skill definition
│   ├── references/                      # Reference documentation
│   │   ├── account-setup.md
│   │   ├── commit-message-format.md
│   │   ├── commit-msg-hook.md
│   │   ├── ddev-setup-workflow.md
│   │   ├── forge-api.md
│   │   ├── gerrit-review-patterns.md
│   │   ├── gerrit-workflow.md
│   │   ├── modern-typo3-patterns.md
│   │   └── troubleshooting.md
│   └── scripts/                         # Automation scripts
│       ├── create-commit-message.py
│       ├── create-forge-issue.sh
│       ├── query-forge-metadata.sh
│       ├── setup-typo3-coredev.sh
│       ├── validate-commit-message.py
│       └── verify-prerequisites.sh
├── .github/workflows/                   # CI workflows
├── assets/                              # Images and diagrams
├── Build/                               # Build tooling
├── evals/                               # Skill evaluations
├── docs/                                # Architecture and plans
│   ├── ARCHITECTURE.md
│   └── exec-plans/
└── composer.json                        # Package definition
```

## Commands

No Makefile or npm scripts. Key scripts live in `skills/typo3-core-contributions/scripts/`:

- `bash skills/typo3-core-contributions/scripts/verify-prerequisites.sh` — check TYPO3 account, Gerrit SSH, Git config
- `bash skills/typo3-core-contributions/scripts/setup-typo3-coredev.sh` — automated TYPO3 Core dev environment setup
- `python3 skills/typo3-core-contributions/scripts/validate-commit-message.py` — validate commit message format
- `python3 skills/typo3-core-contributions/scripts/create-commit-message.py` — generate compliant commit messages

## Rules

1. **Gerrit, not GitHub PRs** — TYPO3 Core uses Gerrit (`review.typo3.org`) for code review
2. **Commit message format** — must start with `[TYPE]` (BUGFIX, FEATURE, TASK, DOCS, CLEANUP, SECURITY), include `Resolves: #<issue>` and `Releases:` lines
3. **WIP workflow** — submit as WIP first (`refs/for/main%wip`), mark ready only after CI passes
4. **Preserve Change-Id** — always amend commits to keep the Gerrit Change-Id
5. **Analyze before coding** — understand the issue deeply before writing any fix
6. **Fix ALL CI failures in one patchset** — do not iterate one failure at a time
7. **Scope boundary** — this skill covers code contributions only; documentation contributions use [typo3-docs-skill](https://github.com/netresearch/typo3-docs-skill)

## References

- [SKILL.md](skills/typo3-core-contributions/SKILL.md) — full skill definition
- [Gerrit Workflow](skills/typo3-core-contributions/references/gerrit-workflow.md)
- [Commit Message Format](skills/typo3-core-contributions/references/commit-message-format.md)
- [Troubleshooting](skills/typo3-core-contributions/references/troubleshooting.md) — 60+ scenarios
- [Account Setup](skills/typo3-core-contributions/references/account-setup.md)
- [DDEV Setup](skills/typo3-core-contributions/references/ddev-setup-workflow.md)
- [Architecture](docs/ARCHITECTURE.md)
