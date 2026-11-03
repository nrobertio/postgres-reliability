#!/usr/bin/env bash
# Show replication state from both sides.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== primary: connected standbys"
docker compose exec -T pg-primary psql -U postgres -d appdb -c \
  "SELECT application_name, client_addr, state, sync_state, write_lag, replay_lag FROM pg_stat_replication ORDER BY 1;"

echo "== primary: replication slots"
docker compose exec -T pg-primary psql -U postgres -d appdb -c \
  "SELECT slot_name, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal FROM pg_replication_slots ORDER BY 1;"

for r in pg-replica-1 pg-replica-2; do
  echo "== ${r}"
  docker compose exec -T "$r" psql -U postgres -d appdb -c \
    "SELECT pg_is_in_recovery() AS standby, now() - pg_last_xact_replay_timestamp() AS replay_delay;"
done