FROM timescale/timescaledb:2.17.2-pg16
COPY init.sql /docker-entrypoint-initdb.d/001_init.sql
