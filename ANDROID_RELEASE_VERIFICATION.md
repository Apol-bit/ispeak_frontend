# Android release preparation verification — 2026-10-09

**Identity and fail-closed release configuration are implemented. The signed
release gate remains BLOCKED by missing team-controlled signing material.**
The team selected `com.ispeak.app` and confirmed the production Node API does not
exist yet. No release key/password was generated. Nothing was uploaded, deployed,
published to Google Play, committed or pushed. No distributable production APK
was built or labeled.

## A–X results

| ID | Requested finding | Result |
| --- | --- | --- |
| A | Android release readiness | Identity/configuration preparation implemented; signed release remains blocked pending private key/configuration. Deployed API/physical verification also pending. |
| B | Original application ID | `com.example.ispeak`; original namespace and Kotlin package matched it. |
| C | Final application ID | **com.ispeak.app**, explicitly selected by the team in this task. |
| D | Namespace/package changes | Application ID and namespace now share the selected constant. MainActivity moved to `android/app/src/main/kotlin/com/ispeak/app/MainActivity.kt` and declares `package com.ispeak.app`. `.MainActivity` resolves correctly; no Firebase/deep links found; Dart package unchanged. |
| E | VersionName/versionCode | **1.0.0 / 1**, existing `pubspec.yaml: 1.0.0+1` intentionally retained. Locally found earlier APKs use the old ID/code 1; external final-ID distribution history is not known. Confirm before first distribution, increment if an existing final-ID release requires it. |
| F | Release signing configuration | `android/key.properties` required; all four nonblank/non-placeholder values required; readable keystore/private-key alias/passwords/non-debug valid certificate checked. Release signingConfig only, explicitly non-debuggable, no debug fallback. Debug still builds successfully. Positive team-key signing not tested. |
| G | Keystore status | **TEAM MUST CREATE** or privately provision the intended existing team key. None is configured or located in this repository. Exact interactive keytool workflow and two-backup guidance are documented; no secrets created. |
| H | Secret/Git hygiene | Properties, keystores/private-key formats and build outputs ignored; added all APK/AAB patterns. No tracked key.properties/JKS/keystore/APK/AAB files. New debug APK contained no keystore/properties/.env/private-key file entries. No signing values printed. |
| I | Production API behavior | Release Gradle gate requires exactly one explicit HTTPS API_BASE_URL before release tasks execute. Missing/empty/duplicate, HTTP, malformed, credential/query/fragment, localhost/local DNS and literal private/loopback/link-local/ULA/carrier-NAT targets rejected. Dart development/runtime behavior unchanged. Public-host DNS/service validity still requires deployed verification. |
| J | Permissions | INTERNET and RECORD_AUDIO; no broad storage permissions. Merged debug APK additionally has AndroidX's signature-level `com.ispeak.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. Record plugin's hasPermission defaults to requesting runtime permission; physical/authenticated recording prompt not tested. |
| K | Flutter analyzer | **PASS — no issues**, 69.2 s. |
| L | Complete Flutter tests | **336 passed**, complete existing suite, no coverage reduction. Includes existing fullscreen/keyboard/responsive/reliability/authentication regressions. |
| M | Signed APK | **NOT BUILT — release keystore/configuration absent.** `assembleRelease --dry-run` correctly fails its signing guard with a synthetic HTTPS configuration. Separate debug build succeeded in 107.5 s, NOT FOR DISTRIBUTION. |
| N | AAB | No artifact built. `bundleRelease --dry-run` signing guard verified; actual signed AAB build not attempted without the team key. |
| O | Signature verification | Intended release certificate NOT VERIFIED. Debug validation APK verifies using APK v2 and Android Debug certificate. The preexisting release-named APK also uses Android Debug and cannot be treated as a current production release. |
| P | APK identity/content | New **debug-only** APK: `com.ispeak.app`, MainActivity correct, version 1.0.0/code 1; synthetic `https://api.example.invalid/api` found in compiled kernel; signing/private files absent. Actual release content/API/certificate not verified. Debug intentionally retains development behavior and is not evidence that a release APK contains no development strings. |
| Q | Installation | Debug-only install/launch/splash/login/keyboard/fullscreen smoke PASS on temporary read-only Pixel_9a API 36. Initial System UI timeout recovered. No persistent app data changed; emulator stopped. Signed-release/physical/microphone/authenticated service checks NOT TESTED. |
| R | Upgrade test | **NOT TESTED — no compatible prior release artifact.** No app uninstall/data clearing or forced upgrade. |
| S | APK filename | No production distribution file exists. Conditional future name: `ispeak-v1.0.0-build1.apk`, only if verified signed version remains 1.0.0/code 1. Current validation artifact is `build/app/outputs/flutter-apk/app-debug.apk`, explicitly NOT FOR DISTRIBUTION. |
| T | SHA-256 | **Production signed APK checksum unavailable.** Debug validation SHA-256 is recorded below for evidence only; do not use it on the landing page. |
| U | Production/configuration files changed | Exact list below. No scoring/authentication/backend/resource/UI application logic changed. |
| V | Documentation/test files changed | Exact list below; preexisting untracked UAT_READINESS.md preserved without editing. |
| W | Remaining limitations | Missing team key/configuration; intended certificate/signing verification; real production API; signed APK/AAB contents; physical mic/fullscreen/keyboard/upgrade UAT. SDK doctor reports some licenses unaccepted, though required installed tooling built the debug APK. No license acceptance or tooling/dependency upgrade performed. |
| X | Deployment status | **BLOCKER REMAINS** for the complete signed-release gate. Cannot yet claim only production API/physical UAT pending, because release signing and the actual signed artifact are still unverified. Identity/configuration sub-work is implemented and locally verified. |

