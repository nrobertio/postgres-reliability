#!/usr/bin/env bash
# Restore from the pgBackRest repository into an empty data dir, then start.
# RESTORE_TARGET set: point-in-time recovery to that timestamp. Empty: latest state.
# archive_mode stays off: a restored copy must never push WAL into the production archive.
set -euo pipefail

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  args=(--stanza=main)
  if [ -n "${RESTORE_TARGET:-}" ]; then
    args+=(--type=time "--target=${RESTORE_TARGET}" --target-action=promote)
  fi
  echo "Restoring with: ${args[*]}"
  pgbackrest "${args[@]}" restore
  chmod 0700 "$PGDATA"
fi

exec postgres -c archive_mode=off -c hot_standby=on
