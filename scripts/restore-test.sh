#!/usr/bin/env bash
# Point-in-time recovery drill. A backup only counts once a restore from it has worked.
#  1. load known data, take a full backup
#  2. write more data, record recovery point T
#  3. simulate an accident after T (DROP TABLE)
#  4. restore to T into a separate instance (production is never touched)
#  5. verify the table is back with every row written before T
set -euo pipefail
cd "$(dirname "$0")/.."

pass() { echo "OK   $*"; }
fail() { echo "FAIL $*"; exit 1; }
q()   { docker compose exec -T pg-primary psql -U postgres -d appdb -v ON_ERROR_STOP=1 -tAc "$1"; }
qr()  { docker compose --profile restore exec -T pg-restore psql -U postgres -d appdb -v ON_ERROR_STOP=1 -tAc "$1"; }
pgb() { docker compose exec -T -u postgres pg-primary pgbackrest --stanza=main "$@"; }

q "DROP TABLE IF EXISTS orders;"
q "CREATE TABLE orders (id int PRIMARY KEY, phase text NOT NULL);"
q "INSERT INTO orders SELECT g, 'before-backup' FROM generate_series(1, 1000) g;"
bash scripts/backup.sh full >/dev/null
pass "full backup taken with 1000 rows"

q "INSERT INTO orders SELECT g, 'after-backup' FROM generate_series(1001, 1500) g;"
sleep 2
target=$(q "SELECT now()::text;")
sleep 2
q "DROP TABLE orders;"
pgb check >/dev/null   # switches WAL and waits until the segment with the DROP is archived
pass "accident simulated after T=${target}, WAL archived"

docker compose --profile restore rm -sf pg-restore >/dev/null 2>&1 || true
docker volume rm -f postgres-reliability_restore-data >/dev/null
start=$(date +%s)
RESTORE_TARGET="$target" docker compose --profile restore up -d pg-restore >/dev/null

state=""
for _ in $(seq 1 90); do
  state=$(qr "SELECT pg_is_in_recovery();" 2>/dev/null || true)
  [ "$state" = "f" ] && break
  sleep 2
done
if [ "$state" != "f" ]; then
  docker compose --profile restore logs --no-color pg-restore | tail -n 40
  fail "restored instance did not finish recovery"
fi
pass "restore and recovery to T finished in $(( $(date +%s) - start ))s"

total=$(qr "SELECT count(*) FROM orders;")
after=$(qr "SELECT count(*) FROM orders WHERE phase = 'after-backup';")
[ "$total" = "1500" ] || fail "expected 1500 rows, got ${total}"
[ "$after" = "500" ] || fail "expected 500 rows written after the backup, got ${after}"
pass "restored table present: 1500 of 1500 rows, 500 of them replayed from archived WAL"

dropped=$(q "SELECT to_regclass('orders') IS NULL;")
[ "$dropped" = "t" ] || fail "production changed during the restore"
pass "production untouched: the restore ran in isolation"
