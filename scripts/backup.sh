#!/usr/bin/env bash
# Take a pgBackRest backup of the primary.  Usage: scripts/backup.sh [full|diff|incr]
set -euo pipefail
cd "$(dirname "$0")/.."

type="${1:-full}"
case "$type" in
  full|diff|incr) ;;
  *) echo "usage: $0 [full|diff|incr]"; exit 2 ;;
esac

pgb() { docker compose exec -T -u postgres pg-primary pgbackrest --stanza=main "$@"; }

pgb stanza-create          # idempotent: succeeds if the stanza already exists and matches
pgb check                  # archive_command works and WAL reaches the repository
pgb --type="$type" backup
pgb info
