FROM postgres:16.4

# pgBackRest for backups and WAL archiving. Directories are owned by postgres so a fresh
# named volume mounted on /var/lib/pgbackrest inherits the right ownership.
RUN apt-get update \
 && apt-get install -y --no-install-recommends pgbackrest \
 && rm -rf /var/lib/apt/lists/* \
 && install -d -o postgres -g postgres -m 0750 /var/lib/pgbackrest /var/log/pgbackrest /tmp/pgbackrest

COPY pgbackrest.conf /etc/pgbackrest/pgbackrest.conf
