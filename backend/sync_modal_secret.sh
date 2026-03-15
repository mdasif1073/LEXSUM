#!/usr/bin/env bash
set -euo pipefail

# Sync values from backend/.env into Modal secret "classroom-env".
# Usage:
#   cd /path/to/classroom_app
#   bash backend/sync_modal_secret.sh
#
# Optional:
#   bash backend/sync_modal_secret.sh /custom/path/to/.env

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${1:-$ROOT_DIR/backend/.env}"
SECRET_NAME="classroom-env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE" >&2
  exit 1
fi

if [[ -x "$ROOT_DIR/backend/venv/bin/modal" ]]; then
  MODAL_BIN="$ROOT_DIR/backend/venv/bin/modal"
elif command -v modal >/dev/null 2>&1; then
  MODAL_BIN="$(command -v modal)"
else
  echo "Modal CLI not found. Activate venv or install modal first." >&2
  exit 1
fi

# Load .env keys into this shell.
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

required_vars=(
  REDIS_URL
  DATABASE_URL
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  WHISPER_MODEL
  LLM_MODEL
)

for key in "${required_vars[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    echo "Missing required key in $ENV_FILE: $key" >&2
    exit 1
  fi
done

args=(
  secret create "$SECRET_NAME" --force
  "REDIS_URL=$REDIS_URL"
  "DATABASE_URL=$DATABASE_URL"
  "SUPABASE_URL=$SUPABASE_URL"
  "SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY"
  "WHISPER_MODEL=$WHISPER_MODEL"
  "LLM_MODEL=$LLM_MODEL"
)

if [[ -n "${HF_TOKEN:-}" ]]; then
  args+=("HF_TOKEN=$HF_TOKEN")
else
  echo "HF_TOKEN not found in $ENV_FILE. Secret will be updated without HF token." >&2
fi

echo "Updating Modal secret '$SECRET_NAME' from $ENV_FILE"
"$MODAL_BIN" "${args[@]}"
echo "Done."
