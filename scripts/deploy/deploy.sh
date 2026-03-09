#!/usr/bin/env bash
# WAR ROOM — Deploy backend to Google Cloud Run
# Uses Cloud Build + Cloud Run. Requires setup-gcp.sh to have been run once.
# Usage: ./scripts/deploy/deploy.sh [--project PROJECT_ID] [--key PATH_TO_SERVICE_ACCOUNT_JSON]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/../../backend" && pwd)"
PROJECT_ID=""
KEY_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --project)
      PROJECT_ID="$2"
      shift 2
      ;;
    --key)
      KEY_FILE="$2"
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

# Authenticate with service account key if provided
if [[ -n "$KEY_FILE" ]]; then
  if [[ ! -f "$KEY_FILE" ]]; then
    echo "Error: Service account key file not found: $KEY_FILE"
    exit 1
  fi
  echo "Using service account: $KEY_FILE"
  gcloud auth activate-service-account --key-file="$KEY_FILE" --project="$PROJECT_ID"
fi

echo "=== Deploying WAR ROOM Backend to Cloud Run ==="
echo "Project: $PROJECT_ID"
echo ""

cd "$REPO_ROOT"

# Submit build from repo root so dir:backend in cloudbuild works (same as GitHub trigger)
gcloud builds submit . \
  --config=backend/cloudbuild.yaml \
  --project="$PROJECT_ID" \
  --substitutions=COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "manual")

echo ""
echo "=== Deployment complete ==="
SERVICE_URL=$(gcloud run services describe war-room-backend --region=us-central1 --project="$PROJECT_ID" --format='value(status.url)' 2>/dev/null || echo "")
if [[ -n "$SERVICE_URL" ]]; then
  echo "Service URL: $SERVICE_URL"
  echo "Health check: $SERVICE_URL/api/health"
else
  echo "Get URL: gcloud run services describe war-room-backend --region=us-central1 --format='value(status.url)'"
fi
echo ""
