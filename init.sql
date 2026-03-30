-- LUCID IoT Fleet Management Platform
-- TimescaleDB Schema
-- Placed at /docker-entrypoint-initdb.d/001_init.sql

-- ============================================================
-- Extensions
-- ============================================================

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ============================================================
-- schema_migrations
-- ============================================================

CREATE TABLE IF NOT EXISTS schema_migrations (
    version     TEXT PRIMARY KEY,
    applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- agents
-- ============================================================

CREATE TABLE IF NOT EXISTS agents (
    agent_id        TEXT PRIMARY KEY,
    first_seen_ts   TIMESTAMPTZ NOT NULL,
    last_seen_ts    TIMESTAMPTZ NOT NULL
);

-- ============================================================
-- agent_metadata
-- ============================================================

CREATE TABLE IF NOT EXISTS agent_metadata (
    agent_id        TEXT PRIMARY KEY REFERENCES agents(agent_id),
    version         TEXT,
    platform        TEXT,
    architecture    TEXT,
    received_ts     TIMESTAMPTZ NOT NULL
);

-- ============================================================
-- agent_status
-- ============================================================

CREATE TABLE IF NOT EXISTS agent_status (
    agent_id            TEXT PRIMARY KEY REFERENCES agents(agent_id),
    state               TEXT,
    connected_since_ts  TIMESTAMPTZ,
    uptime_s            FLOAT8,
    version             TEXT,
    received_ts         TIMESTAMPTZ NOT NULL
);

-- ============================================================
-- agent_state
-- ============================================================

CREATE TABLE IF NOT EXISTS agent_state (
    agent_id        TEXT PRIMARY KEY REFERENCES agents(agent_id),
    cpu_percent     FLOAT8,
    memory_percent  FLOAT8,
    disk_percent    FLOAT8,
    components      JSONB,
    received_ts     TIMESTAMPTZ NOT NULL
);

-- ============================================================
-- agent_cfg
-- ============================================================

CREATE TABLE IF NOT EXISTS agent_cfg (
    agent_id    TEXT PRIMARY KEY REFERENCES agents(agent_id),
    heartbeat_s INTEGER,
    received_ts TIMESTAMPTZ NOT NULL
);

-- ============================================================
-- agent_cfg_logging
-- ============================================================

CREATE TABLE IF NOT EXISTS agent_cfg_logging (
    agent_id    TEXT PRIMARY KEY REFERENCES agents(agent_id),
    log_level   TEXT,
    received_ts TIMESTAMPTZ NOT NULL
);

-- ============================================================
-- agent_cfg_telemetry
-- ============================================================

CREATE TABLE IF NOT EXISTS agent_cfg_telemetry (
    agent_id                TEXT PRIMARY KEY REFERENCES agents(agent_id),
    cpu_pct_enabled         BOOLEAN,
    cpu_pct_interval_s      INTEGER,
    cpu_pct_threshold       FLOAT8,
    memory_pct_enabled      BOOLEAN,
    memory_pct_interval_s   INTEGER,
    memory_pct_threshold    FLOAT8,
    disk_pct_enabled        BOOLEAN,
    disk_pct_interval_s     INTEGER,
    disk_pct_threshold      FLOAT8,
    received_ts             TIMESTAMPTZ NOT NULL
);

-- ============================================================
-- components
-- ============================================================

CREATE TABLE IF NOT EXISTS components (
    agent_id        TEXT NOT NULL REFERENCES agents(agent_id),
    component_id    TEXT NOT NULL,
    first_seen_ts   TIMESTAMPTZ NOT NULL,
    last_seen_ts    TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (agent_id, component_id)
);

-- ============================================================
-- component_metadata
-- ============================================================

CREATE TABLE IF NOT EXISTS component_metadata (
    agent_id        TEXT NOT NULL,
    component_id    TEXT NOT NULL,
    version         TEXT,
    capabilities    JSONB,
    received_ts     TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (agent_id, component_id),
    FOREIGN KEY (agent_id, component_id) REFERENCES components(agent_id, component_id)
);

-- ============================================================
-- component_status
-- ============================================================

CREATE TABLE IF NOT EXISTS component_status (
    agent_id        TEXT NOT NULL,
    component_id    TEXT NOT NULL,
    state           TEXT,
    received_ts     TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (agent_id, component_id),
    FOREIGN KEY (agent_id, component_id) REFERENCES components(agent_id, component_id)
);

-- ============================================================
-- component_state
-- ============================================================

CREATE TABLE IF NOT EXISTS component_state (
    agent_id        TEXT NOT NULL,
    component_id    TEXT NOT NULL,
    payload         JSONB,
    received_ts     TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (agent_id, component_id),
    FOREIGN KEY (agent_id, component_id) REFERENCES components(agent_id, component_id)
);

-- ============================================================
-- component_cfg
-- ============================================================

CREATE TABLE IF NOT EXISTS component_cfg (
    agent_id        TEXT NOT NULL,
    component_id    TEXT NOT NULL,
    payload         JSONB,
    received_ts     TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (agent_id, component_id),
    FOREIGN KEY (agent_id, component_id) REFERENCES components(agent_id, component_id)
);

-- ============================================================
-- component_cfg_logging
-- ============================================================

CREATE TABLE IF NOT EXISTS component_cfg_logging (
    agent_id        TEXT NOT NULL,
    component_id    TEXT NOT NULL,
    log_level       TEXT,
    received_ts     TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (agent_id, component_id),
    FOREIGN KEY (agent_id, component_id) REFERENCES components(agent_id, component_id)
);

-- ============================================================
-- component_cfg_telemetry
-- ============================================================

CREATE TABLE IF NOT EXISTS component_cfg_telemetry (
    agent_id        TEXT NOT NULL,
    component_id    TEXT NOT NULL,
    payload         JSONB,
    received_ts     TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (agent_id, component_id),
    FOREIGN KEY (agent_id, component_id) REFERENCES components(agent_id, component_id)
);

-- ============================================================
-- commands
-- ============================================================

CREATE TABLE IF NOT EXISTS commands (
    request_id      TEXT PRIMARY KEY,
    agent_id        TEXT NOT NULL REFERENCES agents(agent_id),
    component_id    TEXT,
    action          TEXT NOT NULL,
    payload         JSONB,
    result_ok       BOOLEAN,
    result_ts       TIMESTAMPTZ,
    sent_ts         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS commands_agent_id_idx ON commands(agent_id);
CREATE INDEX IF NOT EXISTS commands_pending_idx ON commands(agent_id) WHERE result_ok IS NULL;
CREATE INDEX IF NOT EXISTS commands_sent_ts_idx ON commands(agent_id, sent_ts DESC);

-- ============================================================
-- agent_events (hypertable)
-- ============================================================

-- No FK on agent_id: TimescaleDB does not support FKs on hypertables.
-- Referential integrity enforced by upsert-agents action firing before agent-events-sink in setup_rules.py.
CREATE TABLE IF NOT EXISTS agent_events (
    id          BIGSERIAL,
    agent_id    TEXT NOT NULL,
    action      TEXT,
    request_id  TEXT,
    ok          BOOLEAN,
    applied     JSONB,
    error       TEXT,
    received_ts TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (id, received_ts)
);

SELECT create_hypertable('agent_events', 'received_ts', if_not_exists => TRUE);
SELECT add_retention_policy('agent_events', INTERVAL '7 days', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS agent_events_agent_ts_idx ON agent_events(agent_id, received_ts DESC);
CREATE INDEX IF NOT EXISTS agent_events_request_id_idx ON agent_events(request_id);

-- ============================================================
-- component_events (hypertable)
-- ============================================================

CREATE TABLE IF NOT EXISTS component_events (
    id              BIGSERIAL,
    -- No FK on agent_id/component_id: TimescaleDB does not support FKs on hypertables.
    -- Referential integrity enforced by action ordering in setup_rules.py.
    agent_id        TEXT NOT NULL,
    component_id    TEXT NOT NULL,
    action          TEXT,
    request_id      TEXT,
    ok              BOOLEAN,
    applied         JSONB,
    error           TEXT,
    received_ts     TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (id, received_ts)
);

SELECT create_hypertable('component_events', 'received_ts', if_not_exists => TRUE);
SELECT add_retention_policy('component_events', INTERVAL '7 days', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS component_events_agent_comp_ts_idx ON component_events(agent_id, component_id, received_ts DESC);
CREATE INDEX IF NOT EXISTS component_events_request_id_idx ON component_events(request_id);

-- ============================================================
-- agent_telemetry (hypertable, 7-day retention)
-- ============================================================

CREATE TABLE IF NOT EXISTS agent_telemetry (
    agent_id    TEXT NOT NULL,
    metric      TEXT NOT NULL,
    value       FLOAT8 NOT NULL,
    received_ts TIMESTAMPTZ NOT NULL
);

SELECT create_hypertable('agent_telemetry', 'received_ts', if_not_exists => TRUE);
SELECT add_retention_policy('agent_telemetry', INTERVAL '7 days', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS agent_telemetry_agent_ts_idx ON agent_telemetry(agent_id, received_ts DESC);
CREATE INDEX IF NOT EXISTS agent_telemetry_metric_ts_idx ON agent_telemetry(metric, received_ts DESC);

-- ============================================================
-- component_telemetry (hypertable, 7-day retention)
-- ============================================================

CREATE TABLE IF NOT EXISTS component_telemetry (
    agent_id        TEXT NOT NULL,
    component_id    TEXT NOT NULL,
    metric          TEXT NOT NULL,
    value           FLOAT8 NOT NULL,
    received_ts     TIMESTAMPTZ NOT NULL
);

SELECT create_hypertable('component_telemetry', 'received_ts', if_not_exists => TRUE);
SELECT add_retention_policy('component_telemetry', INTERVAL '7 days', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS component_telemetry_agent_comp_ts_idx ON component_telemetry(agent_id, component_id, received_ts DESC);
CREATE INDEX IF NOT EXISTS component_telemetry_metric_ts_idx ON component_telemetry(metric, received_ts DESC);

-- ============================================================
-- logs (hypertable, 7-day retention)
-- ============================================================

CREATE TABLE IF NOT EXISTS logs (
    agent_id        TEXT NOT NULL,
    component_id    TEXT,
    payload         JSONB,
    received_ts     TIMESTAMPTZ NOT NULL
);

SELECT create_hypertable('logs', 'received_ts', if_not_exists => TRUE);
SELECT add_retention_policy('logs', INTERVAL '7 days', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS logs_agent_ts_idx ON logs(agent_id, received_ts DESC);
CREATE INDEX IF NOT EXISTS logs_component_ts_idx ON logs(component_id, received_ts DESC) WHERE component_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS logs_agent_comp_ts_idx ON logs(agent_id, component_id, received_ts DESC) WHERE component_id IS NOT NULL;

-- ============================================================
-- client_events (hypertable, 7-day retention)
-- ============================================================

CREATE TABLE IF NOT EXISTS client_events (
    agent_id    TEXT NOT NULL,
    event_type  TEXT NOT NULL,
    ts          TIMESTAMPTZ NOT NULL
);

SELECT create_hypertable('client_events', 'ts', if_not_exists => TRUE);
SELECT add_retention_policy('client_events', INTERVAL '7 days', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS client_events_agent_ts_idx ON client_events(agent_id, ts DESC);

-- ============================================================
-- mqtt_rejected_messages (hypertable, 7-day retention)
-- Stores messages that failed EMQX schema validation.
-- schema_validations use failure_action:"ignore" so messages reach
-- the rule engine; rejection rules write here via NOT schema_check().
-- ============================================================

CREATE TABLE IF NOT EXISTS mqtt_rejected_messages (
    id              BIGSERIAL,
    topic           TEXT NOT NULL,
    agent_id        TEXT,
    raw_payload     TEXT,
    validation_name TEXT NOT NULL,
    received_ts     TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (id, received_ts)
);

SELECT create_hypertable('mqtt_rejected_messages', 'received_ts', if_not_exists => TRUE);
SELECT add_retention_policy('mqtt_rejected_messages', INTERVAL '7 days', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS mqtt_rejected_messages_ts_idx         ON mqtt_rejected_messages(received_ts DESC);
CREATE INDEX IF NOT EXISTS mqtt_rejected_messages_topic_ts_idx   ON mqtt_rejected_messages(topic, received_ts DESC);
CREATE INDEX IF NOT EXISTS mqtt_rejected_messages_val_ts_idx     ON mqtt_rejected_messages(validation_name, received_ts DESC);

-- ============================================================
-- api_keys
-- ============================================================

CREATE TABLE IF NOT EXISTS api_keys (
    id              BIGSERIAL PRIMARY KEY,
    key_hash        TEXT NOT NULL UNIQUE,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at    TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,
    revoked         BOOLEAN NOT NULL DEFAULT false
);

-- ============================================================
-- Seed schema_migrations
-- ============================================================

INSERT INTO schema_migrations (version) VALUES ('001_initial')
ON CONFLICT DO NOTHING;
