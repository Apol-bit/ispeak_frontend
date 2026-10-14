# Android identity and release signing

The team explicitly selected **com.ispeak.app** on 2026-10-09. Application ID,
namespace and Kotlin MainActivity now use that identity. No organization/domain
name was inferred. The manifest's `.MainActivity` resolves through the namespace;
no Firebase configuration, deep links or package-sensitive tests were found.
The Dart package remains `ispeak`.

**No distributable production APK/AAB is available.** The production Node API is
not deployed, and no team release keystore or `android/key.properties` is
configured. A debug-signed APK or a placeholder-API build must never be distributed
as production. An existing release-named APK was inspected: it has the old
`com.example.ispeak` identity and an Android Debug certificate. It is not evidence
of a current signed production release and was not republished or renamed.

## Version decision

Keep the existing `pubspec.yaml` value **1.0.0+1**: versionName 1.0.0, versionCode 1.
This is the intended first UAT/release under the newly selected ID, not an
automatic version change. Locally available earlier debug/release-named APKs
use `com.example.ispeak`, version 1.0.0/code 1. They cannot serve as compatible
upgrade artifacts for the new ID. The team must confirm external distribution
history before distribution; if the selected ID already has a distributed build,
use its signing key and a versionCode greater than the latest distributed code.
Never uninstall/clear user data merely to force an upgrade test.

## Team-controlled key creation (not executed by this task)

**TEAM MUST CREATE** or privately provision the intended existing release key.
Do not send passwords or private keys through chat, source control or public logs.
Use the JDK reported by `flutter doctor -v`. On this machine its directory is
`D:\Android\Android Studio\jbr`.

The following team-run command prompts interactively; passwords are not command
arguments. Use the team's real certificate-owner details when prompted. Confirm
that no intended existing signing key is being replaced.

```powershell
$signingDirectory = Join-Path $env:USERPROFILE 'iSpeakSigning'
$releaseKeyPath = Join-Path $signingDirectory 'ispeak-release.jks'
if (Test-Path -LiteralPath $releaseKeyPath) { throw 'Existing key found. Verify and reuse it; do not replace it.' }
New-Item -ItemType Directory -Path $signingDirectory -Force | Out-Null
& 'D:\Android\Android Studio\jbr\bin\keytool.exe' -genkeypair -keystore $releaseKeyPath -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias ispeak-release
```

No keystore, signing password or private key was generated during this task.
If a compatible key already exists elsewhere, use it instead of creating another.
For directly distributed APK updates, preserving the signing identity is critical;
losing it can prevent compatible updates. Play app-signing/upload-key recovery
is a separate workflow, not a substitute for preserving the direct APK key.

Back up the keystore in **at least two trusted team-controlled locations**, with
encrypted storage and access restricted to release maintainers. Keep passwords
in a team-approved password manager outside Git. Record the alias and public
certificate SHA-256 fingerprint, and verify a backup can be read before release.
Do not place the only key copy on the build machine.

## Local private signing configuration

Copy `android/key.properties.example` to `android/key.properties`, then edit it
privately. All four fields are required:

```properties
storePassword=REPLACE_WITH_SECRET
keyPassword=REPLACE_WITH_SECRET
keyAlias=ispeak-release
storeFile=REPLACE_WITH_ABSOLUTE_PRIVATE_KEYSTORE_PATH
```

These are placeholders, not usable signing credentials. Use an absolute path
with forward slashes on Windows, such as the team's private home-directory
keystore path. Relative paths resolve from `android/app`. Do not print the real
file or use signing passwords as shell flags. Avoid Gradle `--debug` diagnostics
or publishing signing reports/logs from a machine holding private credentials.

Git ignores `key.properties`, keystores/private-key formats, build outputs and
all APK/AAB files. The example is safe to track. Gradle release tasks require
the real file, nonblank/non-placeholder values, an existing readable keystore,
the requested private-key alias/passwords and a valid non-debug certificate.
Missing/invalid signing data fails with messages that do not include passwords.
Release uses only the release signingConfig; there is no debug-signing fallback.
Debug builds keep the Android debug configuration.

## API configuration and configuration-only checks

Release builds require exactly one explicit `API_BASE_URL` through Flutter's
`--dart-define`. Gradle decodes Flutter's Base64 `dart-defines` before running
release tasks. Missing/empty/duplicate values, malformed URLs, HTTP, embedded
credentials, query/fragment values, localhost/local DNS names, literal LAN,
loopback/link-local/ULA and carrier-NAT addresses are rejected. The build does
not resolve DNS; the approved public hostname and actual service must still be
verified after deployment. API_BASE_URL is public configuration, never a secret.

No production URL has been selected. `https://api.example.invalid/api` is used
only as a clearly identified synthetic configuration-test input. It is not a
deployed API, and any debug build using it is **NOT FOR DISTRIBUTION**. The
validator accepting that input is not evidence of cloud connectivity. Existing
Dart runtime missing/HTTPS guards and development URL behavior are unchanged.

