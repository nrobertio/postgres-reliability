#!/usr/bin/env bash
# Replica bootstrap: on an empty data dir, clone the primary with pg_basebackup,
# create a physical replication slot and write standby config (-R). Then start as hot standby.
set -euo pipefail
: "${PRIMARY_HOST:?}" "${REPLICA_SLOT:?}" "${REPLICATION_USER:?}" "${REPLICATION_PASSWORD:?}"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Empty data dir: cloning from ${PRIMARY_HOST}"
  until pg_isready -h "$PRIMARY_HOST" -U "$REPLICATION_USER" -q; do sleep 1; done
  export PGPASSWORD="$REPLICATION_PASSWORD"
  pg_basebackup -h "$PRIMARY_HOST" -U "$REPLICATION_USER" -D "$PGDATA" \
    -X stream -R -C -S "$REPLICA_SLOT" --checkpoint=fast
  unset PGPASSWORD
  chmod 0700 "$PGDATA"
fi

# cluster_name becomes the application_name the primary shows in pg_stat_replication
exec postgres -c hot_standby=on -c cluster_name="$REPLICA_SLOT"