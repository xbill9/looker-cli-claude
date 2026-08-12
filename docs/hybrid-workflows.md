# Hybrid workflows: MCP + Looker CLI

The MCP toolset and the Looker CLI reach the same instance through the same API, but they are good at different halves of a job. MCP knows the semantic model and can reason about what comes back; the CLI runs exactly what you tell it, writes files, loops, and covers the parts of the API that have no MCP tool.

Every recipe below is written as: what MCP does, what the CLI does, and why the split is worth it.

| | MCP (`mcp__looker-managed__*`) | CLI (`./lk`) |
|---|---|---|
| Strength | Discovery, judgement, structured content creation | Scale, files, determinism, full API coverage |
| Results | Land in the conversation | Land on disk |
| Coverage | 40 tools: query, content, LookML dev, health | Everything, including git branches, users, roles, schedules, alerts, connections, deploys |
| Cost | Every row consumes context | Free of context, until you read the file |

The MCP half is the **Looker-managed server**, hosted by the instance at `LOOKER_BASE_URL/mcp`. There is no local MCP server in this project.

---

## 1. Discover with MCP, extract with the CLI

**The problem:** you know what you want in business terms but not which fields it maps to — and the answer is 50k rows you do not want in the conversation.

**MCP** finds the fields:

```
get_models                                  → basic_ecomm
get_explores(basic_ecomm)                   → basic_order_items
get_dimensions(basic_ecomm, basic_order_items)  → basic_users.state, basic_order_items.created_at_date
get_measures(basic_ecomm, basic_order_items)    → basic_order_items.total_sale_price
```

**The CLI** runs it and writes the file. The names carry over unchanged — MCP's `model` / `explore` / `fields` / `filters` become the CLI's `model` / `view` / `fields` / `filters`:

```bash
cat > query.json <<'EOF'
{
  "model": "basic_ecomm",
  "view": "basic_order_items",
  "fields": ["basic_users.state", "basic_order_items.total_sale_price", "basic_order_items.count"],
  "filters": {"basic_order_items.created_at_date": "90 days"},
  "sorts": ["basic_order_items.total_sale_price desc"],
  "limit": "5000"
}
EOF

./lk query runquery --file query.json --format csv --output sales.csv
```

**Why split:** MCP's `query` tool is the right tool for the 20 rows you want to talk about. Past that, every row is context you pay for and truncation you have to work around. The CLI streams the same governed query to a file at any size, and `query.json` is now a reproducible artifact you can commit, schedule, or diff.

**Variation — hand the SQL to someone else.** Same file, different format:

```bash
./lk query runquery --file query.json --format sql
```

That is the exact SQL Looker generates, joins and all. Useful for a warehouse review, a derived table, or explaining to a data engineer what the semantic layer is actually doing. Other formats: `json`, `json_detail`, `txt`, `md`, `html`, `xlsx`, `png`, `jpg`.

---

## 2. Create with MCP, version with the CLI

**The problem:** MCP creates content well — `make_look`, `make_dashboard`, `add_dashboard_element`, `add_dashboard_filter` all take structured arguments and return an ID. But the instance is now the only copy.

**MCP** creates:

```
make_dashboard(title="Regional Sales", ...)  → dashboard id 42
add_dashboard_element(dashboard_id=42, ...)
```

**The CLI** snapshots it:

```bash
./lk dashboard cat 42 --trim --dir ./backup     # ./backup/Dashboard_42_Regional Sales.json
./lk folder export 1 --trim --dir ./backup      # or the whole folder tree
```

**Why split:** `--trim` drops server-assigned noise, so the JSON diffs cleanly between runs and can go in git. You get a review artifact before anything is shared, and a restore path (`dashboard import <file> <folder_id>`) if someone edits it in the UI later. Export also takes `--tar`, `--tgz`, and `--zip` if you would rather have one file.

**Variation — promote between instances.** Export from one instance, import into another using a second profile:

```bash
./lk folder export 1 --trim --dir ./release
./looker-cli --profile staging dashboard import "./release/Folder_1_Shared/Dashboard_42_Regional Sales.json" 5
```

`import` mutates the target instance — confirm the destination folder ID first, and note that `--force` overwrites objects on the server.

---

