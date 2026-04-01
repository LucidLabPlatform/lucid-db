# lucid-db

TimescaleDB (Postgres 16) database image for the LUCID IoT fleet management platform. Stores agent state, component telemetry, logs, commands, events, and API keys.

## What this is

`lucid-db` packages the TimescaleDB 2.17.2 / Postgres 16 image with the full LUCID schema baked in. On first boot, `init.sql` runs automatically via `/docker-entrypoint-initdb.d/`, creating all tables, hypertables, retention policies, and indexes in one shot. Subsequent starts skip init entirely (Postgres guards on data directory presence).

## Dockerfile

```
FROM timescale/timescaledb:2.17.2-pg16
COPY init.sql /docker-entrypoint-initdb.d/001_init.sql
```

`init.sql` is copied into the standard Postgres init directory and runs only on first container start.

## Environment Variables

| Variable            | Description                 | Example        |
|---------------------|-----------------------------|----------------|
| `POSTGRES_USER`     | Database superuser name     | `lucid`        |
| `POSTGRES_PASSWORD` | Database superuser password | `REDACTED` |
| `POSTGRES_DB`       | Database name               | `lucid`        |

## Build and Run

```bash
# Build
docker build -t lucid-db .

# Run standalone
docker run -d \
  --name lucid-db \
  -e POSTGRES_USER=lucid \
  -e POSTGRES_PASSWORD=REDACTED \
  -e POSTGRES_DB=lucid \
  -p 5432:5432 \
  -v $(pwd)/pgdata:/var/lib/postgresql/data \
  lucid-db
```

Or via the parent Central Command stack (recommended):

```bash
cd ../lucid-central-command && docker compose up -d
```

## Normalizing legacy agent IDs

If you have older fleet rows that used MQTT client IDs like `lucid.agent.rosbot`
as the stored `agent_id`, run the one-off normalization script below against an
existing database volume. It merges those legacy rows into the canonical agent
IDs such as `rosbot`.

```bash
docker compose exec -T db \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -f /docker-entrypoint-initdb.d/normalize_agent_ids.sql
```

## Schema

The schema is initialised from `init.sql` on first container start. The `timescaledb` extension is created first, then all tables, then hypertables and retention policies.

### Regular tables

| Table                    | Purpose                                                                 |
|--------------------------|-------------------------------------------------------------------------|
| `agents`                 | Registry of known agents; `first_seen_ts` / `last_seen_ts`             |
| `agent_metadata`         | Latest metadata payload per agent (version, platform, architecture)    |
| `agent_status`           | Latest status per agent (state, uptime, connected since)               |
| `agent_state`            | Latest runtime state per agent (CPU %, memory %, disk %, components JSONB) |
| `agent_cfg`              | Latest agent config (heartbeat interval)                               |
| `agent_cfg_logging`      | Latest logging config per agent (log level)                            |
| `agent_cfg_telemetry`    | Latest telemetry config per agent (per-metric enabled/interval/threshold) |
| `components`             | Registry of known components keyed by `(agent_id, component_id)`      |
| `component_metadata`     | Latest metadata per component (version, capabilities JSONB)            |
| `component_status`       | Latest status per component (state)                                    |
| `component_state`        | Latest state payload per component (arbitrary JSONB)                   |
| `component_cfg`          | Latest config payload per component (arbitrary JSONB)                  |
| `component_cfg_logging`  | Latest logging config per component (log level)                        |
| `component_cfg_telemetry`| Latest telemetry config per component (arbitrary JSONB)                |
| `commands`               | Outbound approved-command log with publisher identity, topic, and explicit `result_received` tracking |
| `users`                  | Central Command UI metadata for operational MQTT users                |
| `authn_log`              | Broker authentication outcomes for dashboard audit view               |
| `authz_log`              | Broker authorization outcomes for dashboard audit view                |
| `topic_links`            | EMQX-backed broker-side topic routing definitions                     |
| `api_keys`               | Hashed API keys for Central Command authentication                    |
| `schema_migrations`      | Baseline schema marker seeded with `001_initial` on first boot         |

### TimescaleDB hypertables (7-day retention)

All six hypertables have automatic chunk-drop retention policies via `add_retention_policy(..., INTERVAL '7 days')`. FK constraints are intentionally absent — see note below.

| Table                 | Time column   | Description                                        |
|-----------------------|---------------|----------------------------------------------------|
| `agent_telemetry`     | `received_ts` | Agent metric time-series (CPU %, memory %, disk %) |
| `component_telemetry` | `received_ts` | Component metric time-series (`value` stored as JSONB for numeric or structured metrics) |
| `agent_events`        | `received_ts` | Agent-level command results and events             |
| `component_events`    | `received_ts` | Component-level command results and events         |
| `logs`                | `received_ts` | Structured log stream from agents and components   |
| `client_events`       | `ts`          | MQTT client connect / disconnect events            |

## Key Indexes

All time-series tables carry a compound `(agent_id, received_ts DESC)` index for efficient per-agent time-range queries. Additional indexes:

- `agent_telemetry`: `(metric, received_ts DESC)`
- `component_telemetry`: `(agent_id, component_id, received_ts DESC)`, `(metric, received_ts DESC)`
- `component_events`: `(agent_id, component_id, received_ts DESC)`, `(request_id)`
- `agent_events`: `(request_id)`
- `logs`: `(component_id, received_ts DESC)`, `(agent_id, component_id, received_ts DESC)` (partial, where `component_id IS NOT NULL`)
- `commands`: `(agent_id)`, `(agent_id, sent_ts DESC)`, partial index on pending rows (`WHERE result_received = false`)
- `users`: `(role)`
- `authn_log`: `(ts DESC)`, `(username)`
- `authz_log`: `(ts DESC)`, `(username)`
- `topic_links`: `(enabled)`, `(created_at DESC)`

## Notes

**No FK constraints on hypertables.** TimescaleDB does not support foreign keys on hypertable columns. Referential integrity for `agent_events`, `component_events`, `agent_telemetry`, `component_telemetry`, `logs`, and `client_events` is enforced at the EMQX action layer: the upsert-agents/upsert-components actions fire before the sink actions in `setup_rules.py`, guaranteeing the parent row exists before the time-series row is written.

**schema_migrations seeding.** `init.sql` inserts `001_initial` into `schema_migrations` (`ON CONFLICT DO NOTHING`) as a baseline marker for a fresh database.