## Exact changed files

Production/configuration:

- `.gitignore`: added APK/AAB exclusion; existing key/properties/build exclusions preserved.
- `android/app/build.gradle.kts`: selected identity, complete signing validation, pre-build API gate, explicit non-debuggable release, configuration-only validation tasks.
- `android/app/src/main/kotlin/com/example/ispeak/MainActivity.kt` → `android/app/src/main/kotlin/com/ispeak/app/MainActivity.kt`: package/path rename only.
- `android/app/src/release/AndroidManifest.xml` (new): explicitly disables release cleartext traffic.

Documentation/tests/tools:

- `ANDROID_RELEASE.md` (new): team keytool workflow, private properties, backup/recovery, build/signature/content verification, version decision and landing-page handoff.
- `ANDROID_RELEASE_VERIFICATION.md` (new): this report.
- `DEPLOYMENT.md`: mobile-release instructions updated for selected identity and actual prerequisites; other deployment sections preserved.
- `scripts/check_android_release.ps1` (new): repeatable real-Gradle configuration checks; no keys/artifacts created.

`pubspec.yaml`, all Dart application/test files, API/authentication/scoring/resource
logic, main/debug/profile manifests and unrelated UI were not changed. Existing
`UAT_READINESS.md` remained untouched. The initial working tree had only that
untracked document; no reset/restore/stash/revert/discard operations were used.

## Guard verification and hardening audit

**26 actual Gradle checks passed, zero failed**, including missing/empty/duplicate
API defines, malformed Base64/URI, HTTP, localhost/subdomain/local DNS, short and
normal loopback, emulator/LAN/link-local/carrier-NAT IPv4, IPv6 loopback/ULA,
userinfo/query/fragment and positive synthetic HTTPS validation. Missing signing,
APK/AAB release-task refusal and missing release API guards passed. All checks
ran offline and produced no release artifacts. The positive URL case validates
configuration only; it does not contact the placeholder or establish readiness.

The first configuration attempt encountered a task-name collision with Flutter's
existing checkSigningConfiguration. Project-specific names resolved it. An early
short-loopback test expected a local-network error, while Java URI safely rejected
the abbreviated host as malformed HTTPS; that test expectation was corrected.
The final full 26-case run passed. Signing-file values, passwords/alias/certificate
checks are implemented and compiled, but no positive private-keystore test was
performed because the team key is absent.

Toolchain: Flutter 3.41.2, Dart 3.11.0, Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20,
JDK 21.0.9; Java/Kotlin bytecode target 17. Debug APK minSdk 24/targetSdk 36.
Existing Kotlin jvmTarget/Gradle deprecation warnings remain; no unrelated upgrade
was applied. Flutter's existing release shrinking/R8 defaults are preserved.
Backup behavior remains the platform default and no network-security/backup XML
redesign was introduced. Release cleartext is explicitly false; debug/profile
cleartext remains true. Portrait up/down, immersiveSticky, safe-inset and keyboard
restoration Dart code is unchanged. Debug installation validates the native rename
but cannot substitute for a real signed release or physical-device behavior.

