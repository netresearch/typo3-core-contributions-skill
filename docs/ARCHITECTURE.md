# Architecture — TYPO3 Core Contributions Skill

## Purpose

This skill encapsulates procedural knowledge for contributing to TYPO3 Core through the Gerrit-based review system. It guides AI agents through the full contribution lifecycle: account setup, environment configuration, issue analysis, patch development, CI debugging, and Gerrit submission.

## Skill Structure

The skill follows the Agent Skills specification (agentskills.io):

```
skills/typo3-core-contributions/
├── SKILL.md          # Entry point — loaded by the AI agent on activation
├── references/       # Deep-dive docs loaded on demand
└── scripts/          # Executable automation helpers
```

### SKILL.md

The main skill file. Contains the contribution workflow steps, decision trees, and inline guidance. This is what the agent reads first when the skill activates.

### References

Detailed reference documents that the agent loads when it needs deeper context on a specific topic (e.g., Gerrit workflow details, commit message format rules, troubleshooting a CI failure). Keeping these separate from SKILL.md keeps the initial context window small.

### Scripts

Shell and Python scripts that automate repetitive tasks:
- **verify-prerequisites.sh** — validates that the developer's environment is correctly configured
- **setup-typo3-coredev.sh** — bootstraps a TYPO3 Core development environment with DDEV
- **validate-commit-message.py** / **create-commit-message.py** — enforce and generate compliant commit messages
- **create-forge-issue.sh** / **query-forge-metadata.sh** — interact with the TYPO3 Forge API

## Data Flow

1. Agent receives a user request related to TYPO3 Core contribution
2. SKILL.md is loaded, providing the workflow overview
3. Agent determines which phase applies (setup, development, CI debugging, submission)
4. Relevant reference docs are loaded on demand
5. Scripts are executed when automation is appropriate

## Key Design Decisions

- **Gerrit-centric**: The entire workflow revolves around Gerrit, not GitHub PRs
- **Lazy loading**: Reference docs are separate from SKILL.md to minimize initial context consumption
- **Script automation**: Repetitive validation and setup tasks are scripted rather than described in prose
- **Scope boundary**: Documentation contributions are explicitly out of scope (handled by typo3-docs-skill)
