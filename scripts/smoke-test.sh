#!/usr/bin/env bash
# Proves replication works: a write on the primary appears on both replicas,
# replicas reject writes, and the primary sees two streaming standbys. Exits non-zero on failure.
set -euo pipefail
cd "$(dirname "$0")/.."

q() { local svc=$1; shift; docker compose exec -T "$svc" psql -U postgres -d appdb -v ON_ERROR_STOP=1 -tAc "$@"; }

token="smoke-$(date +%s)-${RANDOM}"
q pg-primary "CREATE TABLE IF NOT EXISTS smoke (id bigserial PRIMARY KEY, token text NOT NULL, created_at timestamptz NOT NULL DEFAULT now());"
q pg-primary "INSERT INTO smoke (token) VALUES ('${token}');"

for r in pg-replica-1 pg-replica-2; do
  n=0
  for _ in $(seq 1 30); do
    n=$(q "$r" "SELECT count(*) FROM smoke WHERE token = '${token}';" 2>/dev/null || echo 0)
    [ "$n" = "1" ] && break
    sleep 1
  done
  [ "$n" = "1" ] || { echo "FAIL ${r}: row not replicated within 30s"; exit 1; }
  echo "OK   ${r}: row replicated"

  if q "$r" "INSERT INTO smoke (token) VALUES ('must-fail');" >/dev/null 2>&1; then
    echo "FAIL ${r}: accepted a write"; exit 1
  fi
  echo "OK   ${r}: read-only"
done

streams=$(q pg-primary "SELECT count(*) FROM pg_stat_replication WHERE state = 'streaming';")
[ "$streams" = "2" ] || { echo "FAIL primary: expected 2 streaming standbys, got ${streams}"; exit 1; }
echo "OK   primary: 2 streaming standbys"