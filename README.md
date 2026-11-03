# Postgres Reliability

A hands-on PostgreSQL reliability lab: a primary with two streaming replicas, and (in progress) automated backups, point-in-time recovery and a restore that is tested, not assumed. Everything runs locally with Docker Compose and is verified in CI.

Maintained by nrobertio.

## What this demonstrates

- Streaming replication: one primary, two hot-standby replicas, each with its own physical replication slot.
- Read/write split: writes go to the primary, reads can go to the replicas, and replicas reject writes.
- Verified, not assumed: CI starts the cluster and fails if a write does not reach both replicas.

## Architecture

```
            writes                 WAL stream (slot replica_1)
 client  ---------->  pg-primary  ---------------------------->  pg-replica-1  (read-only)
         <- reads --              ---------------------------->  pg-replica-2  (read-only)
                                     WAL stream (slot replica_2)
```

## Run it

```
cp .env.example .env          # then change the passwords
docker compose up -d --wait
bash scripts/smoke-test.sh    # write on primary, read on replicas, check read-only
bash scripts/status.sh        # lag, slots, standby state
docker compose down -v        # remove everything, including data
```

Ports are bound to 127.0.0.1 only: primary 5432, replicas 5433 and 5434.

## Roadmap

- [x] Primary and two streaming replicas with replication slots
- [x] Smoke test and CI
- [ ] Backups with pgBackRest to S3-compatible storage (MinIO), full and incremental
- [ ] Point-in-time recovery
- [ ] Automated restore test in CI
- [ ] Failover drill: kill the primary, promote a replica, measure RTO and RPO
- [ ] Replication lag drill and alerting

## License

MIT. See LICENSE.