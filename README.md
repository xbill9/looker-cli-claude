# Looker CLI + MCP for Claude Code

This repository wires a Looker instance up to your terminal and to your agent, with two complementary interfaces:

- **[Looker CLI](https://github.com/looker-open-source/looker-cli)** — the primary interface. A single binary covering folders, Looks, dashboards, projects, users, roles, schedules, health checks, and the entire Looker API surface. Scriptable, file-oriented, and exact.
- **[Looker-managed MCP server](https://docs.cloud.google.com/looker/docs/mcp)** — the instance's own MCP endpoint at `LOOKER_BASE_URL/mcp` (40 tools, preview), so Claude Code can explore the semantic model and build queries conversationally. Nothing to install: Looker hosts it.

Neither replaces the other. The CLI is better at *doing things at scale and writing files*; MCP is better at *discovering the model and reasoning about results*. The interesting workflows use both — see [Hybrid workflows](#hybrid-workflows).

> There is no local MCP server here. This project used to run the [MCP Toolbox](https://github.com/googleapis/genai-toolbox) binary over stdio; the Looker-managed endpoint is the same Toolbox software hosted by Google, so the 300 MB download and its credential plumbing were removed in favour of it.

## Prerequisites

- A **Looker instance** with **API3 credentials** (Base URL, Client ID, Client Secret). Create them in Looker under *Admin → Users → (your user) → Edit Keys*.
- `curl`, `make`, and `tar` (used to fetch the CLI binary).
- **Claude Code** (or another MCP client) if you want the MCP half. `.mcp.json` and `.claude/settings.local.json` are already configured for it.
- For the MCP half, the **Looker-managed MCP server enabled** on the instance (*Admin → Platform → Model Context Protocol*). It is in preview, and not available for customer-hosted instances.
- **Google Cloud SDK (`gcloud`)** — optional; only used for the project ID recorded in `.env` and the bundled Google Cloud skills. Neither the CLI nor the MCP server needs it.

## Quick start

```bash
source set_env.sh   # resolve credentials, write .env, export LOOKER_MCP_URL
make cli            # download ./looker-cli (checksum-verified)
./lk user me        # confirm the CLI can reach the instance
```

`set_env.sh` resolves `LOOKER_BASE_URL`, `LOOKER_CLIENT_ID`, and `LOOKER_CLIENT_SECRET` in order — exported env var → cached file in `$HOME` → interactive prompt — then writes them to `.env` (mode 600) and derives `LOOKER_MCP_URL`.

**Source it, don't execute it.** `./lk` only needs `.env`, but Claude Code expands `${LOOKER_MCP_URL}` in `.mcp.json` from its own environment, so that variable has to be exported in the shell you launch `claude` from. Then start `claude` from this directory and the `looker-managed` server connects automatically.

## Using the CLI

`./lk` is a thin wrapper around `./looker-cli` that supplies what the CLI cannot work out for itself. Everything after it is passed straight through, so `./lk <command> --help` works across the whole command tree.

```bash
./lk model ls                       # LookML models
./lk folder tree 1                  # dashboards + Looks under "Shared"
./lk dashboard cat 2 --trim         # a dashboard as JSON
./lk project validate my_project    # LookML validation
./lk --help                         # full command list
```

The wrapper does three things:

1. **Reads `.env`** — the CLI has no env-var support of its own; without this every call needs `--host`, `--client-id`, and `--client-secret` on the command line.
2. **Converts the URL to host + port** — the CLI wants a bare hostname and an explicit port, and its default of `19999` only applies to self-hosted deployments. Hosted instances serve the API on **443**, which is what the wrapper passes (override with `LOOKER_CLI_PORT`).
3. **Authenticates with a session token** — it calls `session login` once, stores the token in `~/.looker_auth` (mode 600), and passes `--token-file` afterwards, so your client secret is not in the process list on every command. Tokens are refreshed after 45 minutes; `./lk login` forces a refresh and `./lk logout` invalidates the stored token.

If a command starts failing with an authentication error, run `./lk login`. The wrapper deliberately does **not** auto-retry, since a blind retry would re-run mutating commands.

### Command map

| Area | Commands | Notes |
|------|----------|-------|
| Content | `folder`, `look`, `dashboard` | `ls`, `tree`, `cat`, `mv`, `rm`, `import`, `export` |
| Queries | `query runquery` | Runs a query definition; `--format json,csv,txt,md,html,xlsx,sql,png,jpg` |
| LookML | `project`, `model` | `branch`, `checkout`, `file`, `validate`, **`deploy`** |
| Admin | `user`, `group`, `role`, `permission`, `attribute`, `session` | No MCP equivalent |
| Ops | `plan`, `alert`, `connection` | Schedules, alerts, connection tests — no MCP equivalent |
| Health | `health analyze`, `health pulse`, `health vacuum` | Needs System Activity access (see below) |
| Raw API | `api <category> <endpoint>` | The full Swagger surface; flags map to the endpoint's parameters |
| Discovery | `meta search`, `meta tree` | Find commands without leaving the shell |

### Output and files

The CLI writes results to disk, which is its main advantage over MCP for anything large:

```bash
./lk query runquery --file query.json --format csv --output sales.csv
./lk dashboard cat 2 --trim --dir ./backup      # one JSON file per object
./lk folder export 1 --trim --dir ./backup      # a whole folder tree
./lk folder export 1 --tgz backup.tgz
```

A query definition is a plain Looker query body — `model`, `view` (the explore), `fields`, and optionally `filters`, `sorts`, `limit`:

```json
{
  "model": "basic_ecomm",
  "view": "basic_order_items",
  "fields": ["basic_users.state", "basic_order_items.total_sale_price"],
  "filters": {"basic_order_items.created_at_date": "90 days"},
  "sorts": ["basic_order_items.total_sale_price desc"],
  "limit": "500"
}
```

`--format sql` returns the generated SQL instead of running the query — useful for review, or for lifting a governed query into a derived table.

### Raw API calls

Anything without a dedicated command is reachable through `api`, generated from the Swagger spec:

```bash
./lk api                                    # list categories
./lk api datagroup all_datagroups
./lk api scheduledplan search_scheduled_plans --all_users --limit 10
./lk api <category> <endpoint> --help       # per-endpoint flags
```

### Without the wrapper

`./lk` is a convenience, not a requirement. Saved profiles work too, and are the better choice if you switch between instances:

```bash
./looker-cli profile add prod     # then: ./looker-cli --profile prod folder top
```

Give the profile port **443** for a hosted instance. Profiles live in the CLI's own `config.yaml` and store credentials on disk — treat that file like `.env`.

### Permissions

CLI commands are bounded by whatever the API3 key's user can do. Two common surprises:

- `health analyze` and `health vacuum` read the **System Activity** model (`i_looker`) and fail with *Access Denied* for non-admin keys. The MCP `health_*` tools hit the same wall.
- `plan ls` returns 404 without the `see_schedules` permission.

## Using the MCP tools

The instance hosts the server itself, so there is nothing to install. `.mcp.json` declares it as `looker-managed`:

```json
{
  "mcpServers": {
    "looker-managed": {
      "type": "http",
      "url": "${LOOKER_MCP_URL}",
      "headersHelper": "${CLAUDE_PROJECT_DIR:-.}/lk headers"
    }
  }
}
```

Its 40 tools cover four areas:

| Area | Tools |
|------|-------|
| Discovery | `get_models`, `get_explores`, `get_dimensions`, `get_measures`, `get_filters`, `get_parameters`, `get_looks`, `get_dashboards`, `get_projects` |
| Querying | `query`, `query_sql`, `query_url`, `run_look`, `run_dashboard` |
| Content | `make_look`, `make_dashboard`, `add_dashboard_element`, `add_dashboard_filter`, `generate_embed_url` |
| LookML & ops | `dev_mode`, `get/create/update/delete_project_file`, `validate_project`, `run_lookml_tests`, `create_view_from_table`, `get_connections`, `health_analyze`, `health_pulse`, `health_vacuum` |

Typical discovery flow: `get_models` → `get_explores` → `get_dimensions` / `get_measures` → `query`.

### Authentication

The documented path is OAuth 2.1 + PKCE, which needs an admin to register an OAuth client. This repo instead reuses the API3 credentials already in `.env`: `./lk headers` mints a one-hour Looker access token and prints `{"Authorization": "Bearer ..."}`, which Claude Code runs as a `headersHelper` on every connection *and* again after a `401`/`403`. Expiry therefore heals itself, where a static `headers` entry would go stale after an hour.

The tradeoff is that every agent action is attributed to the API3 key's user rather than to an individually-authorised one. Switch to OAuth when you move past evaluation — the instance advertises the endpoints at `/.well-known/oauth-authorization-server`.

### What it does not have

Two things the older local server did:

- **Git branch tools** (`create/switch/list/delete/get_git_branch`) — use `./lk project branch`, `./lk project checkout <project> <branch>`, and `./lk api project create_git_branch` / `delete_git_branch` / `update_git_branch`. `./lk session update dev` switches the CLI's workspace.
- **`get_field_value_suggestions`** — query the suggest explore directly, or use `./lk query runquery` against the field.

Preview caveats: no fine-grained scopes (tool access is a global allowlist), no dynamic client registration, fixed server capacity, a ~30-second delay before tool-list changes reach clients, and no support for customer-hosted instances.

## Hybrid workflows

The division of labour that works in practice:

| Use MCP for | Use the CLI for |
|-------------|-----------------|
| Finding the right model, explore, and field names | Running the query once you know them |
| Small result sets you want to reason about | Large result sets, files, images, generated SQL |
| Creating and editing content with structured arguments | Snapshotting, moving, exporting, importing that content |
| Editing LookML files in dev mode | `project deploy`, and anything looped over many objects |
| Interpreting an audit | Producing the audit, and the admin surface MCP does not cover |

Three short examples; [`docs/hybrid-workflows.md`](docs/hybrid-workflows.md) has the full set with commands you can paste.

**Discover with MCP, extract with the CLI.** Ask Claude to find the fields (`get_explores` → `get_dimensions`), then let it write a query JSON and run it through the CLI so the rows land in a file instead of the conversation:

```bash
./lk query runquery --file query.json --format csv --output sales.csv
```

**Create with MCP, version with the CLI.** After `make_dashboard` or `make_look` returns an ID, snapshot the object to disk and diff it against the last known-good copy:

```bash
./lk dashboard cat <id> --trim --dir ./backup
```

**Audit with the CLI, fix with MCP.** Inventory content or LookML with `./lk folder tree`, `./lk project file ls`, or `./lk api ...`, hand the output to Claude, and have it edit files in dev mode via `update_project_file` + `validate_project` — then deploy with `./lk project deploy <project>`, which MCP cannot do.

## Structure

- [lk](lk): CLI wrapper — resolves `.env`, host/port, and session-token auth. **Start here for CLI work.**
- [Makefile](Makefile): `make cli` downloads the checksum-verified Looker CLI into `./looker-cli`; `make login` / `make check` are shortcuts for `./lk`.
- [init.sh](init.sh) / [set_env.sh](set_env.sh): Currently **identical** setup scripts. Each resolves credentials (env var → cached file in `$HOME` → prompt), writes `.env`, derives `LOOKER_MCP_URL`, and exports the variables. Warns if `gcloud` is not authenticated; it does not log you in.
- [.mcp.json](.mcp.json): Declares the `looker-managed` MCP server. Variable references only — **no secrets** — so it is safe to commit.
- [.claude/settings.local.json](.claude/settings.local.json): Enables the MCP server for this project. There is no tool allowlist, so Looker tool calls still prompt.
- [CLAUDE.md](CLAUDE.md) / [GEMINI.md](GEMINI.md): Per-client context and working rules.
- [docs/hybrid-workflows.md](docs/hybrid-workflows.md): Worked CLI + MCP recipes.
- [skills-lock.json](skills-lock.json) + [.agents/skills](.agents/skills): Vendored [Google Cloud skills](https://github.com/google/skills) (BigQuery, Cloud SQL, AlloyDB, Cloud Run, data lineage) for warehouse-side work.
- `vip-dashboard.html`, `vip-dashboard-{light,dark}.png`: Demo output — a standalone HTML dashboard built from Looker query results.
- `looker-cli`: The downloaded CLI binary (~12 MB). Gitignored; never commit it.

## Security notes

- **Secrets live only in `.env`** (gitignored, mode 600) and the cached `$HOME/looker_*.txt` files (mode 600). They are never written into `.mcp.json`.
- The client secret is read with hidden input and masked in script output.
- `./lk` keeps the secret off the command line for normal commands by exchanging it for a session token in `~/.looker_auth` (mode 600). That file is a bearer credential — `./lk logout` invalidates it.
- `./lk headers` prints a live bearer token to stdout by design — it is meant to be consumed by Claude Code's `headersHelper`, not run in a terminal where it lands in scrollback.
- `make cli` verifies the Looker CLI download against the release's published SHA-256 checksums and warns loudly if verification is skipped. Pin with `LOOKER_CLI_VERSION`.
- Every MCP tool call is attributed to the API3 key's user and logged in Looker System Activity and Cloud Audit Logs. Per-user attribution requires OAuth.
- Set `LOOKER_VERIFY_SSL=false` only for instances with self-signed certificates; it defaults to `true` and is honoured by the CLI wrapper.

## License

[MIT](LICENSE), except for the vendored skills under `.agents/skills/`, which come
from [google/skills](https://github.com/google/skills) and remain under their
upstream Apache-2.0 license.
