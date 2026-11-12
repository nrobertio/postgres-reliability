# Postgres Reliability

A hands-on PostgreSQL reliability lab: a primary with two streaming replicas, pgBackRest backups with continuous WAL archiving, a point-in-time restore that is tested on every push, and a failover drill that measures RTO and RPO. Runs with Docker Compose and is verified end to end in CI.

Maintained by nrobertio.

## What this demonstrates

- Streaming replication: one primary, two hot-standby replicas, each with its own physical replication slot.
- Backups: pgBackRest full, differential and incremental backups, with every WAL segment archived.
- Point-in-time recovery: a table is dropped by "accident", and the database is restored to the moment before, into an isolated instance.
- Tested restores: CI restores and checks row counts on every push. A backup that has never been restored is not a backup.
- Failover: the primary is killed, a replica is promoted, and the drill measures time to first write and data loss.

## Architecture

```
            writes                  WAL stream (slots)
 client  ---------->  pg-primary  -------------------->  pg-replica-1, pg-replica-2 (read-only)
                          |
                          | archive_command: pgbackrest archive-push
                          v
                    backup repository (full / diff / incr + WAL)
                          |
                          | restore --type=time
                          v
                     pg-restore (isolated, archive off)
```

## Run it

Easiest: open the repo in GitHub Codespaces (Code > Codespaces > Create codespace). Docker and `.env` are set up for you.

```
cp .env.example .env              # then change the passwords
docker compose up -d --build --wait
bash scripts/smoke-test.sh        # replication works, replicas are read-only
bash scripts/backup.sh full       # or diff / incr
bash scripts/restore-test.sh      # drop a table, restore to just before, verify
bash scripts/status.sh            # lag, slots, standby state
bash scripts/failover-drill.sh    # kill the primary, promote a replica (destructive)
docker compose --profile restore down -v
```

Ports are bound to 127.0.0.1 only: primary 5432, replicas 5433 and 5434, restore 5435.

Design decisions and trade-offs: [docs/PROJECT.md](docs/PROJECT.md).

## Roadmap

- [x] Primary and two streaming replicas with replication slots
- [x] pgBackRest backups with WAL archiving
- [x] Point-in-time restore, tested in CI
- [x] Failover drill with RTO and RPO
- [ ] Backup repository on S3 (MinIO locally, S3 in another account in production), encrypted
- [ ] Re-point the remaining replica to the new primary after failover
- [ ] Automatic failover with Patroni and a replication lag alert

## License

MIT. See LICENSE.
