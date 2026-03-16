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
- Troubleshooting guide with 60+ scenarios
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
```

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
typo3-core-contributions/
├── SKILL.md                      # Main skill definition
├── README.md                     # This file
├── references/
│   ├── account-setup.md          # Prerequisites and account configuration
│   ├── commit-message-format.md  # Commit message standards
│   ├── ddev-setup-workflow.md    # DDEV environment setup
│   ├── gerrit-workflow.md        # Complete Gerrit submission workflow
│   └── troubleshooting.md        # 60+ troubleshooting scenarios
├── scripts/
│   ├── setup-typo3-coredev.sh    # Automated environment setup
│   └── verify-prerequisites.sh   # Prerequisites checker
└── assets/
    └── images/                   # Workflow diagrams and screenshots
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

**Types**: BUGFIX, FEATURE, TASK, DOCS, CLEANUP, SECURITY

**Required**: At least one `Resolves:` line

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
- ✅ Comprehensive troubleshooting guide (60+ scenarios)
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

**Version**: 1.1.0
**Last Updated**: 2025-10-27
**Status**: Production-ready, validated on live submissions

---

**Made with ❤️ for Open Source by [Netresearch](https://www.netresearch.de/)**
