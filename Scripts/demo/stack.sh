#!/usr/bin/env bash
# The Jeni Care demo stack — one command per verb.
#
#   scripts/demo/stack.sh up      start the local Supabase + seed
#   scripts/demo/stack.sh reset   wipe to a known state + seed  ← the demo verb
#   scripts/demo/stack.sh seed    seed only (assumes a clean db)
#   scripts/demo/stack.sh status  what exists right now
#   scripts/demo/stack.sh down    stop the containers
#   scripts/demo/stack.sh sql     open psql on the demo database
#
# `reset` is the one that matters: it is how tomorrow's demo is
# replayed. It drops the database, re-applies the whole real
# migration chain, and re-seeds the fictional clinic — deterministic
# every time.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
# shellcheck source=/dev/null
source "$ROOT/scripts/demo/env.sh"

WORKDIR="$ROOT/demo"

require_docker() {
  if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop, then retry." >&2
    exit 1
  fi
}

case "${1:-}" in
  up)
    require_docker
    "$ROOT/scripts/demo/sync_migrations.sh"
    supabase start --workdir "$WORKDIR"
    python3 "$ROOT/scripts/demo/seed.py"
    ;;
  reset)
    require_docker
    "$ROOT/scripts/demo/sync_migrations.sh"
    supabase db reset --workdir "$WORKDIR"
    python3 "$ROOT/scripts/demo/seed.py"
    ;;
  seed)
    require_docker
    python3 "$ROOT/scripts/demo/seed.py"
    ;;
  status)
    require_docker
    python3 "$ROOT/scripts/demo/seed.py" --status
    ;;
  down)
    supabase stop --workdir "$WORKDIR"
    ;;
  sql)
    shift
    docker exec -it "$CARE_DB_CONTAINER" psql -U postgres -d postgres "$@"
    ;;
  *)
    sed -n '2,16p' "$0"
    exit 1
    ;;
esac
