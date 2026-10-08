# Proving a finding in a released extension without a site

Use this when the finding is a reachable code path — open redirect, IDOR, arbitrary file read/write, a skipped validator — in a *released* extension, and a full TYPO3 install is more than the proof needs. The harness drives the controller directly in a version-matched container and shows the sink reached on the unpatched release (red) and blocked with the patch (green). It is the per-finding "two tests" of `security-report.md`, not a substitute for the fresh-site reproduction steps the policy asks for.

## Version-matched PHP in Docker

The code runs on the PHP the target TYPO3 supports, not the host's. One throwaway image per PHP version, reused across findings:

- TYPO3 9.5 / 10.4 → PHP 7.4, 11.5 → 8.1, 12.4 → 8.3, 13.4 / 14.x → 8.4.
- `php:7.4-cli` is Debian Buster (archived): rewrite `/etc/apt/sources.list` to `archive.debian.org` and `apt-get -o Acquire::Check-Valid-Until=false update` before installing.
- Install `intl mbstring zip` (`docker-php-ext-install`) and composer; TYPO3 needs intl.

## composer in the container

Write an explicit `composer.json` (do not drive it with `composer require` + `composer config` — the advisory policy blocks every TYPO3 core version and the config dance misfires):

```json
{
  "name": "harness/<ext>", "version": "1.0.0",
  "require": { "typo3/cms-extbase": "^12.4", "typo3/cms-frontend": "^12.4" },
  "autoload": { "psr-4": { "Vendor\\Ext\\": "ext/Classes/" } },
  "config": { "allow-plugins": { "typo3/cms-composer-installers": true, "typo3/class-alias-loader": true } }
}
```

Copy the released extension's `Classes/` into `ext/`, then `composer update --no-interaction --ignore-platform-reqs --no-security-blocking` (`--no-security-blocking` is the composer 2.10 flag that lets the advisory-flagged core versions install).

## Driving the controller

Build it without the constructor and set the protected state by reflection:

```php
$c = (new ReflectionClass(Ctrl::class))->newInstanceWithoutConstructor();
(new ReflectionProperty(ActionController::class, 'settings'))->setValue($c, [...]); // setAccessible first
```

An anonymous subclass overrides the sink / redirect / forward to record and stop. **Match the parent signature exactly — a mismatch is a fatal, not a finding.** Signatures differ across versions: `redirectToUri($uri, $_ = null, $statusCode = 303): void` (11.5), `forward()` is `public` in 10.4, `getAttribute($name, $default = null)`, `UriBuilder::setTargetPageUid(int $targetPageUid): UriBuilder`.

- Context is a `SingletonInterface`: register it with `GeneralUtility::setSingletonInstance(Context::class, $stub)`, not `addInstance`.
- Call `Environment::initialize(...)` before any code that uses `Environment::getPublicPath()` / `getExtensionsPath()` or `GeneralUtility::sanitizeLocalUrl()` — otherwise a `TypeError` from an uninitialised `Environment` aborts the run and fakes a pass or a block that is not the guard's doing.

## Observing a file sink without stubbing the method

To see the exact path production passes to `file_get_contents` / `file_put_contents`, define that function in the controller's **own namespace** — PHP resolves an unqualified call in the current namespace before the global one:

```php
namespace Vendor\Ext\Controller { function file_get_contents($p) { $GLOBALS['READ']=$p; throw new \RuntimeException('SINK'); } }
namespace { require 'vendor/autoload.php'; /* drive the action, assert $GLOBALS['READ'] */ }
```

This runs the real method up to the sink with no downstream stubbing.

## Detect the branch at its earliest call

A deny or error branch often ends in `LocalizationUtility::translate()`, which throws without a `LanguageService` and aborts before a marker placed at the end of the branch — so a patched run that *does* deny reads as "still vulnerable". Detect the branch at the first call unique to it (for an access check that logs on denial, `getLogger()`), not at the redirect/flash that follows. Run red on the unpatched copy, apply the patch, run green, and restore the copy between findings.

## Version facts worth reusing

- A bare `$this->redirect()/redirectToUri()` only redirects where `ActionController::redirectToUri` has return type `void` (≤ 11.5, it throws). On 12.4+ it returns `ResponseInterface`; a `void` action discards that, so the redirect never fires — a discarded-redirect finding is reachable on ≤ 11.5 and is a different (non-)issue on 12+.
- Extbase `Request::getAttribute()` exists from 11.5; an action that calls it does not run on ≤ 10.4.
