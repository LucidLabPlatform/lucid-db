BEGIN;

CREATE TEMP TABLE agent_id_map AS
SELECT
    agent_id AS legacy_id,
    regexp_replace(agent_id, '^lucid\.agent\.', '') AS canonical_id
FROM agents
WHERE agent_id LIKE 'lucid.agent.%'
  AND regexp_replace(agent_id, '^lucid\.agent\.', '') <> agent_id;

INSERT INTO agents (agent_id, first_seen_ts, last_seen_ts)
SELECT
    canonical_id,
    MIN(first_seen_ts) AS first_seen_ts,
    MAX(last_seen_ts) AS last_seen_ts
FROM (
    SELECT m.canonical_id, a.first_seen_ts, a.last_seen_ts
    FROM agents a
    JOIN agent_id_map m ON m.legacy_id = a.agent_id
    UNION ALL
    SELECT a.agent_id AS canonical_id, a.first_seen_ts, a.last_seen_ts
    FROM agents a
    JOIN agent_id_map m ON m.canonical_id = a.agent_id
) merged
GROUP BY canonical_id
ON CONFLICT (agent_id) DO UPDATE
SET first_seen_ts = LEAST(agents.first_seen_ts, EXCLUDED.first_seen_ts),
    last_seen_ts = GREATEST(agents.last_seen_ts, EXCLUDED.last_seen_ts);

INSERT INTO agent_metadata (agent_id, version, platform, architecture, received_ts)
SELECT m.canonical_id, t.version, t.platform, t.architecture, t.received_ts
FROM agent_metadata t
JOIN agent_id_map m ON m.legacy_id = t.agent_id
ON CONFLICT (agent_id) DO UPDATE
SET version = CASE WHEN EXCLUDED.received_ts >= agent_metadata.received_ts THEN EXCLUDED.version ELSE agent_metadata.version END,
    platform = CASE WHEN EXCLUDED.received_ts >= agent_metadata.received_ts THEN EXCLUDED.platform ELSE agent_metadata.platform END,
    architecture = CASE WHEN EXCLUDED.received_ts >= agent_metadata.received_ts THEN EXCLUDED.architecture ELSE agent_metadata.architecture END,
    received_ts = GREATEST(agent_metadata.received_ts, EXCLUDED.received_ts);

INSERT INTO agent_status (agent_id, state, connected_since_ts, uptime_s, version, received_ts)
SELECT m.canonical_id, t.state, t.connected_since_ts, t.uptime_s, t.version, t.received_ts
FROM agent_status t
JOIN agent_id_map m ON m.legacy_id = t.agent_id
ON CONFLICT (agent_id) DO UPDATE
SET state = CASE WHEN EXCLUDED.received_ts >= agent_status.received_ts THEN EXCLUDED.state ELSE agent_status.state END,
    connected_since_ts = CASE WHEN EXCLUDED.received_ts >= agent_status.received_ts THEN EXCLUDED.connected_since_ts ELSE agent_status.connected_since_ts END,
    uptime_s = CASE WHEN EXCLUDED.received_ts >= agent_status.received_ts THEN EXCLUDED.uptime_s ELSE agent_status.uptime_s END,
    version = CASE WHEN EXCLUDED.received_ts >= agent_status.received_ts THEN EXCLUDED.version ELSE agent_status.version END,
    received_ts = GREATEST(agent_status.received_ts, EXCLUDED.received_ts);

INSERT INTO agent_state (agent_id, cpu_percent, memory_percent, disk_percent, components, received_ts)
SELECT m.canonical_id, t.cpu_percent, t.memory_percent, t.disk_percent, t.components, t.received_ts
FROM agent_state t
JOIN agent_id_map m ON m.legacy_id = t.agent_id
ON CONFLICT (agent_id) DO UPDATE
SET cpu_percent = CASE WHEN EXCLUDED.received_ts >= agent_state.received_ts THEN EXCLUDED.cpu_percent ELSE agent_state.cpu_percent END,
    memory_percent = CASE WHEN EXCLUDED.received_ts >= agent_state.received_ts THEN EXCLUDED.memory_percent ELSE agent_state.memory_percent END,
    disk_percent = CASE WHEN EXCLUDED.received_ts >= agent_state.received_ts THEN EXCLUDED.disk_percent ELSE agent_state.disk_percent END,
    components = CASE WHEN EXCLUDED.received_ts >= agent_state.received_ts THEN EXCLUDED.components ELSE agent_state.components END,
    received_ts = GREATEST(agent_state.received_ts, EXCLUDED.received_ts);

INSERT INTO agent_cfg (agent_id, heartbeat_s, received_ts)
SELECT m.canonical_id, t.heartbeat_s, t.received_ts
FROM agent_cfg t
JOIN agent_id_map m ON m.legacy_id = t.agent_id
ON CONFLICT (agent_id) DO UPDATE
SET heartbeat_s = CASE WHEN EXCLUDED.received_ts >= agent_cfg.received_ts THEN EXCLUDED.heartbeat_s ELSE agent_cfg.heartbeat_s END,
    received_ts = GREATEST(agent_cfg.received_ts, EXCLUDED.received_ts);