## Artifact evidence and handling

Debug validation artifact SHA-256:

```text
67114735A70520993F95EFD5A77B77126C37A367F4A0D76DFB23F4A7B9512AB3
```

**DEBUG ONLY — NOT FOR DISTRIBUTION; not a landing-page checksum.** Its public
Android Debug certificate SHA-256:

```text
931f2c5d865560ee9aa5135a098ac47d45bee3d892cbd08a0b6aeeccb6d6d913
```

The old release-named APK has this debug certificate and the old com.example.ispeak
identity. It was not renamed, uploaded or substituted as release evidence. No
signed production artifact or production checksum was fabricated. APK inspection
confirmed the synthetic URL in debug's compiled kernel and no private signing-file
entries; this is a bounded file/configuration inspection, not a complete binary
security audit. The exact current production endpoint is still unavailable.

The emulator smoke used port 5580, read-only/no-snapshot/headless flags and a first
install without replacing an existing final-ID app. No credentials were entered or
submitted. System UI initially timed out, then recovered and showed the fullscreen
onboarding prompt. After dismissal, splash/login appeared; input_method reported
mInputShown=true then false, login remained visible and the app PID stayed alive.
The emulator was killed at the end. No signed-release or microphone UAT claim is
made from these debug-only observations.

`git diff --check` passed. Git emitted existing LF/CRLF conversion notices, not
whitespace errors. `git check-ignore` confirmed properties/keystores/build/APK/AAB
exclusions and `git ls-files` found no private signing or artifact candidates.
Evidence/logs are ignored under `.uat-work/android-release` and `*.local.log`.

Landing-page handoff remains pending: actual signed filename, version/code,
approved release date, final signed APK SHA-256, download URL and optional QR
target must come from the real-API verified artifact. No landing page was edited.

References: [Flutter Android release/signing](https://docs.flutter.dev/deployment/android),
[Android signing and key preservation](https://developer.android.com/studio/publish/app-signing),
[application ID/namespace](https://developer.android.com/build/configure-app-module),
[version codes](https://developer.android.com/studio/publish/versioning).

## Private-signing continuation — 2026-10-09

The current working tree was inspected and preserved. Neither private
`android/key.properties` nor the documented home-directory team keystore exists;
no workspace keystore was found outside generated build outputs. The team has
been asked to run the existing interactive keytool command and configure the
private properties locally. No passwords or signing keys were generated, read
into reports, or requested through chat. Signing remains blocked on that action.

| Requested verification | Current result |
| --- | --- |
| A. Team keystore | NOT CREATED by this task; documented location absent |
| B. Signing configuration | Implemented; positive private-key validation pending |
| C. key.properties | Absent; team must configure privately |
| D. Git hygiene | Properties, JKS/keystore, APK/AAB ignored; no matching tracked files; nothing staged; diff check passed |
| E. Signed APK build | NOT RUN — team key/configuration absent |
| F. Signed AAB build | NOT RUN — team key/configuration absent |
| G. Release signature | NOT VERIFIED — no new signed release artifact |
| H. ID/version | Source remains com.ispeak.app / 1.0.0 / code 1; release binary pending |
| I. Signed-release emulator install | NOT TESTED; prior debug smoke is separate evidence |
| J. Signed APK SHA-256 | UNAVAILABLE; no debug or stale APK hash substituted |
| K. Artifact classification | Future placeholder-API artifacts: TEST RELEASE — NOT FOR DISTRIBUTION |
| L. Remaining blockers | Team signing setup and artifact checks; production API; physical microphone/UAT; external version/distribution history |
| M. Readiness | BLOCKER for verified signed release; cannot yet move to IMPLEMENTED — PRODUCTION API / PHYSICAL UAT PENDING |

The previous analyzer, 336 frontend tests and 26 release-guard checks remain
the existing verification evidence; they were not rerun for this documentation
continuation. `ANDROID_RELEASE.md` now gives explicit placeholder-API APK/AAB
commands and AAB certificate verification alongside the existing APK procedure.
Its backup procedure requires at least two encrypted team-controlled copies,
password-manager storage, recorded alias/public fingerprint and a readable backup.
Actual backup completion has not been verified. No deployment, publication,
commit, push or existing artifact replacement occurred.
