#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/backend"

if [ ! -x venv/bin/python ]; then
  echo "Missing backend/venv. Run: bash backend/setup_backend.sh"
  exit 1
fi

if command -v lsof >/dev/null 2>&1; then
  existing_pids=$(lsof -tiTCP:8000 -sTCP:LISTEN || true)
  if [ -n "$existing_pids" ]; then
    echo "Port 8000 is already in use by: $existing_pids"
    for pid in $existing_pids; do
      existing_cmd=$(ps -p "$pid" -o comm= 2>/dev/null | tr -d ' ')
      if [ "$existing_cmd" = "Python" ] || [ "$existing_cmd" = "uvicorn" ] || [ "$existing_cmd" = "python3" ]; then
        echo "Stopping stale backend process PID $pid ($existing_cmd)"
        kill -9 "$pid" || true
      else
        echo "Port 8000 is owned by $existing_cmd PID $pid. Please stop that process manually."
        exit 1
      fi
    done
    sleep 1
  fi
fi

source venv/bin/activate
export PYTHONPATH="$ROOT${PYTHONPATH:+:$PYTHONPATH}"

exec uvicorn app.main:app \
  --host "${API_HOST:-0.0.0.0}" \
  --port "${API_PORT:-8000}" \
  --reload \
  --reload-dir "$ROOT/backend" \
  --reload-dir "$ROOT/app" \
  --reload-exclude "*/venv/*" \
  --reload-exclude "*/__pycache__/*" \
  --reload-exclude "*/.git/*" \
  --reload-exclude "*.pyc" \
  --reload-exclude "*.pyo"
