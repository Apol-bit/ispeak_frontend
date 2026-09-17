# Thesis UAT scope: password recovery

Reviewed: 2026-09-17.

## Decision

Password recovery / Forgot Password is **out of scope for the current thesis
version and controlled UAT**. No explicit requirement for it was found in the
available project documentation. This disposition follows the project owner's
instruction not to implement recovery unless an existing requirement explicitly
requires it.

No formal thesis manuscript, software requirements specification, or approved
requirements matrix was located in the inspected project folder. This finding
therefore applies to the available evidence, not to an unseen thesis document.
Reassess only if an explicit approved requirement is supplied; report the required
minimum functionality for approval before implementation.

## Evidence reviewed

- `../ispeak_backend/README.md`, Features, line 6: authentication is described as
  JWT-based login and signup; password recovery is not listed.
- `../iSpeak_Demo_Script.pdf`, all 14 pages: page 4, "Scene 1: Splash Screen &
  Login", describes login and optional signup, password hashing, tokens, and
  blocked-account handling. Page 8 describes admin login; page 13 describes
  password hashing and role-based access. No password-recovery flow or requirement
  appears. This is a demonstration document with older architecture references,
  not a current formal requirements specification.
- `../Learning Resources (Demo).docx`: sample speech, impromptu challenge, and
  articulation guidance; no account-recovery requirement.
- Available frontend, admin, Node, Python V2, and legacy README/setup/deployment
  documentation: no explicit thesis password-recovery requirement found.
- The earlier recovery recommendation in `DEPLOYMENT_READINESS.md` was an audit
  observation, not evidence of an approved functional requirement. It is
  superseded by this scope decision.

## Existing implementation

- `lib/pages/login_screen.dart`, lines 234-240: "Forgot Password?" displays
  "Password reset feature coming soon" in a SnackBar. It does not initiate a
  recovery request.
- `../ispeak_admin_panel/lib/screens/login_screen.dart`, lines 367-373:
  "Forgot Password?" displays "Contact Super Admin for password reset."
  This message does not establish an implemented admin reset capability.
- `../ispeak_backend/routes/authRoutes.js`, lines 13-15: signup, login, and the
  authenticated current-user endpoint. The inspected auth/user controllers and
  routes contain no password-recovery/reset endpoint. Profile editing and account
  unarchiving are not password recovery.

The existing labels are placeholders, not an implemented feature or an explicit
thesis requirement. Authentication code and both UI controls remain unchanged.

## UAT treatment

- Mark password recovery as **Not applicable / Out of scope**, not PASS, in the
  current thesis UAT feature checklist. Do not advertise self-service reset.
- Use known working test-account credentials for authentication scenarios.
  Forgotten credentials have no supported recovery flow in this version; do not
  assume the admin message provides one or bypass authentication for UAT.
- No email service, external recovery API, reset tokens, dependencies, environment
  changes, or authentication changes are required for this scope decision.
- This does not waive other authentication, security, or deployment gates and
  does not authorize deployment.

## Verification

Documentation and authentication source inspection completed. Only this scope
note and the recovery-specific wording in `DEPLOYMENT_READINESS.md` were changed
for this task. No runtime tests were rerun because executable code and dependency
configuration were not changed. Nothing was deployed.
