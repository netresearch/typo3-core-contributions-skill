# Reporting a Vulnerability to the TYPO3 Security Team

Load this before building anything for a report. The team's own pages decide channel, language and required content, and a package built first and checked against them afterwards misses them. Measured on 2026-10-07 against the live pages below; read them again, they change.

## Sources — read the files themselves, not a summary

- [`https://typo3.org/security.txt`](https://typo3.org/security.txt) is PGP clear-signed and holds `Contact`, `Encryption` (key URLs and an `openpgp4fpr:` fingerprint), `Preferred-Languages: en` and `Policy`. Print it whole: a filter on `Contact|Policy` hides `Encryption:` and `Preferred-Languages:`.
- The `Policy:` URL redirects to `https://typo3.community/contribute/teams-committees/security/security-in-typo3`. Fetch with redirects followed (`curl -L`).
- The contact page, `https://typo3.community/contribute/teams-committees/security/contact-us`, states the key id and the complete fingerprint for encrypted mail.
- The bug bounty rules, `https://typo3.community/contribute/teams-committees/security/bug-bounty-program`, list what the team counts as a vulnerability. `https://typo3.org/community/teams/security/bug-bounty-program` redirects there; the root-relative links on the policy page belong to `typo3.community`, and `typo3.org/contribute/…` answers 404.

## What the team asks for

- Send the report by e-mail to the address in `Contact`. Encrypted mail is offered ("You can send GPG/PGP encrypted emails …") with the key named in `Encryption`. Before encrypting, check that the fingerprint on the contact page equals the one in `security.txt`.
- Write in English (`Preferred-Languages: en`).
- The policy lists as required: the affected TYPO3 version and/or extension version, and "Detailed steps to reproduce the issue on a fresh TYPO3 website". Saying that you do not want to be credited in the Security Bulletin is optional.
- Timeline the policy states: acknowledgement within 48 hours, a further response within 7 days. Nothing becomes public before a fix is released.
- Do not put the finding into a public branch, merge request or issue (`t3o-gitlab-workflow.md`, "Security findings do not go through git.typo3.org").

## Is it in scope

The bug bounty page lists as qualifying: SQL injection, server-side code execution, cross-site scripting, cross-site request forgery, authentication and authorization flaws, sensitive information disclosure. Among the non-qualifying ones are flaws that only work with a super-privileged user (install tool, maintenance mode). Third-party extensions count only where their distribution has an impact (download and installation counts); the decision is the team's. A finding that needs a backend login is not decided by the page, so say which role triggers it.

Look for an existing advisory first: `https://packagist.org/api/security-advisories/?packages[]=<vendor/package>` and the TYPO3-EXT-SA list. Compare the advisory's affected range with the version you hold. An advisory for another defect in the same extension does not cover yours.

## The package

Build for a reader who has nothing but the archive.

1. **One patch per affected version**, generated against the exact commit you tested, and `git apply --check` against a fresh clone of the tag.
2. **Two tests per finding**: one that shows the defect on the unpatched release, one that asserts the fixed behaviour. The second is red before the patch and green after it ([proving-a-test.md](proving-a-test.md)).
3. **Steps to reproduce on a fresh TYPO3 website**, run once on a local instance you control, never on a third party's system.
4. **Permalinks to commits, not tags.** Take the commit Packagist records for the version (`source.reference`), compare it with `git ls-remote <repo> 'refs/tags/<version>^{}'`, fetch each cited file at that commit and assert that the cited line holds the cited token.
5. **Verify the archive as it is received**: unpack it into an empty directory, follow its README word for word, run its tests, and compare the file list with the expected list. A tool that runs inside the package directory can add files; `qsv`, for example, writes cache files next to a CSV (the `data-tools` skill, `references/csv-processing.md`).
6. **Scan the text for local paths, user names and session ids** before it leaves.
7. **English throughout**, including the column headers of any CSV.
