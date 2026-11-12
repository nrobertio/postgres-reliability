# Postgres Reliability: project write-up

## Why this exists

Most outages involving data are not about the database being down. They are about a backup that cannot be restored, a restore nobody has practised, or a failover where nobody knows how much data was lost. This lab makes those three things concrete and tests them automatically.

## What it does

1. Replication. A primary streams WAL to two hot standbys. Each standby has its own physical replication slot, so the primary keeps the WAL a standby still needs.
2. Backups. pgBackRest takes full, differential and incremental backups. `archive_command` pushes every completed WAL segment to the repository, so recovery can go to any moment after the first backup.
3. Point-in-time recovery. The test writes data, takes a backup, writes more, records a time T, then drops the table. It restores to T into a separate instance and checks that all 1500 rows are back, 500 of them replayed from archived WAL.
4. Failover. The drill kills the primary, promotes replica 1 with `pg_promote()`, and measures the time until the first write succeeds. It also checks that the last replicated write survived.

## Design decisions

- pgBackRest over plain `pg_dump`: `pg_dump` is a logical snapshot at one moment. pgBackRest gives physical backups plus WAL, so recovery can stop at any second, and it handles retention, checksums and parallel restore.
- Restore into an isolated instance: production is never overwritten during a restore. You check the restored data first, then decide whether to copy rows back or switch over.
- `archive_mode=off` on the restored copy: a restored cluster has the same system identifier as production. If it archived, it could write conflicting WAL into the production repository.
- Replication slots per replica: without slots, a replica that falls behind can lose the WAL it needs and must be rebuilt. The trade-off is that a dead replica's slot keeps WAL forever and can fill the primary's disk, so slots need monitoring (`scripts/status.sh` shows retained WAL per slot).
- Asynchronous replication: writes are fast and a slow replica does not block the primary. The cost is a possible small data loss on failover. Synchronous replication removes that loss but adds latency and can block writes if the standby is down.
- Manual promotion in the drill: it keeps the mechanics visible. The measured time excludes detection; in production an orchestrator such as Patroni detects failure, holds a leader lock (etcd or Consul) to avoid split brain, and promotes automatically.

## Design notes and trade-offs

- RPO vs cost: continuous WAL archiving gives an RPO of seconds for the backup path. Async replication gives near-zero RPO for failover, but not zero.
- RTO: failover takes seconds; a restore takes minutes and grows with database size and WAL to replay. That is why both exist: replicas for availability, backups for mistakes such as a dropped table, which replicas copy instantly.
- Where backups live: the lab keeps the repository on a separate volume. In production it belongs in S3 in another account, encrypted, with object lock, so a compromised database host cannot delete its own backups.
- Retention: `repo1-retention-full=2` keeps two full backups and the WAL needed for them. Real retention follows the business requirement, often daily for 30 days plus monthly copies.

## What I would add next

- S3 repository with encryption and object lock.
- Patroni for automatic failover, and re-pointing the remaining replica to the new primary.
- Alerts on replication lag, retained WAL per slot, and backup age.
- A scheduled restore test against a real-sized copy, with the restore time tracked over time.
