# Deployment readiness — 2026-09-16

**Overall status: NOT READY.** No deployment was performed.

Completed tests from September 15 are retained below. On September 16, the
remaining Android artifact and release-build checks were completed without
rerunning the completed suites.

## Fixed blockers

- Node JWT signature/expiry validation, live account-status checks, route
  ownership enforcement, Admin/Validator role enforcement, and 401/403 handling.
- Authenticated responses omit password hashes and private recording paths;
  upload ownership comes from the token, not a submitted user ID.
- Mobile secure token persistence, authenticated API calls, session validation,
  expiry redirects, logout cleanup, and request timeouts. Admin requests carry
  tokens and validate the session/role against the backend.
- Signup terms acceptance/version persistence and input validation; login/signup
  rate limiting; normalized account identifiers.
- Environment-based production settings, explicit CORS, release HTTPS API URL
  requirement, health checks, startup validation, and graceful Node shutdown.
- Local storage abstraction, private audio access, retention scheduling, account
  deletion cleanup, and production guard against accidental local storage use.
  Reference-audio replacement preserves the old file until the DB update succeeds.
- Production standardized on Python V2, with legacy-production prohibition,
  inference concurrency control, media-signature validation, language propagation,
  and actual decoded duration instead of file-size estimation.
- Dependency remediation with model-loading, transcription, metrics and unit-test
  verification; unused ONNX-related dependencies removed after checking usage.
- Taglish free-practice selection and inclusion in the labelled Filipino/Taglish
  progress group, admin reference-audio upload, narrow modal layouts, and meaningful
  Node authorization plus live integration tests.
- Android release signing configuration without a debug-signing fallback,
  external package-ID requirement, ignored private signing files, and version
  values sourced from pubspec. Mobile/admin analyzer findings were resolved.

## Remaining blockers

1. **Android release identity/signing:** final organization-owned package ID and
   private upload keystore configuration are absent. The release AAB build fails
   at the intended package-ID guard. A signed release AAB has not been produced
   or tested. No final ID or signing secret was invented.
2. **Production storage:** only the local adapter is implemented. Provider choice,
   private bucket/container, region/endpoint and workload credentials are required
   before implementing and testing object-store upload/read/delete integration.
3. **Production infrastructure:** real HTTPS API/admin domains, hosting/network
   configuration, managed MongoDB credentials/TLS/backups, JWT secret, private
   Python endpoint, and model/runtime capacity are not configured or verified.
4. **Dependency gate:** the last pip-audit run reports `accelerate 1.14.0`
   (`PYSEC-2026-3804`, no listed fix) and `transformers 5.5.0`
   (`PYSEC-2026-3929`, listed fix `5.10.0`). Package metadata checked during the
   remediation marked that Transformers release yanked. Resolve with a supported
   compatible fix or document an explicit risk assessment before release.
5. **Production validation:** signed-app physical-device recording tests,
   storage retention/deletion tests, Mongo backup restore, and inference capacity
   tests remain outstanding. Local automated results do not establish these.

Password recovery is out of scope for the current thesis version/UAT: no explicit
requirement was found in the available documentation. Existing controls only show
messages; no recovery/email service is required for this UAT scope. See
`THESIS_UAT_SCOPE.md` for evidence and limitations. Admin browser bearer-token
storage remains accessible to page JavaScript; configure hosting security headers
and review the session policy.

## Manual actions required

- Provide the final Android package ID and configure the upload keystore path,
  alias and passwords in ignored `android/key.properties`. Do not send secrets
  through source control. Confirm Play Console ownership and version code.
- Select the storage provider and private bucket/container configuration described
  in `DEPLOYMENT.md`; provision credentials in the hosting secret manager.
- Supply API/admin domains, hosting choices, private Python routing and capacity,
  MongoDB connection configuration, JWT secret and allowed CORS origins.
- Review the two unresolved dependency advisories and choose a tested remediation
  or explicit risk disposition.
- Perform the device and production-infrastructure checks listed above.

## Tests

| Check | Result | Evidence / limit |
| --- | --- | --- |
| Flutter analyzer | PASS | No issues found |
| Flutter tests | PASS | 11 tests, including secure storage, terms and responsive layouts |
| Android debug APK | PASS | Artifact generated September 15; manifest readable and APK v2 signature verifies September 16; version 1.0.0 / code 1 |
| Android release AAB | FAIL | `bundleRelease` exited 1: organization-owned package ID required; private signing configuration also absent |
| Admin analyzer | PASS | No issues found |
| Admin tests | PASS | 2 tests |
| Admin production web build | PASS | Local release compile with example HTTPS API domain; must rebuild for real endpoint |
| Node syntax checks | PASS | Changed Node modules parsed successfully |
| Node tests | PASS | 8 authorization tests |
| Python V2 tests | PASS | 12 analysis-component tests after dependency changes |
| Python dependency consistency | PASS | pip check: no broken requirements |
| Python vulnerability scan | FAIL | 2 remaining advisories listed above |
| Python startup / health | PASS | iSpeak_v5 speech model and local filler classifier available |
| Python transcription / metrics | PASS | Real AAC sample returned transcript and metrics; decoded duration 16.765 seconds |
| Media validation | PASS | Disguised non-audio WAV rejected with HTTP 400 |
| API / Mongo integration | PASS | Live Node → MongoDB → Python V2 flow on isolated local services |
| Authentication / RBAC / admin authorization | PASS | User/Admin/Validator permissions, token expiry, banned-user rejection and protected routes exercised |
| IDOR / upload ownership | PASS | Cross-user access rejected; submitted userId cannot override token owner |

Unperformed device, release-signing, cloud-storage and production-capacity checks
are open gates, not PASS results. Test services were local and isolated.

## Final deployment steps

1. Resolve package/signing, storage, infrastructure and dependency inputs above.
2. Implement the chosen object-store adapter and route integration; verify private
   access, replacement, deletion, retention and failure recovery in staging.
3. Configure the production secrets/environment from `DEPLOYMENT.md`; keep Python
   private, provision model files, establish TLS, backups and proxy rate limits.
4. Rerun affected tests after these changes. Exercise production-equivalent
   authentication, all three languages, storage and backup restore in staging.
5. Build admin web and the signed Android AAB with the actual HTTPS API URL and
   final package ID. Verify the release signature/version and physical-device flows.
6. Review remaining gates and obtain explicit deployment approval. Only then
   follow the selected hosting/store release process, check health and smoke
   tests, and monitor logs/errors with a rollback artifact available.

The temporary audit MongoDB directory and two generated WAV fixtures were removed
after confirming the audit service ports were not listening. They contained only
disposable test data; no production database or user audio was removed.