Run the guard matrix without producing artifacts or creating signing secrets:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\check_android_release.ps1 -JavaHome 'D:\Android\Android Studio\jbr'
```

ExecutionPolicy Bypass applies only to that trusted script process; it changes
no machine-wide policy. Results/logs are ignored under `.uat-work/android-release`.
The script tests URL handling and, while `key.properties` is absent, the signing
and APK/AAB release-task failure gates. It never replaces key.properties.

## Build and artifact verification once team prerequisites exist

For the requested local signed-build verification while the API is unavailable,
the team must first complete the interactive key creation and private properties
setup above. Then use these configuration-only commands from `ispeak_frontend`:

```powershell
$env:JAVA_HOME = 'D:\Android\Android Studio\jbr'
& 'D:\flutter\bin\flutter.bat' build apk --release --no-pub --dart-define=API_BASE_URL=https://api.example.invalid/api
& 'D:\flutter\bin\flutter.bat' build appbundle --release --no-pub --dart-define=API_BASE_URL=https://api.example.invalid/api
```

Both resulting artifacts must be classified **TEST RELEASE — NOT FOR
DISTRIBUTION**. The endpoint is synthetic and cannot verify backend functions.
Do not use the preexisting release-named APK as evidence if a build fails.
Only verify and checksum artifacts after their corresponding builds succeed.
For the AAB, also run the JDK's `jarsigner -verify -verbose -certs` against
`build/app/outputs/bundle/release/app-release.aab`, checking that its signer
matches the intended team certificate. APK signing is checked with `apksigner`
below. AAB verification does not replace APK installation testing.

Use the approved real deployed HTTPS API for the eventual distributable artifact.
Do not use the documentation/test placeholder. No `ISPEAK_APPLICATION_ID`
override is needed: the selected identity is explicit in Gradle and Kotlin.

```powershell
flutter.bat analyze
flutter.bat test
# Set this process variable to the team's approved real deployed URL first.
flutter.bat build apk --release "--dart-define=API_BASE_URL=$env:ISPEAK_RELEASE_API_URL"
# Optional AAB; do not publish or upload it.
flutter.bat build appbundle --release "--dart-define=API_BASE_URL=$env:ISPEAK_RELEASE_API_URL"
```

An unset variable is rejected by the build guard. Validate before naming or
distributing an artifact:

```powershell
$androidTools = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools\36.1.0'
& (Join-Path $androidTools 'apksigner.bat') verify --verbose --print-certs build\app\outputs\flutter-apk\app-release.apk
& (Join-Path $androidTools 'aapt.exe') dump badging build\app\outputs\flutter-apk\app-release.apk
Get-FileHash -LiteralPath build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
```

Use the installed build-tools version on other machines. Compare the public
certificate SHA-256 against the team's intended certificate, reject Android Debug,
and confirm package `com.ispeak.app` plus actual version/permissions. Verify the
compiled approved endpoint and manifest contents; a valid signature alone does
not establish API correctness or safe distribution. Do not modify the APK after
its final checksum. Do not log or package private key/properties files.

Expected source permissions are INTERNET and RECORD_AUDIO, without broad storage
permissions. AndroidX can add its generated signature-level dynamic-receiver
permission. The record plugin requests microphone access through
`hasPermission(request: true)` before recording. Physical permission behavior
and headset/device variations still need device UAT.

Release is explicitly non-debuggable and blocks cleartext traffic. Debug/profile
retain their existing cleartext behavior. Existing Flutter-plugin shrinking/R8
defaults are preserved; no new optimization or version upgrade was enabled.
Backup behavior remains the platform default; no backup/security XML or storage
behavior was redesigned. Existing portrait orientations, immersiveSticky calls,
safe insets and keyboard/background restoration remain unchanged in Dart.
Modern Android system-UI behavior must be checked on actual target devices.

## Device, upgrade and landing-page handoff

Only install a properly classified artifact on an authorized test device. Check
launch/login screen, microphone prompt, portrait/fullscreen/insets/keyboard and
immediate crashes. No physical Android device was connected. A disposable,
headless, read-only Pixel_9a emulator (Android API 36) was started for a debug-only
smoke test, without replacing an existing final-ID app. Installation succeeded;
splash/login rendered, the keyboard opened/dismissed, fullscreen returned and the
app remained running. An initial emulator System UI timeout and fullscreen
onboarding prompt recovered without source changes. No credentials were entered,
no authentication submitted, and no microphone flow was exercised because the
real authenticated API is unavailable. The emulator was stopped without saving
snapshots or persistent app-data changes. This is not signed-release/physical UAT.
No compatible prior final-ID release artifact was found, so the upgrade test is
**NOT TESTED — no compatible prior release artifact**.

After the final real-API signed build is verified, the intended filename is
`ispeak-v1.0.0-build1.apk` if the actual built version is still 1.0.0/code 1.
Never rename a debug, unsigned or stale APK as production. The landing-page handoff
must include actual filename, verified version/code, team-approved release date,
SHA-256, final download URL and optional QR target. Those values are not yet
available. This task does not edit the landing page, upload artifacts, publish to
Google Play, deploy, commit or push.
