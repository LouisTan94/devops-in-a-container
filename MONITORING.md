# Monitoring Guide — Prometheus & Grafana

## Access

| Service    | URL                        | Credentials          |
|------------|----------------------------|----------------------|
| Prometheus | http://localhost:9090       | None                 |
| Grafana    | http://localhost:3000       | admin / P@ssw0rd1234 |

---

## How to Read the Alert Rules (`prometheus/alerts.yml`)

### File Structure

```
groups:
  - name: <group-name>       # Logical grouping of related alerts
    rules:
      - alert: <AlertName>   # Name shown in Prometheus UI and notifications
        expr: <PromQL>       # The condition that triggers the alert
        for: <duration>      # How long the condition must be true before firing
        labels:
          severity: critical # Tag used to route/filter alerts
        annotations:
          summary: "..."     # Short one-line description
          description: "..." # Detailed message, can use template variables
```

### Key Fields Explained

| Field | Purpose |
|---|---|
| `expr` | PromQL query — alert fires when this evaluates to true (non-zero) |
| `for` | Pending duration — prevents flapping on transient spikes |
| `severity` | Label used by Alertmanager to route to the right channel |
| `{{ $labels.job }}` | Template variable — the scrape job name of the firing target |
| `{{ $labels.instance }}` | Template variable — the host:port of the firing target |
| `{{ $value }}` | Template variable — the actual numeric value that triggered the alert |

### Alert States

```
INACTIVE → PENDING → FIRING
```

- **INACTIVE** — expression is false, all clear
- **PENDING** — expression is true but `for` duration not yet elapsed
- **FIRING** — expression has been true longer than `for` duration

View current state at: **Prometheus → Alerts** tab.

---

## Alert Groups Reference

### `instance` group

| Alert | Condition | For | Meaning |
|---|---|---|---|
| `TargetDown` | `up == 0` | 1m | A scrape target is unreachable |

`up` is set to `1` by Prometheus when a scrape succeeds, `0` when it fails. This catches any service going down across all jobs.

---

### `node` group — Host-level metrics (via node_exporter)

| Alert | Condition | For | Meaning |
|---|---|---|---|
| `HighCPUUsage` | CPU idle < 10% → usage > 90% | 5m | Server is CPU-saturated |
| `HighMemoryUsage` | Available memory < 10% | 5m | Server is running out of RAM |
| `DiskSpaceLow` | Disk used > 85% | 5m | Disk filling up |

**How the CPU expr works:**
```
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
```
- `rate(...[5m])` — per-second rate of idle CPU time over 5 min
- `avg by(instance)` — averages across all CPU cores
- `100 - (... * 100)` — converts idle % to used %

**Disk expr excludes `tmpfs` and `overlay`** (Docker internals) to avoid false positives:
```
{fstype!~"tmpfs|overlay"}
```

---

### `gitlab` group — Application-level metrics

| Alert | Condition | For | Meaning |
|---|---|---|---|
| `GitlabSidekiqQueueHigh` | Queue size > 100 jobs | 5m | Background jobs backing up |
| `GitlabSidekiqJobLatencyHigh` | Queue latency > 300s | 5m | Jobs waiting too long to start |
| `GitlabPumaQueueHigh` | Queued connections > 10 | 5m | Web server overloaded |
| `GitlabGitalyErrorRateHigh` | gRPC errors > 0.1/s | 5m | Git operations failing |

**Gitaly expr — only counts real errors, ignores expected gRPC codes:**
```
grpc_code!~"OK|NotFound|Unauthenticated|AlreadyExists|FailedPrecondition|Canceled"
```

---

### `postgres` group

| Alert | Condition | For | Meaning |
|---|---|---|---|
| `PostgresqlHighConnections` | Active connections > 200 | 5m | Connection pool exhaustion risk |
| `PostgresqlDown` | `pg_up == 0` | 1m | Postgres exporter cannot connect |

---

### `redis` group

| Alert | Condition | For | Meaning |
|---|---|---|---|
| `RedisHighMemory` | Used / max > 80% | 5m | Redis approaching memory limit |
| `RedisDown` | `redis_up == 0` | 1m | Redis exporter cannot connect |

---

## Reloading Alert Rules

After editing `prometheus/alerts.yml`, apply without restarting:

```bash
curl.exe -X POST http://localhost:9090/-/reload
```

Verify rules loaded at **Prometheus → Status → Rules**.

## Adding a New Alert

```yaml
- alert: MyAlert
  expr: some_metric > threshold
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Short description"
    description: "Detail with value: {{ $value }}"
```

Add it under the relevant group in `prometheus/alerts.yml`, then reload.
