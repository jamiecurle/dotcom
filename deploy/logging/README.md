# Centralised logging — Grafana Alloy → Grafana Cloud Loki

Ships every Docker container log from the Swarm cluster off the Raspberry Pi
nodes into [Grafana Cloud Loki](https://grafana.com/products/cloud/logs/)'s free
tier.

[Grafana Alloy](https://grafana.com/docs/alloy/latest/) runs as a Swarm
**global** service — one task per node. Each task talks to its own local Docker
daemon, discovers all containers, tails their logs, attaches clean labels, drops
`/health` probe noise, and pushes the rest to Loki over basic auth.

```
┌─ pi node ─────────────┐
│ containers → Alloy ───┼──▶ Grafana Cloud Loki ──▶ Grafana Explore (LogQL)
│ (docker.sock, ro)     │       (basic auth)
└───────────────────────┘   one Alloy task per node
```

## Files

| File                  | Purpose                                              |
| --------------------- | ---------------------------------------------------- |
| `config.alloy`        | Alloy pipeline: discover → relabel → drop → write    |
| `logging-stack.yml`   | Swarm stack: global Alloy service, config, secret    |
| `logging.env.tpl`     | 1Password secret references for `LOKI_URL`/`USERNAME` |
| `README.md`           | This runbook                                         |

## Credentials live in 1Password

Nothing sensitive is committed. Store the three Grafana Cloud values as fields
on a 1Password item (e.g. vault **Homelab**, item **Grafana Cloud Loki**), then:

- `LOKI_URL` / `LOKI_USERNAME` are injected at deploy time by `op run`, which
  resolves the `op://…` references in `logging.env.tpl`.
- the **token** is piped straight from `op read` into a Docker secret, so it
  never touches disk or the repo.

Adjust the vault/item/field names in `logging.env.tpl` and the `op read` command
below to match your vault layout.

## One-time setup

### 1. Get your Grafana Cloud Loki credentials

In Grafana Cloud: **Connections → Add new connection → Loki** (or **Hosted
logs**). You'll get three things, all of which go into your 1Password item:

- **Push URL** — e.g. `https://logs-prod-012.grafana.net/loki/api/v1/push`
  → field referenced by `LOKI_URL` in `logging.env.tpl`.
- **Username / User** — a numeric instance id, e.g. `123456`
  → field referenced by `LOKI_USERNAME` in `logging.env.tpl`.
- **Token / Password** — a `glc_...` API token (generate one with the
  `logs:write` scope) → read by `op read` into the Docker secret below.

### 2. Point the env template at your vault

Edit `logging.env.tpl` so the `op://` references match your vault/item/field
names. It holds references only (no values), so it stays in the repo.

### 3. Create the token secret from 1Password

```sh
op read "op://Homelab/Grafana Cloud Loki/token" | docker secret create grafana_cloud_token -
```

Piping from `op read` keeps the token off disk. The stack references this secret
as `external: true`, so it must exist before you deploy. To rotate it:
`docker secret rm grafana_cloud_token` then re-create from 1Password and
redeploy (a secret can't be updated in place).

## Deploy

`op run` resolves `logging.env.tpl` into `LOKI_URL` / `LOKI_USERNAME` for the
deploy command, which the stack file picks up via `${VAR}` interpolation:

```sh
op run --env-file=deploy/logging/logging.env.tpl -- \
  docker stack deploy -c deploy/logging/logging-stack.yml logging
```

Re-running the same command is the upgrade path — it's idempotent. (If you ever
deploy outside `op run`, the stack will fail fast: `LOKI_URL`/`LOKI_USERNAME`
are marked required via `${VAR?…}`.)

## Verify

```sh
# Expect: MODE = global, REPLICAS = N/N where N = number of nodes.
docker stack services logging

# Expect one running task per node, each "Running".
docker service ps logging_alloy
```

Then check logs are landing in Grafana: **Explore → Loki** and run
`{job="docker"}`.

### Per-node debug UI

Each Alloy task publishes its UI on its own node (`mode: host`):

```
http://<node>:12345
```

Open the **Graph** tab to see the `discovery.docker → loki.source.docker →
loki.process → loki.write` pipeline and confirm components are healthy. If you'd
rather not expose it, delete the `ports:` block in `logging-stack.yml`.

## Example LogQL queries

```logql
{job="docker"}                       # everything we ship
{swarm_service="jamie_web"}          # just the web app (swarm service name)
{node="stekpi"} |= "error"           # one Pi, lines containing "error"
{compose_project="logging"}          # Alloy's own logs
{swarm_service="jamie_web"} |= "oban" # Oban job logs (emitted as JSON lines)
```

> Label names come straight from `config.alloy`: `container`, `swarm_service`,
> `compose_project`, `compose_service`, `node`, `job`. The Swarm service name is
> `<stack>_<service>` — e.g. deploying the app stack as `jamie` makes
> `swarm_service="jamie_web"`.

## Log format notes

- **App / Phoenix logs** are plain console lines
  (`$time $metadata[$level] $message`).
- **Oban logs** are emitted by Oban's default telemetry logger as **JSON
  objects on a single line** (with `"source":"oban"`), not plain text. They flow
  through untouched — use `| json` in LogQL to parse fields, e.g.
  `{swarm_service="jamie_web"} | json | worker != ""`.

No structured/JSON logging library (e.g. `LoggerJSON`) is in use for the app's
own logs, so this config assumes plain console output and does not do
app-wide JSON parsing.

## Free-tier quota & the `/health` drop

Grafana Cloud's free tier includes ~**50 GB/month** of log ingest. The Swarm
healthcheck hits `GET /health` every 30s on every web replica, which is a
surprising amount of noise over a month.

`config.alloy` has a `loki.process` stage with `stage.drop` that drops lines
matching the `/health` path **before** they're shipped, so they never count
against the quota. Normal app logs and Oban logs are untouched.

Caveat: Phoenix logs each probe as two lines sharing a request_id —
`GET /health` and a companion `Sent 200 in …µs`. Alloy's `stage.drop` is
stateless, so it drops the path line (`GET /health`) but can't correlate and
drop the companion `Sent 200` line. That residual is tiny; the bulk of the
volume is removed.

## Non-standard Docker socket path

The config and stack assume the standard daemon socket at
`/var/run/docker.sock`. **Rootless Docker** and some PaaS/Coolify setups put it
elsewhere, e.g.:

- rootless: `/run/user/<uid>/docker.sock` (or `$XDG_RUNTIME_DIR/docker.sock`)

If your hosts differ, update **both** places to match:

1. the volume mount source in `logging-stack.yml`
   (`/var/run/docker.sock:/var/run/docker.sock:ro`), and
2. the `host = "unix:///var/run/docker.sock"` lines in `config.alloy`
   (`discovery.docker` and `loki.source.docker`).

Keep the in-container target (`/var/run/docker.sock`) the same and only change
the host source side, so `config.alloy` needs no change unless the in-container
path moves.
