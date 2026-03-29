# lucid-db

TimescaleDB database image for the LUCID IoT fleet management platform. Stores agent state, component telemetry, logs, commands, events, and API keys.

## Build and Run

```bash
# Copy and edit env file
cp .env.example .env

# Build
docker build -t lucid-db .

# Run
docker run -d \
  --name lucid-db \
  --env-file .env \
  -p 5432:5432 \
  -v $(pwd)/pgdata:/var/lib/postgresql/data \
  lucid-db
```

Or with Docker Compose (from the parent `lucid-central-command` stack):

```bash
cd ../lucid-central-command && docker compose up -d
```

## Environment Variables

| Variable            | Description               | Default        |
|---------------------|---------------------------|----------------|
| `POSTGRES_USER`     | Database superuser name   | `lucid`        |
| `POSTGRES_PASSWORD` | Database superuser password | `REDACTED` |
| `POSTGRES_DB`       | Database name             | `lucid`        |

## Schema

The schema is initialised from `init.sql` (mounted at `/docker-entrypoint-initdb.d/001_init.sql`) on first container start.

### Regular tables

- `schema_migrations` — applied migration versions
- `agents`, `agent_metadata`, `agent_status`, `agent_state`, `agent_cfg`, `agent_cfg_logging`, `agent_cfg_telemetry` — per-agent derived state
- `components`, `component_metadata`, `component_status`, `component_state`, `component_cfg`, `component_cfg_logging`, `component_cfg_telemetry` — per-component derived state
- `commands` — outbound command log with pending/result tracking
- `api_keys` — hashed API keys for Central Command auth

### TimescaleDB hypertables (7-day retention)

| Table                | Time column  | Description                              |
|----------------------|--------------|------------------------------------------|
| `agent_events`       | `received_ts`| Agent-level command results/events       |
| `component_events`   | `received_ts`| Component-level command results/events   |
| `agent_telemetry`    | `received_ts`| Agent metric time-series (CPU, mem, disk)|
| `component_telemetry`| `received_ts`| Component metric time-series             |
| `logs`               | `received_ts`| Structured log stream from agents/components |
| `client_events`      | `ts`         | MQTT connect/disconnect events           |

Retention policies are added via `add_retention_policy` and automatically drop chunks older than 7 days.
