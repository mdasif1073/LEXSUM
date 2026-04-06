#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/backend"

if [ ! -x venv/bin/python ]; then
  echo "Missing backend/venv. Run: bash backend/setup_backend.sh"
  exit 1
fi

source venv/bin/activate
cd "$ROOT"
bash backend/sync_modal_secret.sh
exec modal run modal_worker.py
