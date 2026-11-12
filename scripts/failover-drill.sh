#!/usr/bin/env bash
# Failover drill: kill the primary, promote replica 1, measure RTO and check RPO.
# Destructive for the running lab (the primary is killed), so CI runs it last.
set -euo pipefail
cd "$(dirname "$0")/.."

pass() { echo "OK   $*"; }
fail() { echo "FAIL $*"; exit 1; }
q() { local svc=$1; shift; docker compose exec -T "$svc" psql -U postgres -d appdb -v ON_ERROR_STOP=1 -tAc "$1"; }
now_ms() { date +%s%3N; }

q pg-primary "CREATE TABLE IF NOT EXISTS drill (id bigserial PRIMARY KEY, token text NOT NULL);"
token="last-write-$(date +%s)"
q pg-primary "INSERT INTO drill (token) VALUES ('${token}');"

seen=0
for _ in $(seq 1 30); do
  seen=$(q pg-replica-1 "SELECT count(*) FROM drill WHERE token = '${token}';" 2>/dev/null || echo 0)
  [ "$seen" = "1" ] && break
  sleep 1
done
[ "$seen" = "1" ] || fail "last write did not reach pg-replica-1 before the drill"
pass "last committed write replicated to pg-replica-1"

t0=$(now_ms)
docker compose kill pg-primary >/dev/null 2>&1
promoted=$(q pg-replica-1 "SELECT pg_promote(true, 30);")
[ "$promoted" = "t" ] || fail "promotion of pg-replica-1 failed"
q pg-replica-1 "INSERT INTO drill (token) VALUES ('first-write-after-failover');" >/dev/null
t1=$(now_ms)
pass "pg-replica-1 promoted and accepting writes $((t1 - t0)) ms after the primary was killed"

kept=$(q pg-replica-1 "SELECT count(*) FROM drill WHERE token = '${token}';")
[ "$kept" = "1" ] || fail "RPO: the last replicated write was lost"
pass "no data lost for writes that had replicated (async: an unreplicated commit could be lost)"

recovering=$(q pg-replica-1 "SELECT pg_is_in_recovery();")
[ "$recovering" = "f" ] || fail "pg-replica-1 is still in recovery"
pass "pg-replica-1 is the new primary"
