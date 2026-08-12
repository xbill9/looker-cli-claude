# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

A **setup/glue** project that connects a Looker instance to the terminal and to MCP clients. There is no application code — the repo's job is to install one binary, resolve one set of credentials, and make both interfaces usable:

- **`./looker-cli`** (driven through the `./lk` wrapper) — the primary interface. Covers the whole Looker API.
- **The Looker-managed MCP server** — the instance's own endpoint at `${LOOKER_MCP_URL}` (40 tools, preview). Nothing is installed locally; `./lk headers` authenticates it.

The user is a **Looker developer** (LookML, Looker administration, embedding). Prefer governed, semantic-layer answers over ad-hoc SQL.

## Layout

- `lk` — CLI wrapper: sources `.env`, converts `LOOKER_BASE_URL` into host + port 443, logs in once via `session login`, and passes `--token-file` thereafter so the client secret stays out of the process list. Passes all arguments through, so `./lk <cmd> --help` works.
- `init.sh`, `set_env.sh` — **currently byte-for-byte identical** bash setup scripts (credential resolution → write `.env` → derive `LOOKER_MCP_URL` → export vars). If you change one, change both or dedupe them.
- `Makefile` — `make cli` downloads the Looker CLI to `./looker-cli` (gitignored, SHA-256 verified; pin with `LOOKER_CLI_VERSION`). `make login` / `make check` wrap `./lk`.
- `.mcp.json` — declares one MCP server, secret-free and **safe to commit**: `looker-managed`, the instance-hosted endpoint at `${LOOKER_MCP_URL}`, authenticated by a `headersHelper` that runs `./lk headers`. Claude Code expands the `url` in its own process, so `LOOKER_MCP_URL` must be exported (`source set_env.sh`) in the shell that launches `claude` — `.env` alone is not enough for this server.
- `.claude/settings.local.json` — enables the MCP server. There is **no** tool allowlist, so Looker tool calls still prompt.
- `README.md` — user-facing setup and usage; update it whenever `lk`, `init.sh`, `set_env.sh`, or the `Makefile` change.
- `docs/hybrid-workflows.md` — worked CLI + MCP recipes. Keep it in sync with what the tools actually do.
- `skills-lock.json` + `.agents/skills/` — vendored Google Cloud skills (BigQuery, Cloud SQL, AlloyDB, etc.).
- `vip-dashboard.html`, `vip-dashboard-{light,dark}.png` — committed demo output built from Looker query results.
- `looker-cli` — downloaded binary (gitignored, ~12 MB).

## Setup

```bash
source set_env.sh   # credentials + .env + LOOKER_MCP_URL
make cli            # ./looker-cli
./lk user me        # smoke test
```

`./lk` needs only `.env`, but the MCP server needs `LOOKER_MCP_URL` exported in the shell that launches `claude`, because Claude Code expands `${...}` in a remote server's `url` itself. **Source, don't execute** — and if MCP tools are missing, that export is the first thing to check.

## Choosing an interface

Both hit the same API as the same API3 key. Pick by what should happen to the result.

| Task | Interface |
|------|-----------|
| Find models, explores, dimensions, measures | MCP (`get_models` → `get_explores` → `get_dimensions`/`get_measures`) |
| Run a query whose rows you need to reason about | MCP `query` |
| Run a query for a file, image, xlsx, or generated SQL — or for many rows | `./lk query runquery --file q.json --format ... --output ...` |
| Create Looks/dashboards from structured arguments | MCP (`make_look`, `make_dashboard`, `add_dashboard_element`) |
| Snapshot, move, export, import, or bulk-inventory content | `./lk` (`dashboard cat --trim --dir`, `folder export`) |
| Edit LookML files in dev mode | MCP (`dev_mode`, `get/create/update/delete_project_file`) |
| **Create, switch, or delete a git branch** | `./lk` — the managed server has no git tools |
| Validate LookML | Either (`validate_project` / `./lk project validate`) |
| **Deploy a project to production** | `./lk project deploy` — MCP has no deploy tool |
| Users, groups, roles, permissions, user attributes, schedules, alerts, connections, themes, sessions | `./lk` — no MCP equivalent |
| Anything else in the API | `./lk api <category> <endpoint>` |

