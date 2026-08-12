# git.typo3.org — GitLab workflow for t3o sites

**When to load:** any work against `git.typo3.org` that is not reading Core CI
logs — t3o site repositories, merge requests, issues, work items, labels,
pipelines. Core patches go to Gerrit instead; see `gerrit-workflow.md`.

## typo3.org has three systems — pick the right one first

| Host | System | Used for |
|---|---|---|
| `review.typo3.org` | Gerrit | TYPO3 **Core** patches |
| `forge.typo3.org` | Redmine | TYPO3 **Core** issues |
| `git.typo3.org` | GitLab (19.x EE) | t3o **site** repositories, and read-only Core CI logs |

Getting this wrong is the first failure mode. `git.typo3.org/typo3/CI/cms/-/jobs/<id>`
is a Core CI log and belongs to the Gerrit workflow. `git.typo3.org/services/t3o-sites/**`
is ordinary GitLab work with branches, merge requests and issues — Gerrit is not
involved and `refs/for/main` means nothing there.

Known t3o site groups:

- `services/t3o-sites/extensions.typo3.org/ter` — the TER site (TYPO3 v13, DDEV)
- `services/t3o-sites/extensions.typo3.org/anubis` — the bot wall in front of it
- `services/t3o-sites/common/t3olayout` — the shared layout package for **all** t3o sites
- `services/t3o-sites/common/t3o-basic-pipeline-jobs` — the shared CI template

A change in `t3olayout` lands on every t3o site. Treat it as a shared library,
not as the site you happen to be looking at.

## Authentication

A personal access token belongs in `~/.secrets/git.typo3.org` (`glpat-…`).

```bash
curl -sS -H "PRIVATE-TOKEN: $(cat ~/.secrets/git.typo3.org)" \
  "https://git.typo3.org/api/v4/user"
```

Do not reach for `glab`: `GITLAB_HOST` is commonly exported for a different
instance, and `--hostname` only works on `glab api`. The REST API with an
explicit header is unambiguous.

`${CLAUDE_SKILL_DIR}/scripts/t3o-gitlab.py` wraps the calls below — start there
rather than hand-rolling curl.

## Check your access level before planning anything

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/t3o-gitlab.py" access services/t3o-sites/extensions.typo3.org/ter
```

`permissions.project_access.access_level` decides which plan is even possible:

| Level | You can | You cannot |
|---|---|---|
| none (`null`) | read, **create issues**, edit **your own** issue descriptions | push, set labels, link across projects |
| 20 Reporter | + set labels, link issues | push |
| 30 Developer | + push branches, open MRs, set labels | merge (see below) |

Three traps, all verified the hard way:

**Labels fail silently without Reporter.** `PUT /issues/:iid` with `labels`
returns **HTTP 200** and simply does not apply them. Always read the returned
object back and confirm the field, never trust the status code.

**Cross-project issue links need Guest in both projects.** Otherwise
`POST /issues/:iid/links` returns 403 *"You must have at least the Guest role in
both projects."* Fall back to a textual reference.

**Forking may be disabled.** `POST /projects/:id/fork` can answer
*"Limit reached — You cannot create projects in your personal namespace."*
When that happens the fork-and-MR path does not exist. File an issue containing
a ready-to-apply diff instead, and say in it that you cannot open an MR.

## Contribution rules for t3o sites

`CONTRIBUTING.md` in these repos points at the
[t3o team workflow](https://docs.typo3.org/m/typo3/team-t3oteam/main/en-us/Workflow/Index.html).
The binding rules:

- **Target `develop`, never `main`.** Maintainers merge `develop` into `main` for releases.
- **Draft while work is in progress.** Remove the `Draft:` prefix only when it is ready for maintainer review.
- **You cannot merge your own merge request.** A maintainer reviews and merges. This is not a formality — do not `merge` even with Developer rights.
- **Branch naming** is documented as `feature/<issue-number>-<description>` and `hotfix/<description>`. Repo practice also uses `task/` and `bugfix/` prefixes; keep the issue number either way.
- **The MR description must state the changes *and the testing done*.** An MR without a testing section is incomplete by their rules.
- **Commit subjects use the Core prefixes** — `[BUGFIX]`, `[TASK]`, `[FEATURE]` — so `validate-commit-message.py` still applies, minus the Gerrit-only `Change-Id`. Use `Relates: #<iid>` for the site issue.

### Issue templates are not optional furniture

`.gitlab/issue_templates/{Bugreport,Feature,Task}.md` exist in `ter` and
`t3olayout`. **Read them before opening the first issue**, not after the tenth.
Every template requires an **Acceptance Criteria** checklist; the Bugreport one
also wants Summary, Steps to reproduce, an Example URL, current vs expected
behaviour, and logs.

Their trailing `/label ~ter` quick action refers to a label that does not exist
in `ter` — the real area labels are `TER Website`, `TER Extensions` and
`extensions.typo3.org`. Set labels explicitly rather than relying on the
template.

House label taxonomy: `Type::Bug` / `Type::Feature` / `Type::Task`,
`Skill:: Backend|Frontend|Ops|Design|Solr|Content`, `Process: To discuss`,
`Process:: Review`, plus area labels. When the cause of a finding is not
established, `Process: To discuss` is more honest than `Type::Bug`.

## Issue and work item mechanics

**Cross-project references need the full path.** `t3olayout#678` renders as
plain text; `services/t3o-sites/common/t3olayout#678` renders as a link.

