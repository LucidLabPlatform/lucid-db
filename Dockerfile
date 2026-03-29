FROM timescale/timescaledb:latest-pg16
COPY init.sql /docker-entrypoint-initdb.d/001_init.sql