INSERT INTO agent_cfg_logging (agent_id, log_level, received_ts)
SELECT m.canonical_id, t.log_level, t.received_ts
FROM agent_cfg_logging t
JOIN agent_id_map m ON m.legacy_id = t.agent_id
ON CONFLICT (agent_id) DO UPDATE
SET log_level = CASE WHEN EXCLUDED.received_ts >= agent_cfg_logging.received_ts THEN EXCLUDED.log_level ELSE agent_cfg_logging.log_level END,
    received_ts = GREATEST(agent_cfg_logging.received_ts, EXCLUDED.received_ts);

INSERT INTO agent_cfg_telemetry (
    agent_id,
    cpu_pct_enabled, cpu_pct_interval_s, cpu_pct_threshold,
    memory_pct_enabled, memory_pct_interval_s, memory_pct_threshold,
    disk_pct_enabled, disk_pct_interval_s, disk_pct_threshold,
    received_ts
)
SELECT
    m.canonical_id,
    t.cpu_pct_enabled, t.cpu_pct_interval_s, t.cpu_pct_threshold,
    t.memory_pct_enabled, t.memory_pct_interval_s, t.memory_pct_threshold,
    t.disk_pct_enabled, t.disk_pct_interval_s, t.disk_pct_threshold,
    t.received_ts
FROM agent_cfg_telemetry t
JOIN agent_id_map m ON m.legacy_id = t.agent_id
ON CONFLICT (agent_id) DO UPDATE
SET cpu_pct_enabled = CASE WHEN EXCLUDED.received_ts >= agent_cfg_telemetry.received_ts THEN EXCLUDED.cpu_pct_enabled ELSE agent_cfg_telemetry.cpu_pct_enabled END,
    cpu_pct_interval_s = CASE WHEN EXCLUDED.received_ts >= agent_cfg_telemetry.received_ts THEN EXCLUDED.cpu_pct_interval_s ELSE agent_cfg_telemetry.cpu_pct_interval_s END,
    cpu_pct_threshold = CASE WHEN EXCLUDED.received_ts >= agent_cfg_telemetry.received_ts THEN EXCLUDED.cpu_pct_threshold ELSE agent_cfg_telemetry.cpu_pct_threshold END,
    memory_pct_enabled = CASE WHEN EXCLUDED.received_ts >= agent_cfg_telemetry.received_ts THEN EXCLUDED.memory_pct_enabled ELSE agent_cfg_telemetry.memory_pct_enabled END,
    memory_pct_interval_s = CASE WHEN EXCLUDED.received_ts >= agent_cfg_telemetry.received_ts THEN EXCLUDED.memory_pct_interval_s ELSE agent_cfg_telemetry.memory_pct_interval_s END,
    memory_pct_threshold = CASE WHEN EXCLUDED.received_ts >= agent_cfg_telemetry.received_ts THEN EXCLUDED.memory_pct_threshold ELSE agent_cfg_telemetry.memory_pct_threshold END,
    disk_pct_enabled = CASE WHEN EXCLUDED.received_ts >= agent_cfg_telemetry.received_ts THEN EXCLUDED.disk_pct_enabled ELSE agent_cfg_telemetry.disk_pct_enabled END,
    disk_pct_interval_s = CASE WHEN EXCLUDED.received_ts >= agent_cfg_telemetry.received_ts THEN EXCLUDED.disk_pct_interval_s ELSE agent_cfg_telemetry.disk_pct_interval_s END,
    disk_pct_threshold = CASE WHEN EXCLUDED.received_ts >= agent_cfg_telemetry.received_ts THEN EXCLUDED.disk_pct_threshold ELSE agent_cfg_telemetry.disk_pct_threshold END,
    received_ts = GREATEST(agent_cfg_telemetry.received_ts, EXCLUDED.received_ts);

INSERT INTO components (agent_id, component_id, first_seen_ts, last_seen_ts)
SELECT m.canonical_id, c.component_id, c.first_seen_ts, c.last_seen_ts
FROM components c
JOIN agent_id_map m ON m.legacy_id = c.agent_id
ON CONFLICT (agent_id, component_id) DO UPDATE
SET first_seen_ts = LEAST(components.first_seen_ts, EXCLUDED.first_seen_ts),
    last_seen_ts = GREATEST(components.last_seen_ts, EXCLUDED.last_seen_ts);

INSERT INTO component_metadata (agent_id, component_id, version, capabilities, received_ts)
SELECT m.canonical_id, t.component_id, t.version, t.capabilities, t.received_ts
FROM component_metadata t
JOIN agent_id_map m ON m.legacy_id = t.agent_id
ON CONFLICT (agent_id, component_id) DO UPDATE
SET version = CASE WHEN EXCLUDED.received_ts >= component_metadata.received_ts THEN EXCLUDED.version ELSE component_metadata.version END,
    capabilities = CASE WHEN EXCLUDED.received_ts >= component_metadata.received_ts THEN EXCLUDED.capabilities ELSE component_metadata.capabilities END,
    received_ts = GREATEST(component_metadata.received_ts, EXCLUDED.received_ts);

