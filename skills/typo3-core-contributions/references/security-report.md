# Reporting a Vulnerability to the TYPO3 Security Team

Load this before building anything for a report. The team's own pages decide channel, language and required content, and a package built first and checked against them afterwards misses them. Measured on 2026-10-07 against the live pages below; read them again, they change.

## Sources — read the files themselves, not a summary

- [`https://typo3.org/security.txt`](https://typo3.org/security.txt) is PGP clear-signed and holds `Contact`, `Encryption` (key URLs and an `openpgp4fpr:` fingerprint), `Preferred-Languages: en` and `Policy`. Print it whole: a filter on `Contact|Policy` hides `Encryption:` and `Preferred-Languages:`.
- The `Policy:` URL redirects to `https://typo3.community/contribute/teams-committees/security/security-in-typo3`. Fetch with redirects followed (`curl -L`).
- The contact page, `https://typo3.community/contribute/teams-committees/security/contact-us`, states the key id and the complete fingerprint for encrypted mail.
- The public Bug Bounty Program is **discontinued** ([announcement](https://news.typo3.com/article/bug-bounty-program-discontinued)); its page, `https://typo3.community/contribute/teams-committees/security/bug-bounty-program`, now opens with "Bug Bounty Program Discontinued". Its former qualifying lists are history, not current reporting criteria. Reporting, review, coordinated disclosure, advisories, CVEs and credit continue. The root-relative links on the policy page belong to `typo3.community`; `typo3.org/contribute/…` answers 404.

## What the team asks for

- Send the report by e-mail to the address in `Contact`. Encrypted mail is offered ("You can send GPG/PGP encrypted emails …") with the key named in `Encryption`. Before encrypting, check that the fingerprint on the contact page equals the one in `security.txt`.
- Write in English (`Preferred-Languages: en`).
- The policy lists as required: the affected TYPO3 version and/or extension version, and "Detailed steps to reproduce the issue on a fresh TYPO3 website". Saying that you do not want to be credited in the Security Bulletin is optional.
- Timeline the policy states: acknowledgement within 48 hours, a further response within 7 days. Nothing becomes public before a fix is released.
- Suggest a **CVSS v4.0** vector. Current advisories (TYPO3-EXT-SA-2026-*) carry a "Suggested CVSS v4.0" line and the team sets the official score, so give v4.0; add v3.1 only as a reference if you have it. The v4.0 score is a MacroVector lookup, not a formula — compute it offline with the `cvss` Python library (`security-audit` skill, `references/cvss-scoring.md`), never by hand.
- The team triages a high volume and **explicitly flags AI-generated reports** as the thing that slows them down. Keep every report terse, reproduced and patched, and do not send status inquiries while a case is open — the acknowledgement already states the timeline.
- When the finding belongs to a case you already opened, **reply inside that e-mail thread** and leave the `[Ticket#…]` subject intact, so everything stays one OTRS ticket; a new subject opens a second ticket and splits the case.
- Do not put the finding into a public branch, merge request or issue (`t3o-gitlab-workflow.md`, "Security findings do not go through git.typo3.org").

## Is it in scope

The policy says: if you are unsure whether an issue is a security vulnerability, report it anyway; the Security Team decides. Say which role triggers the finding (anonymous visitor, frontend user, backend user, administrator). Do not judge scope from the lists on the discontinued bug bounty page.

Look for an existing advisory first: `https://packagist.org/api/security-advisories/?packages[]=<vendor/package>` and the TYPO3-EXT-SA list. Compare the advisory's affected range with the version you hold. An advisory for another defect in the same extension does not cover yours.

**State the affected version precisely, including the untagged case.** The flaw may live only in a development branch (Composer `dev-master`, `vN.x-dev`) with no tagged release carrying it — common where the dev branches are the only installable source for a newer TYPO3 version. Say so explicitly, name the branch and the exact commit, and name which tagged release is *not* affected. Then evidence that the vulnerable code is actually used, with Packagist per-version install counts: `https://packagist.org/packages/<vendor>/<package>/stats/<version>.json?average=monthly&from=YYYY-MM-01` — pass the Composer version (`dev-master`, `vN.x-dev`, or a tag) — and compare the dev-branch installs against the tagged release. The Security Team decides scope; give them the numbers rather than a claim.

## The package

Build for a reader who has nothing but the archive. The covering e-mail carries the one-line-per-finding summary, the suggested CVSS and any prior-ticket reference; the archive holds only the technical report, the patches and the tests. Meta addressed to the team inside the archive ("reported to you", "do not publish before a fix", a credit placeholder) is noise the reader does not need — credit is taken from the sender, so omit it unless you are declining it.

1. **One patch per affected version**, generated against the exact commit you tested, and `git apply --check` against a fresh clone of the tag.
2. **Two tests per finding**: one that shows the defect on the unpatched release, one that asserts the fixed behaviour. The second is red before the patch and green after it ([proving-a-test.md](proving-a-test.md)). For a *released* extension with no site to install, build those two tests as a standalone exploit harness that drives the controller directly: [security-proof-harness.md](security-proof-harness.md).
3. **Steps to reproduce on a fresh TYPO3 website**, run once on a local instance you control, never on a third party's system. When the defect is in a TYPO3 *library or package* (for example `typo3/html-sanitizer`) whose exploit needs a non-default configuration — a custom `Behavior`, an opt-in builder — a fresh **default** site may not reproduce it, because the default path diverts the input before it reaches the vulnerable code (html-sanitizer: Core's `DefaultSanitizerBuilder` sends `<svg>` to `SvgSanitizer`, not the allowlist). Then reproduce at the library level (composer-require the version, a script that drives the vulnerable API), and state the scope honestly: name the default code path that keeps a default site safe, and the consumer configuration that is affected. Cite a precedent advisory for a custom-behavior-only bypass (for example `GHSA-hvwx-qh2h-xcfj`, "only custom behaviors … were vulnerable", still assigned a CVE). Do not manufacture a default-site reproduction that does not exist — an honest "default config does not reach it, here is the library-level proof" is stronger, and the Security Team decides scope.
4. **Permalinks to commits, not tags.** Take the commit Packagist records for the version (`source.reference`), compare it with `git ls-remote <repo> 'refs/tags/<version>^{}'`, fetch each cited file at that commit and assert that the cited line holds the cited token.
5. **Verify the archive as it is received**: unpack it into an empty directory, follow its README word for word, run its tests, and compare the file list with the expected list. A tool that runs inside the package directory can add files; `qsv`, for example, writes cache files next to a CSV (the `data-tools` skill, `references/csv-processing.md`).
6. **Scan the text for local paths, user names and session ids** before it leaves.
7. **English throughout**, including the column headers of any CSV.

## The covering e-mail

Keep the e-mail body short. The team triages many reports and decides fast, and a long, exhaustive body reads as AI-generated filler that works against the report. Put the mechanism, the impact, the CVSS score, the affected versions and a one-line workaround in a few short paragraphs; move every detail — the full write-up, the reproduction, the permalinks, the patch descriptions and the test evidence — into the attached files, and do not restate the attachment in the body. Leave out anything the reader does not need in order to act: your own fork, an unpublished advisory of your own, or a credit instruction stay out of the body unless the policy asks for them.
