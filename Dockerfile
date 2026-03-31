FROM timescale/timescaledb:2.17.2-pg16
COPY init.sql /docker-entrypoint-initdb.d/001_init.sql
COPY normalize_agent_ids.sql /docker-entrypoint-initdb.d/normalize_agent_ids.sql