INSERT INTO component_status (agent_id, component_id, state, received_ts)
SELECT m.canonical_id, t.component_id, t.state, t.received_ts
FROM component_status t
JOIN agent_id_map m ON m.legacy_id = t.agent_id
ON CONFLICT (agent_id, component_id) DO UPDATE
SET state = CASE WHEN EXCLUDED.received_ts >= component_status.received_ts THEN EXCLUDED.state ELSE component_status.state END,
    received_ts = GREATEST(component_status.received_ts, EXCLUDED.received_ts);

INSERT INTO component_state (agent_id, component_id, payload, received_ts)
SELECT m.canonical_id, t.component_id, t.payload, t.received_ts
FROM component_state t
JOIN agent_id_map m ON m.legacy_id = t.agent_id
ON CONFLICT (agent_id, component_id) DO UPDATE
SET payload = CASE WHEN EXCLUDED.received_ts >= component_state.received_ts THEN EXCLUDED.payload ELSE component_state.payload END,
    received_ts = GREATEST(component_state.received_ts, EXCLUDED.received_ts);

INSERT INTO component_cfg (agent_id, component_id, payload, received_ts)
SELECT m.canonical_id, t.component_id, t.payload, t.received_ts
FROM component_cfg t
JOIN agent_id_map m ON m.legacy_id = t.agent_id
ON CONFLICT (agent_id, component_id) DO UPDATE
SET payload = CASE WHEN EXCLUDED.received_ts >= component_cfg.received_ts THEN EXCLUDED.payload ELSE component_cfg.payload END,
    received_ts = GREATEST(component_cfg.received_ts, EXCLUDED.received_ts);

INSERT INTO component_cfg_logging (agent_id, component_id, log_level, received_ts)
SELECT m.canonical_id, t.component_id, t.log_level, t.received_ts
FROM component_cfg_logging t
JOIN agent_id_map m ON m.legacy_id = t.agent_id
ON CONFLICT (agent_id, component_id) DO UPDATE
SET log_level = CASE WHEN EXCLUDED.received_ts >= component_cfg_logging.received_ts THEN EXCLUDED.log_level ELSE component_cfg_logging.log_level END,
    received_ts = GREATEST(component_cfg_logging.received_ts, EXCLUDED.received_ts);

INSERT INTO component_cfg_telemetry (agent_id, component_id, payload, received_ts)
SELECT m.canonical_id, t.component_id, t.payload, t.received_ts
FROM component_cfg_telemetry t
JOIN agent_id_map m ON m.legacy_id = t.agent_id
ON CONFLICT (agent_id, component_id) DO UPDATE
SET payload = CASE WHEN EXCLUDED.received_ts >= component_cfg_telemetry.received_ts THEN EXCLUDED.payload ELSE component_cfg_telemetry.payload END,
    received_ts = GREATEST(component_cfg_telemetry.received_ts, EXCLUDED.received_ts);

UPDATE commands t
SET agent_id = m.canonical_id
FROM agent_id_map m
WHERE t.agent_id = m.legacy_id;

UPDATE agent_events t
SET agent_id = m.canonical_id
FROM agent_id_map m
WHERE t.agent_id = m.legacy_id;

UPDATE component_events t
SET agent_id = m.canonical_id
FROM agent_id_map m
WHERE t.agent_id = m.legacy_id;

UPDATE agent_telemetry t
SET agent_id = m.canonical_id
FROM agent_id_map m
WHERE t.agent_id = m.legacy_id;

UPDATE component_telemetry t
SET agent_id = m.canonical_id
FROM agent_id_map m
WHERE t.agent_id = m.legacy_id;

UPDATE logs t
SET agent_id = m.canonical_id
FROM agent_id_map m
WHERE t.agent_id = m.legacy_id;

UPDATE client_events t
SET agent_id = m.canonical_id
FROM agent_id_map m
WHERE t.agent_id = m.legacy_id;

UPDATE mqtt_rejected_messages t
SET agent_id = m.canonical_id
FROM agent_id_map m
WHERE t.agent_id = m.legacy_id;

DELETE FROM component_metadata WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);
DELETE FROM component_status WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);
DELETE FROM component_state WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);
DELETE FROM component_cfg WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);
DELETE FROM component_cfg_logging WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);
DELETE FROM component_cfg_telemetry WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);
DELETE FROM components WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);

DELETE FROM agent_metadata WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);
DELETE FROM agent_status WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);
DELETE FROM agent_state WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);
DELETE FROM agent_cfg WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);
DELETE FROM agent_cfg_logging WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);
DELETE FROM agent_cfg_telemetry WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);
DELETE FROM agents WHERE agent_id IN (SELECT legacy_id FROM agent_id_map);

COMMIT;
