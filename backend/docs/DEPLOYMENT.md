# WAR ROOM — Backend Deployment to Google Cloud

This is the complete, battle-tested runbook for deploying the WAR ROOM backend to **Google Cloud Run** via **Cloud Build**. It documents every step, including real problems encountered during the first deployment and how to fix them.

**Live service:** `https://war-room-backend-rmkrknzoaa-uc.a.run.app`

---

## Architecture

```
GitHub push to main
       │
       ▼
GitHub Actions (.github/workflows/deploy-backend.yml)
       │  OR
       ▼
gcloud builds submit (manual)
       │
       ▼
Cloud Build (backend/cloudbuild.yaml)
  ├── Step 1: docker build → gcr.io/PROJECT/war-room-backend:SHA
  ├── Step 2: docker push → Container Registry
  └── Step 3: gcloud run deploy → Cloud Run (us-central1)
                                        │
                                        ▼
                              Secrets pulled from Secret Manager
                              (GOOGLE_API_KEY, ELEVENLABS_API_KEY,
                               LIVEKIT_URL, LIVEKIT_API_KEY,
                               LIVEKIT_API_SECRET)
```

---

## Prerequisites

Before you start, you need:

- A **Google Cloud project** with billing enabled
- The **gcloud CLI** installed — [install guide](https://cloud.google.com/sdk/docs/install)
- A **service account JSON key** for the project (e.g. `backend/gcp-service-account.json`)
- Your **personal Google account** that owns the project (for one-time IAM setup)
- All backend API keys ready: Google/Gemini, ElevenLabs, LiveKit (URL + API key + secret)

---

## Step 1 — Enable Required GCP APIs

> **Important:** This must be done with your personal Google account (project Owner/Editor), not a service account. Service accounts cannot enable APIs by default.

Enable all APIs in one command:

```bash
gcloud auth login   # log in with your personal Google account (opens browser)
gcloud config set project YOUR_PROJECT_ID

gcloud services enable \
  cloudresourcemanager.googleapis.com \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  containerregistry.googleapis.com \
  secretmanager.googleapis.com
```

Or enable them one by one via the Cloud Console:

| API | Link |
|-----|------|
| Cloud Resource Manager | [Enable](https://console.cloud.google.com/apis/library/cloudresourcemanager.googleapis.com) |
| Cloud Build | [Enable](https://console.cloud.google.com/apis/library/cloudbuild.googleapis.com) |
| Cloud Run | [Enable](https://console.cloud.google.com/apis/library/run.googleapis.com) |
| Container Registry | [Enable](https://console.cloud.google.com/apis/library/containerregistry.googleapis.com) |
| Secret Manager | [Enable](https://console.cloud.google.com/apis/library/secretmanager.googleapis.com) |

> **Why Cloud Resource Manager?** Even basic gcloud commands (like `gcloud config set project`) query the Resource Manager API to validate the project. If it is disabled, almost everything else fails first.

---

## Step 2 — Grant IAM Roles to the Service Account

The deployment service account needs these 5 roles. Run this with your personal account (the one that owns the project):

```bash
# Set your values
PROJECT_ID="YOUR_PROJECT_ID"
SA="YOUR_SERVICE_ACCOUNT@YOUR_PROJECT_ID.iam.gserviceaccount.com"

for role in \
  roles/cloudbuild.builds.editor \
  roles/run.admin \
  roles/storage.admin \
  roles/secretmanager.admin \
  roles/iam.serviceAccountUser; do
  echo "Granting $role..."
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA" \
    --role="$role" \
    --condition=None
done
```

> **Why `--condition=None`?** If the project IAM policy already has conditional bindings (set via the Console), running `add-iam-policy-binding` without this flag fails with:
> `Adding a binding without specifying a condition to a policy containing conditions is prohibited in non-interactive mode.`

| Role | Why it's needed |
|------|----------------|
| `cloudbuild.builds.editor` | Submit and view Cloud Build jobs |
| `run.admin` | Create and update Cloud Run services |
| `storage.admin` | Push Docker images to Container Registry (uses GCS) |
| `secretmanager.admin` | Create and read secrets in Secret Manager |
| `iam.serviceAccountUser` | Allow Cloud Run to run as the compute service account |

---

## Step 3 — Store API Keys in Secret Manager

Fill in `backend/.env` with your real API keys (use `backend/.env.example` as a template), then run the setup script. It reads values from `.env` automatically:

```bash
./scripts/deploy/setup-gcp.sh --project YOUR_PROJECT_ID
```

This script:
1. Re-enables all required APIs (idempotent — safe to run multiple times)
2. Creates 5 secrets in Secret Manager:
   - `war-room-google-api-key`
   - `war-room-elevenlabs-api-key`
   - `war-room-livekit-url`
   - `war-room-livekit-api-key`
   - `war-room-livekit-api-secret`
3. Grants the Cloud Run compute service account `secretmanager.secretAccessor` on each secret

> **Never commit `backend/.env` or `backend/gcp-service-account.json` to GitHub.** Both are in `.gitignore` already.

To update a secret value later:

```bash
echo -n "new-value" | gcloud secrets versions add war-room-google-api-key --data-file=-
# Then redeploy to pick up the new version
```

---

## Step 4 — Deploy

### Option A: Manual deploy (recommended for first run)

```bash
# From the repo root
bash scripts/deploy/deploy.sh \
  --key backend/gcp-service-account.json \
  --project YOUR_PROJECT_ID
```

Or submit directly with gcloud:

```bash
# Must run from repo root (not inside backend/)
gcloud auth activate-service-account --key-file=backend/gcp-service-account.json --project=YOUR_PROJECT_ID

gcloud builds submit . \
  --config=backend/cloudbuild.yaml \
  --project=YOUR_PROJECT_ID \
  --substitutions=COMMIT_SHA=$(git rev-parse --short HEAD)
```

> **Must run from repo root.** The `cloudbuild.yaml` uses `dir: backend` to set the Docker build context. Running from inside `backend/` breaks this path.

### Option B: Automatic deploy via GitHub Actions

Every push to `main` that touches `backend/**` triggers a deploy automatically. To enable this:

1. Go to [github.com/OkeyAmy/war-room/settings/secrets/actions](https://github.com/OkeyAmy/war-room/settings/secrets/actions)
2. Click **New repository secret**
3. Name: `GCP_SERVICE_ACCOUNT_KEY`
4. Value: paste the entire contents of `backend/gcp-service-account.json`

The workflow file is at `.github/workflows/deploy-backend.yml`.

### Option C: Cloud Build GitHub trigger (push-to-deploy via GCP)

```bash
# First connect the repo in Cloud Console:
# https://console.cloud.google.com/cloud-build/triggers → Connect repository → GitHub → OkeyAmy/war-room

./scripts/deploy/create-github-trigger.sh --project YOUR_PROJECT_ID
```

After this, every push to `main` also triggers a Cloud Build job directly (separate from GitHub Actions).

---

## Step 5 — Verify the deployment

```bash
# Get the service URL
gcloud run services describe war-room-backend \
  --region=us-central1 \
  --project=YOUR_PROJECT_ID \
  --format='value(status.url)'

# Health check
curl https://YOUR_SERVICE_URL/api/health
```

A successful response looks like:

```json
{
  "status": "healthy",
  "service": "war-room-backend",
  "version": "2.0.0",
  "environment": "production"
}
```

---

## Known Issues & Troubleshooting

### ❌ "Cloud Resource Manager API has not been used in project ... before or it is disabled"

**When it happens:** Almost any gcloud command, including `gcloud config set project`.

**Fix:** Enable the Cloud Resource Manager API first — either via the Console link above or with `gcloud services enable cloudresourcemanager.googleapis.com` (using your personal account).

---

### ❌ "PERMISSION_DENIED: Permission denied to enable service"

**When it happens:** When running `gcloud services enable ...` with a service account.

**Fix:** Service accounts cannot enable APIs by default. Run API enablement with your personal Google account (`gcloud auth login`), then switch back to the service account for deployment.

---

### ❌ "Adding a binding without specifying a condition ... is prohibited in non-interactive mode"

**When it happens:** When running `gcloud projects add-iam-policy-binding` and the project already has conditional IAM bindings.

**Fix:** Add `--condition=None` to the command:

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/run.admin" \
  --condition=None
```

---

### ❌ Build upload takes forever (15+ minutes) or times out

**When it happens:** Running `gcloud builds submit` from the repo root without a `.gcloudignore` file.

**Root cause:** The repo contains large directories that should be excluded:
- `node_modules/` — 1.5 GB (frontend dependencies)
- `demo/` — 543 MB
- `backend/data/` — 179 MB

Without `.gcloudignore`, gcloud uploads everything — over 3 GB.

**Fix:** The `.gcloudignore` file at the repo root is already configured. With it, the upload is **79 files / ~1 MB**. Never delete it.

If you ever add new large directories (model weights, datasets, etc.), add them to `.gcloudignore`.

---

### ❌ "The user-provided container failed to start and listen on the port defined provided by the PORT=8080 environment variable"

**When it happens:** Cloud Run deployment succeeds (image pushed) but the revision immediately fails to start.

**Root cause:** Cloud Run injects a `PORT` environment variable (default `8080`) and expects the container to listen on that port. The original Dockerfile hardcoded port `8000`:

```dockerfile
# Old — breaks on Cloud Run
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Fix (already applied):** Use the shell form of `CMD` so environment variables are expanded at runtime:

```dockerfile
# Correct — works on Cloud Run and locally
CMD uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}
```

The `${PORT:-8000}` syntax means: use the `PORT` env var if set (Cloud Run sets it to `8080`), otherwise default to `8000` for local development.

---

### ❌ "secret not found" during Cloud Run deploy

**When it happens:** The `--set-secrets` flag in `cloudbuild.yaml` references a secret that doesn't exist in Secret Manager.

**Fix:** Run `./scripts/deploy/setup-gcp.sh` to create all required secrets. Check they exist:

```bash
gcloud secrets list --project=YOUR_PROJECT_ID
```

You should see all 5 secrets listed.

---

### ❌ Cloud Run returns 500 after deploy

**When it happens:** The service starts but API calls fail.

**Fix:** Check that the Cloud Run compute service account has `secretmanager.secretAccessor` on each secret. The setup script grants this automatically, but you can verify:

```bash
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)')
CLOUD_RUN_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

for secret in war-room-google-api-key war-room-elevenlabs-api-key war-room-livekit-url war-room-livekit-api-key war-room-livekit-api-secret; do
  echo "Checking $secret..."
  gcloud secrets get-iam-policy "$secret" --project=YOUR_PROJECT_ID | grep "$CLOUD_RUN_SA" || echo "  MISSING binding for $CLOUD_RUN_SA"
done
```

---

### ⚠️ Health check shows "degraded" (not all checks pass)

**When it happens:** `/api/health` returns `"status": "degraded"` with some failed checks.

**What this means:** The service is running. Some health check sub-tests (e.g. Firestore health check using a reserved document ID `__health_check__`) are internal implementation issues, not deployment failures. The core API endpoints work correctly.

---

## Security Checklist

- [ ] `backend/.env` is in `.gitignore` ✅
- [ ] `backend/gcp-service-account.json` is in `.gitignore` ✅
- [ ] `.gcloudignore` excludes `.env` and `gcp-service-account.json` ✅
- [ ] All API keys are in Secret Manager, never hardcoded ✅
- [ ] Cloud Run service account only has `secretAccessor` (not full Secret Manager admin) ✅
- [ ] Never commit API keys or service account keys to GitHub ✅

---

## Quick Reference

```bash
# Authenticate with service account
gcloud auth activate-service-account \
  --key-file=backend/gcp-service-account.json \
  --project=war-room-production

# Deploy manually
bash scripts/deploy/deploy.sh \
  --key backend/gcp-service-account.json \
  --project war-room-production

# Get service URL
gcloud run services describe war-room-backend \
  --region=us-central1 --format='value(status.url)'

# Health check
curl https://war-room-backend-rmkrknzoaa-uc.a.run.app/api/health

# View Cloud Run logs
gcloud run services logs read war-room-backend \
  --region=us-central1 --project=war-room-production --limit=50

# Update a secret
echo -n "new-api-key" | gcloud secrets versions add war-room-google-api-key --data-file=-
```
