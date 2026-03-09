#!/usr/bin/env bash
# WAR ROOM — Create Cloud Build trigger for GitHub (push to main -> auto deploy)
# Prerequisites:
#   1. Connect your GitHub repo in Cloud Console: Cloud Build > Triggers > Connect repository
#   2. Run setup-gcp.sh first
# Usage: ./scripts/deploy/create-github-trigger.sh [--project PROJECT_ID]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
  echo "Error: GCP project ID required."
  exit 1
fi

TRIGGER_NAME="war-room-backend-deploy"
REPO_OWNER="OkeyAmy"
REPO_NAME="war-room"

echo "=== Creating Cloud Build trigger for GitHub ==="
echo "Project: $PROJECT_ID"
echo "Repo: $REPO_OWNER/$REPO_NAME"
echo ""

# Check if trigger already exists
if gcloud builds triggers describe "$TRIGGER_NAME" --project="$PROJECT_ID" &>/dev/null; then
  echo "Trigger '$TRIGGER_NAME' already exists. Updating..."
  gcloud builds triggers delete "$TRIGGER_NAME" --project="$PROJECT_ID" --quiet
fi

# Create GitHub trigger
# Note: First connect the repo in Cloud Console: https://console.cloud.google.com/cloud-build/triggers
gcloud builds triggers create github \
  --name="$TRIGGER_NAME" \
  --project="$PROJECT_ID" \
  --repo-name="$REPO_NAME" \
  --repo-owner="$REPO_OWNER" \
  --branch-pattern="^main$" \
  --build-config="backend/cloudbuild.yaml" \
  --included-files="backend/**" \
  --description="Deploy WAR ROOM backend on push to main"

echo ""
echo "=== Trigger created ==="
echo "Pushes to main will now trigger deployment."
echo "If you see 'repository not found', connect the repo first:"
echo "  https://console.cloud.google.com/cloud-build/triggers?project=$PROJECT_ID"
echo ""