**Extended references carry title and status.** Append `+` for the title, `+s`
for title *and* state:

```
!883+s                                        → Draft: [BUGFIX] … • Open
services/t3o-sites/common/t3olayout#678+s     → Main navigation carries … • Open
```

Only **bare** references expand. A markdown link `[#678](https://…)` stays a
plain link, so prefer bare references in index tables. The expansion happens in
the browser; `POST /api/v4/markdown` returns the pre-expansion HTML, so verify
by checking that `data-original` kept the `+s` and that the reference resolved
to an id — not by looking for the title in the rendered text.

**Sub-issues under an Issue are refused.** `workItemUpdate` with
`hierarchyWidget.childrenIds` answers *"it's not allowed to add this type of
parent item"* for Issue → Issue. Allowed is Epic → Issue and Issue → Task, and
`WorkItemUpdateInput` does **not** accept `workItemTypeId`, so an existing Issue
cannot be converted to a Task through the API either. Use `relates_to` links and
an index comment instead.

**URLs.** Issues resolve under both `/-/issues/<iid>` and `/-/work_items/<iid>`;
the API returns the work-item form.

## CI: check whether it runs at all

`ter` has `builds_access_level: disabled`. No pipeline runs for anyone — a
`head_pipeline` of `null` on your MR is not your fault, and
`GET /projects/:id/pipelines` may answer 403. **Verify this before promising
that CI will catch anything**, then reproduce the gates locally.

The shared template `services/t3o-sites/common/t3o-basic-pipeline-jobs@v13`
defines `test:typoscript` and `test:php`; the site repo adds its own jobs.

### Reproducing the gates locally (ter)

```bash
composer install --ignore-platform-reqs --no-scripts

composer test:rector      # rector process -n
composer test:phpstan     # phpstan analyse -c phpstan.neon
composer test:unit        # phpunit -c .gitlab-ci/Tests/phpunit.xml
PHP_CS_FIXER_IGNORE_ENV=1 vendor/bin/php-cs-fixer fix --dry-run -n \
  --config=.php-cs-fixer.dist.php <changed files>
```

`test:unit` needs `TYPO3_PATH_WEB="$PWD/public"` and an existing
`public/fileadmin/currentcoredata.json`.

TypoScript lint is **not** in `require-dev`; the CI job installs it globally:

```bash
composer require helmich/typo3-typoscript-lint     # in a scratch dir
typoscript-lint -c typoscript-lint.yml --fail-on-warnings
```

Run these with the **repository's own dependencies**. Borrowing a binary from
another checkout's `vendor/` gives a different tool version and a false pass:
in one session `php-cs-fixer` from a foreign vendor reported clean while the
repo's own `rector` and `phpstan` each found a real defect in the same file.

### Rector says constructor injection — verify before obeying

`GeneralUtilityMakeInstanceToConstructorPropertyRector` will rewrite
`GeneralUtility::makeInstance()` inside a ViewHelper into constructor injection.
That is correct **only** because `typo3/cms-fluid`'s `Configuration/Services.php`
tags every `ViewHelperInterface` implementation as `fluid.viewhelper` and a
compiler pass sets those definitions public and non-shared, and because the
extension's `Services.yaml` registers `Classes/*` with `autoconfigure: true`.
Check both before accepting the rewrite — without the container registration,
`ViewHelperResolver` falls back to `new $class()` and a required constructor
argument is a fatal error. Rector's output is also mechanical: it leaves
`$x = $this->x;` aliases and misplaced blank lines worth cleaning up by hand.

## extensions.typo3.org sits behind Anubis — every live probe is suspect

Anubis is a bot wall in front of `extensions.typo3.org`. Its `policy.yaml`
weighs any user agent matching `Mozilla|Opera` into `CHALLENGE`, and
`status_codes.CHALLENGE: 200` serves the challenge as a **successful response**:

- HTTP **200**, `content-type: text/html`, about **7537 bytes**
- `<title>Making sure you're not a bot!</title>`
- carries its own `<meta name="robots" content="noindex,nofollow">`
- `Set-Cookie: techaro.lol-anubis-auth-*`, body markers `anubis`, `techaro`, `within.website`

So `curl -A 'Mozilla/…' https://extensions.typo3.org/` will report that the page
is `noindex` — and that is the wall, not the site. Static asset paths are
challenged too, which is why Lighthouse logs
`Refused to execute script … MIME type ('text/html')` for perfectly healthy JS.

**Fingerprint every response before reasoning about it**: status, content type,
byte size, `<title>`, and a grep for the markers. Two unrelated URLs answering
with the identical byte size is the tell. A plain `curl` user agent passes
through to the origin, as does `Chrome-Lighthouse`.

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/t3o-gitlab.py" probe https://extensions.typo3.org/
```

Do not conclude that a crawler is blocked because a `Googlebot` user agent gets
challenged from your machine: `(data)/crawlers/_allow-good.yaml` verifies
crawlers by address, not by user agent string.

## Reporting findings

One finding, one ticket. A long comment listing six problems gives none of them
a place to be discussed, rejected or closed. Make the comment an index that
links the tickets, and put each finding — with its evidence and acceptance
criteria — in its own issue. Search the existing tracker first: an open issue
for the same thing usually already exists.

When the fix belongs in a repository you cannot push to, the issue **is** the
deliverable: include the ready diff in a fenced block and say plainly that you
have no push access and that forking is refused.