## 3. Audit with the CLI, fix with MCP, deploy with the CLI

**The problem:** cleaning up LookML needs a full inventory (CLI), judgement about each item (MCP), and a deploy (CLI only).

**The CLI** produces the inventory:

```bash
./lk health vacuum explores --timeframe 90 --csv > unused.csv   # needs System Activity access
./lk project file ls my_project                                 # every file in the project
./lk folder tree 1                                              # what content exists at all
```

**The CLI** opens the branch — the managed MCP server has no git tools:

```bash
./lk api project create_git_branch --project_id my_project --name cleanup-unused-fields
./lk project branch my_project        # confirm the active branch
```

**MCP** reads `unused.csv` from disk and edits in dev mode:

```
dev_mode
get_project_file / update_project_file        (per file)
validate_project → run_lookml_tests
```

**The CLI** ships it:

```bash
./lk project validate my_project      # second opinion, tabular, CSV-able
./lk project deploy my_project        # MCP has no deploy tool
```

**Why split:** the audit is a bulk read that would take dozens of MCP calls; the fix needs a model to decide what is actually safe to remove; branching and deploying exist only in the CLI. `health vacuum` and `health analyze` read the System Activity model and require an admin-level key — if they return *Access Denied*, that is a permissions issue, not a broken command.

The full branch surface, since MCP no longer covers it: `./lk project branch [--all]`, `./lk project checkout <project> <branch>`, and `./lk api project create_git_branch` / `update_git_branch` / `delete_git_branch` / `all_git_branches` / `find_git_branch`.

---

## 4. Reach the API surface MCP does not cover

**The problem:** MCP's 40 tools stop at querying, content, LookML, and health. Users, groups, roles, permission sets, user attributes, schedules, alerts, connections, themes, and sessions are CLI-only.

**The CLI** answers the operational question:

```bash
./lk plan failures                                        # schedules that failed their last run
./lk api scheduledplan search_scheduled_plans --all_users --limit 50
./lk connection test <connection_name>
./lk attribute ls
./lk role ls
```

**MCP** takes it from there — given a failing schedule's `dashboard_id`, `run_dashboard` reproduces the failure against live data, and `get_dimensions` explains whether a filter references a field that no longer exists.

**Why split:** neither half can do this alone. The CLI can see the schedule; only MCP can tell you why the content behind it broke.

Every endpoint in the Swagger spec is reachable as `./lk api <category> <endpoint>`, with the endpoint's parameters as flags. `./lk api` lists categories; `./lk meta search <keyword>` finds commands by name.

---

## 5. Loop with the CLI, reason with MCP

**The problem:** "which of our dashboards still point at the deprecated explore?" — one MCP call per dashboard is slow and expensive.

**The CLI** fetches everything locally, in one pass:

```bash
./lk folder export 1 --trim --dir ./inventory
grep -rl "old_explore_name" ./inventory
```

**MCP** (or Claude reading the files directly) then works over the local JSON rather than the API, and only calls back out to the instance for the handful of objects that actually matter.

**Why split:** turning N API round-trips into one export plus local file reads is the difference between a minute and an afternoon — and the inventory is reusable for the next question.

---

## 6. Two ways to run the same query, deliberately

`query` (MCP) and `query runquery` (CLI) hit the same endpoint. Choose by what happens to the result:

| Want | Use |
|------|-----|
| To read the numbers and reason about them | MCP `query` |
| A file, an image, an xlsx, or the SQL | CLI `query runquery --format ... --output ...` |
| More rows than you want in context | CLI |
| To iterate on filters conversationally | MCP `query`, then freeze the final shape into a `query.json` |

That last row is the pattern worth internalising: explore with MCP, then **freeze the result into a CLI artifact** so it can be re-run without an agent in the loop.

---

## Guardrails

- CLI commands that mutate (`rm`, `import`, `mv`, `deploy`, `create`, `set`, `randomize`, and anything with `--force`) change the live instance exactly as fast as you can type them. Confirm before running them, and prefer `cat`/`export` to a file first.
- `--force` overwrites server objects. Do not add it to make an error message go away.
- Both halves authenticate as the same API3 key, so both are bounded by the same permissions. An *Access Denied* from one will come from the other too.
- Content created through either interface lands in your personal folder unless you name a folder.
