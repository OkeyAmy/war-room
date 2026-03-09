#!/usr/bin/env bash
# WAR ROOM — One-time GCP setup for backend deployment
# Run this once before first deploy. Creates Secret Manager secrets and enables APIs.
# Usage: ./scripts/deploy/setup-gcp.sh [--project PROJECT_ID]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/../../backend" && pwd)"
PROJECT_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --project)
      PROJECT_ID="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "$PROJECT_ID" ]]; then
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)
fi

if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: GCP project ID required. Set with: gcloud config set project YOUR_PROJECT_ID"
  echo "Or pass: $0 --project YOUR_PROJECT_ID"
  exit 1
fi

echo "=== WAR ROOM GCP Setup ==="
echo "Project: $PROJECT_ID"
echo ""

# Load .env if present (for secret values)
ENV_FILE="$BACKEND_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  echo "Loading values from backend/.env..."
  set -a
  source "$ENV_FILE" 2>/dev/null || true
  set +a
fi

# Prompt for missing secrets
create_secret() {
  local name=$1
  local env_var=$2
  local prompt_msg=$3
  local value="${!env_var}"

  if [[ -z "$value" ]]; then
    read -sp "$prompt_msg: " value
    echo ""
  fi

  if [[ -z "$value" ]]; then
    echo "  Skipping $name (empty)"
    return
  fi

  if gcloud secrets describe "$name" --project="$PROJECT_ID" &>/dev/null; then
    echo "  Adding new version to $name..."
    echo -n "$value" | gcloud secrets versions add "$name" --data-file=- --project="$PROJECT_ID"
  else
    echo "  Creating secret $name..."
    echo -n "$value" | gcloud secrets create "$name" --data-file=- --replication-policy=automatic --project="$PROJECT_ID"
  fi
  echo "  Done: $name"
}

echo "--- Enabling APIs ---"
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  containerregistry.googleapis.com \
  secretmanager.googleapis.com \
  --project="$PROJECT_ID"

echo ""
echo "--- Creating Secret Manager secrets ---"
echo "Enter values when prompted, or ensure backend/.env has them."
echo ""

create_secret "war-room-google-api-key" "GOOGLE_API_KEY" "GOOGLE_API_KEY (Gemini)"
create_secret "war-room-elevenlabs-api-key" "ELEVENLABS_API_KEY" "ELEVENLABS_API_KEY"
create_secret "war-room-livekit-url" "LIVEKIT_URL" "LIVEKIT_URL (e.g. wss://your-project.livekit.cloud)"
create_secret "war-room-livekit-api-key" "LIVEKIT_API_KEY" "LIVEKIT_API_KEY"
create_secret "war-room-livekit-api-secret" "LIVEKIT_API_SECRET" "LIVEKIT_API_SECRET"

echo ""
echo "--- Granting Cloud Run access to secrets ---"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
CLOUD_RUN_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

for secret in war-room-google-api-key war-room-elevenlabs-api-key war-room-livekit-url war-room-livekit-api-key war-room-livekit-api-secret; do
  if gcloud secrets describe "$secret" --project="$PROJECT_ID" &>/dev/null; then
    gcloud secrets add-iam-policy-binding "$secret" \
      --project="$PROJECT_ID" \
      --member="serviceAccount:${CLOUD_RUN_SA}" \
      --role="roles/secretmanager.secretAccessor" \
      --quiet 2>/dev/null || true
  fi
done

echo ""
echo "=== Setup complete ==="
echo "Next steps:"
echo "  1. Deploy: ./scripts/deploy/deploy.sh"
echo "  2. Or connect GitHub: Cloud Console > Cloud Build > Triggers > Connect repository"
echo ""