Default heuristic: **discover and decide with MCP, execute and persist with the CLI.** When a query shape is settled, freeze it into a `query.json` the CLI can re-run without an agent.

## CLI usage rules

- Always invoke through `./lk`, not `./looker-cli` directly — the bare binary defaults to `localhost:19999` with no credentials. The exception is a second instance, which needs `./looker-cli --profile <name>`.
- Use `./lk meta search <keyword>` or `./lk <cmd> --help` to check a command's real flags before running it. Do not guess flag names.
- Query definitions use `view` for the explore name; `model`, `fields`, `filters`, and `sorts` match MCP's spelling exactly.
- Write bulk output to a file and read the file — do not page large results through the terminal.
- **Mutating commands** (`rm`, `mv`, `import`, `create`, `set`, `deploy`, `randomize`, anything with `--force`) change the live instance. Confirm with the user first and report back the resulting IDs/URLs.
- `--force` overwrites server objects; never add it to silence an error.
- `health analyze` / `health vacuum` need System Activity (`i_looker`) access and fail with *Access Denied* for non-admin keys; `plan ls` returns 404 without `see_schedules`. These are permissions limits, not bugs — say so rather than retrying.
- If a command fails to authenticate, run `./lk login` (the wrapper does not auto-retry, by design).

## MCP tool usage rules

- Typical discovery flow: `get_models` → `get_explores` → `get_dimensions` / `get_measures` → `query`.
- **Query values are passed bare** — do not wrap filter/parameter values in extra quotes (a `parameter` value is `first_touch`, not `"first_touch"`). Filter keys are fully-qualified `view.field`.
- **Content-creation and dev tools mutate the live instance** (`make_*`, `add_dashboard_*`, `create/update/delete_project_file`, git and dev-mode tools). Confirm before creating/altering/deleting Looker content, and report back the returned IDs/URLs.
- Looks are created in the user's **personal folder** unless a `folder` is given; titles must be unique.
- For LookML edits, work in **dev mode on a branch**. The branch half is CLI-only now: `./lk api project create_git_branch --project_id <p> --name <branch>` (or `./lk project checkout <p> <branch>` for an existing one) → MCP `dev_mode` → edit files → `validate_project` → `run_lookml_tests` → `./lk project deploy <p>`.
- `get_field_value_suggestions` does not exist on the managed server. Get valid filter values by querying the field's suggest explore, or with `./lk query runquery`.
- The instance URL is `LOOKER_BASE_URL` in `.env`; content links are `<base>/dashboards/<id>` and `<base>/looks/<id>`.

## Conventions & guardrails

- **Never commit secrets.** `.env`, `$HOME/looker_*.txt`, `~/.looker_auth`, and the CLI's own `config.yaml` hold credentials — keep them out of git and out of command output. `.mcp.json` must stay secret-free (`${VAR}` only). `looker-cli` is a gitignored binary.
- `~/.looker_auth` holds a bearer token, not just a cache. Do not print its contents; invalidate with `./lk logout`.
- `./lk headers` prints a live bearer token to stdout for Claude Code's `headersHelper`. Do not run it to "check" something — its output is a credential.
- When editing the setup scripts or `lk`, preserve the security posture: `umask 077`, mode 600 on credential files, hidden secret input, masked echo, and no secrets in argv for routine commands.
- LookML guidance (from `GEMINI.md`): clean hierarchy, reuse dimensions/measures with `extends`, document fields with `description`, mind access/security filters, use datagroups for caching, and use the Embed SDK for SSO embedding.
- No test suite or build exists. "Verifying" a change means running `./lk user me` plus one read-only command, and confirming the MCP server still starts and answers `get_models`.
