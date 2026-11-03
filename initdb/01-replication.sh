#!/usr/bin/env bash
# Runs once, on first start of the primary: create the replication role and allow it in pg_hba.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v repl_user="$REPLICATION_USER" -v repl_pass="$REPLICATION_PASSWORD" <<'SQL'
CREATE ROLE :"repl_user" WITH REPLICATION LOGIN PASSWORD :'repl_pass';
SQL

echo "host replication ${REPLICATION_USER} all scram-sha-256" >> "$PGDATA/pg_hba.conf"