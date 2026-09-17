# iSpeak production configuration

This document prepares the four iSpeak components for deployment. It contains
no credentials and none of the commands below deploy an environment.

## 1. Required infrastructure

- An HTTPS API domain for the Node service.
- A private network endpoint for `ispeak_python-backendV2`; do not expose the
  inference service directly to the public internet.
- A managed MongoDB deployment with TLS, authentication, restricted network
  access, automated backups, and a tested restore procedure.
- Private object storage for user recordings and validator reference audio.
  Select the provider before implementing its adapter in
  `ispeak_backend/services/storageService.js`.
- Hosting for the admin web build and sufficient CPU/GPU, memory, and disk for
  the approximately 1.5 GB speech model.

The legacy `ispeak_python-backend` must not be deployed.

Before implementing object storage, supply the provider/API (for example an
S3-compatible API, GCS, or Azure Blob), region, private bucket/container name,
endpoint if applicable, workload identity/service-account method, and retention
policy. Configure credentials in the host's secret manager. Do not paste them
into this document. The current adapter is local-only: a selected provider needs
upload/write support, streaming reads, deletion, and route integration. Reference
audio access must remain authenticated; user recording keys must stay private.

## 2. Node API

Configure these values in the hosting platform, never in Git:

| Variable | Production value |
| --- | --- |
| `MONGO_URI` | Managed MongoDB TLS URI |
| `JWT_SECRET` | Cryptographically random secret, at least 32 characters |
| `JWT_EXPIRES_IN` | Token lifetime, default `7d` |
| `JWT_ISSUER` | Stable issuer, default `ispeak-api` |
| `JWT_AUDIENCE` | Stable audience, default `ispeak-clients` |
| `TERMS_VERSION` | Current published terms version, currently `1.0` |
| `NODE_ENV` | `production` |
| `CORS_ORIGINS` | Comma-separated HTTPS admin origins |
| `PYTHON_BACKEND_URL` | Private V2 service URL |
| `PYTHON_TIMEOUT_MS` | Inference timeout, default `300000` |
| `PORT` | Platform-assigned or configured API port |
| `STORAGE_DRIVER` | Provider adapter name; `local` is development-only |
| `RECORDING_RETENTION_DAYS` | Recording lifetime, default `30` |

`npm start` starts the service. `/health` returns 200 only after MongoDB is
connected. Production startup rejects missing security configuration and
rejects local storage unless `ALLOW_LOCAL_STORAGE_IN_PRODUCTION=true` is set as
an explicit acknowledgement for a single-instance server with persistent disk.

The current authentication limiter is process-local and uses the direct client
IP. Configure per-client limits at the trusted reverse proxy before production;
multiple API replicas need shared limits. Do not blindly trust arbitrary
forwarded IP headers. Match the proxy upload limit and inference request timeout
to Node/Python settings.

## 3. Python V2

Start with `start_backend.ps1` on Windows or:

```text
python -m uvicorn fastapi_backend:app --host <private-bind-address> --port <port>
```

Required production configuration:

| Variable | Production value |
| --- | --- |
| `ISPEAK_ENV` | `production` |
| `ISPEAK_HOST` | Private bind address, commonly `0.0.0.0` in a container |
| `ISPEAK_PORT` | Internal service port |
| `ISPEAK_CORS_ORIGINS` | Explicit trusted origins; wildcard is rejected |
| `ISPEAK_MAX_UPLOAD_MB` | Must match Node, default `25` |
| `ISPEAK_MAX_CONCURRENT_INFERENCES` | Capacity-tested worker limit |
| `ISPEAK_QUEUE_TIMEOUT_SECONDS` | Maximum inference queue wait |
| `ISPEAK_MODEL_PATH` | iSpeak v5 adapter directory |
| `ISPEAK_BASE_MODEL_PATH` | Local Whisper base-model directory |

## 4. Mobile release

Choose and register an organization-owned Android package ID. Then create a
private upload keystore and copy `android/key.properties.example` to
`android/key.properties`. Both the real properties file and keystore are
ignored by Git.

Supply `storeFile`, `storePassword`, `keyAlias`, and `keyPassword` locally. Use an
absolute keystore path with forward slashes on Windows; relative paths resolve
from `android/app`. Keep passwords and the keystore outside the repository. The
package ID must match the intended Play Console application. Current version is
`1.0.0+1`; use a higher version code when updating an existing listing.

Build only after supplying those values:

```text
$env:ISPEAK_APPLICATION_ID='com.yourorg.ispeak'
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com/api
```

Replace the example domain and package ID. Release API URLs must use HTTPS, and
Gradle refuses release tasks that still use `com.example.ispeak` or have no
release signing file. Update the `version:` value in `pubspec.yaml` before each
store release (`versionName+versionCode`).

## 5. Admin web

```text
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com/api
```

Configure the web host to serve `index.html` for client-side routes, enable
HTTPS/security headers, and add only that origin to Node `CORS_ORIGINS`.

## 6. Required pre-deployment verification

Run all automated suites, validate Admin/Validator permissions with real test
accounts, test English/Filipino/Taglish recordings on physical Android devices,
exercise retention and account deletion against the selected object store, and
restore a MongoDB backup into a non-production environment.

The builds verified during this audit use an example API domain and are only
compile checks. Rebuild mobile and admin with the real HTTPS API URL before any
release. See `DEPLOYMENT_READINESS.md` for the recorded results and remaining gates.
