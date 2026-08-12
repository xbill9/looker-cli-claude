---
title: Looker's Native MCP Server with Claude Code
published: false
series: Looker
date: 2026-08-12 00:00:00 UTC
tags: mcp,looker,claudecode,cli
canonical_url:
cover_image: https://raw.githubusercontent.com/xbill9/looker-cli-claude/main/docs/images/cover-native-mcp.jpg
---

<!--
Cover art: docs/images/cover-native-mcp.jpg — generated with NB2Lite
(gemini-3.1-flash-lite-image, Interactions API, 16:9, thinking_level=high),
then one stateful edit to replace invented commands in the terminal with real
./lk ones. First pass kept at docs/images/cover-native-mcp-v1.jpg.
The raw.githubusercontent URL above resolves from the public repo, so it works
as both the dev.to cover and the inline image in the Medium variant.
-->

# Looker's Native MCP Server with Claude Code

![Looker + MCP — The Native Server with Claude Code](https://raw.githubusercontent.com/xbill9/looker-cli-claude/main/docs/images/cover-native-mcp.jpg)

Looker hosts its own MCP server now. This walks through connecting Claude Code to it, pairing it with the Looker CLI, and being clear-eyed about where the tool set stops.

#### The binary you no longer need

Until recently, connecting an agent to Looker meant running MCP Toolbox as a local binary. You downloaded 292 MB onto your laptop, taught it your API credentials, launched it as a stdio subprocess, and kept it updated forever. Every developer needed their own copy, and the server ran on your side of the wire.

Looker closed that gap. Every Looker (Google Cloud core) and Looker (original) instance now exposes an MCP endpoint on its own base URL:

```plaintext
https://780eb09e-7dab-4076-9ec1-ecf9d8414630.looker.app/mcp
```

That is the entire install. Ask the endpoint who it is and the joke lands:

```shell
curl -s -X POST "$LOOKER_MCP_URL" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{
        "protocolVersion":"2025-06-18","capabilities":{},
        "clientInfo":{"name":"probe","version":"0"}}}'
```

```json
{"jsonrpc":"2.0","id":1,"result":{
  "protocolVersion":"2025-06-18",
  "capabilities":{"tools":{"listChanged":false},"prompts":{"listChanged":false}},
  "serverInfo":{"name":"Toolbox","version":"1.4.0+container.release.linux.amd64.d67cfbe"}}}
```

`"name":"Toolbox"`. It is the same software. Google moved it to the other end of the connection and took over running it. Migrating is not a bet on new technology — it is the server you were already running, minus the operational burden.

#### Before you start

Three things, and only the first needs someone else.

**An admin has to switch the server on.** It lives at **Admin → Platform → Model Context Protocol**. That page also holds the allowlist of which tools agents may call. A tool switched off there does not exist as far as any client is concerned.

**You need API3 credentials** — Base URL, Client ID, Client Secret. Looker admin panel, *Users → (your user) → Edit Keys*.

**Note the preview limits** before you plan around them. Customer-hosted instances are not supported. There are no fine-grained scopes — tool access is one global allowlist, not per-user or per-group. Tool-list changes take about 30 seconds to reach clients, which then have to reconnect.

#### Setup, start to finish

**1. Resolve credentials.** The setup script prompts for anything it cannot find, writes `.env` at mode 600, and derives `LOOKER_MCP_URL` from your base URL:

```shell
source set_env.sh
```

Source it, do not execute it. The reason matters and catches everyone once — see step 4.

**2. Install the Looker CLI.** Checksum-verified into the project root:

```shell
make cli
```

```plaintext
looker-cli 0.4.8
```

**3. Smoke-test the credentials** before involving an agent. If this fails, nothing downstream will work:

```shell
./lk user me
```

```plaintext
+----+--------------+-------------+----------+
| ID | DISPLAY NAME | IS DISABLED | ROLE IDS |
+----+--------------+-------------+----------+
| 3  | xbill work   | false       | 8        |
|    |              |             | 4        |
|    |              |             | 149      |
+----+--------------+-------------+----------+
```

**4. Register the server with Claude Code.** The whole configuration is four lines, and it holds no secrets:

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

Compare that with what it replaced: a `bash -c` wrapper that sourced `.env`, checked three variables, and exec'd a 292 MB binary with `--stdio --prebuilt looker,looker-dev`. Also gone is `startup_timeout_sec` — it existed because the binary had to boot and handshake before the client would call it ready. An endpoint that is already running has nothing to wait for.

Two fields are doing real work here.

`headersHelper` names a *command*, not a static value. Claude Code runs it on every connection, and again automatically after a `401` or `403`, retrying the call once with fresh headers. Looker access tokens live one hour; this makes expiry heal itself. A stale token becomes one 401 you never see.

`${LOOKER_MCP_URL}` is expanded **by Claude Code itself**, not by a shell. A stdio server could source `.env` inside its own wrapper; a remote server has no wrapper. The variable must exist in the environment of the process you launch `claude` from — which is exactly why step 1 says *source*, not execute. If your tools are missing, check this first.

**5. Verify.** Start Claude Code and run `/mcp`. You should see `looker-managed` connected with 40 tools. The endpoint will confirm the count itself, without credentials:

```shell
curl -s -X POST "$LOOKER_MCP_URL" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | jq '.result.tools | length'
```

```plaintext
40
```

Metadata is open — `initialize` and `tools/list` answer unauthenticated, which is what lets a client discover the server before signing in. `tools/call` refuses without a token. Nothing touches data anonymously.

One note on what this authentication actually is. `./lk headers` exchanges your API3 key for a short-lived Looker access token. It works, and it is the right call for evaluation, but every action is attributed to the API3 key's user rather than the human who asked. For a shared instance, register an OAuth client instead — the instance advertises the endpoints at `/.well-known/oauth-authorization-server` and uses PKCE, so there is no client secret to store.

#### An example: from question to file

Here is the pattern the whole setup exists to support. Start with a question, not a query.

> Which product categories drive the most revenue?

Claude walks the semantic model. `get_models` returns the instance inventory:

```plaintext
basic_ecomm, intermediate_ecomm, advanced_ecomm       sample_thelook_ecommerce
london_bicycles                                       london_bicycles
gcp_billing_block                                     marketplace_gcp-billing
bq_agent_analytics                                    agent_events
```

`get_explores` on `advanced_ecomm` narrows it to two, and `get_measures` returns the aggregates that actually exist — `order_items.total_sale_price`, `order_items.count`, `order_items.average_sale_price`. No guessing at column names, and no SQL. The agent is reading the same governed definitions your dashboards use.

Then `query` runs it:

```json
{"products.category":"Outerwear & Coats","order_items.total_sale_price":971454.48,
 "order_items.count":6711,"order_items.average_sale_price":144.76}
{"products.category":"Jeans","order_items.total_sale_price":924765.39,
 "order_items.count":9428,"order_items.average_sale_price":98.09}
{"products.category":"Sweaters","order_items.total_sale_price":630197.03,
 "order_items.count":8476,"order_items.average_sale_price":74.35}
```

Outerwear leads on revenue with a third fewer items sold than Jeans, because it carries a 48% higher average price. That is the kind of read worth having an agent for: the rows are in its context, so it can reason about them.

**Now hand it to the CLI.** The query shape is settled, so freeze it. Same fields, same sorts, in a file the CLI understands:

```json
{
  "model": "advanced_ecomm",
  "view": "advanced_example_ecommerce",
  "fields": [
    "products.category",
    "order_items.total_sale_price",
    "order_items.count",
    "order_items.average_sale_price"
  ],
  "sorts": ["order_items.total_sale_price desc"],
  "limit": "6"
}
```

```shell
./lk query runquery --file q.json --format csv --output category-revenue.csv
```

```plaintext
Products Category,Order Items Sales,Order Items # of Order Items,Order Items Average Price
Outerwear & Coats,971454.4791278839,6711,144.75554747845126
Jeans,924765.3913908005,9428,98.08712254887557
Sweaters,630197.0301675797,8476,74.35075863232427
```

Identical numbers, different destination. That is the entire argument for running both.

The `view` key is the one spelling trap — the CLI calls the explore `view`, while `model`, `fields`, `filters` and `sorts` match MCP exactly.

**Why bother with the second interface at all?** Because the two differ in what happens to the answer, not in what they can reach. Same instance, same API3 key, same REST API underneath.

| | Native MCP (`looker-managed`) | CLI (`./lk`) |
|---|---|---|
| Coverage | 40 tools: query, content, LookML dev, health | The whole API — git, users, roles, schedules, connections, deploys |
| Results land | In the model's context | On disk |
| Cost | Every row consumes context | Free of context until you read the file |
| Good at | Discovery, judgement, structured content creation | Scale, files, determinism, repeatability |
| Bad at | Bulk output, anything admin-shaped | Deciding what to ask for |

**Discover and decide over MCP, execute and persist with the CLI.** Asking an agent which explore holds revenue by cohort is worth twenty minutes of clicking through the Explore UI. Routing 40,000 rows through its context is not. Once the shape is settled, the CSV job runs forever with no agent in the loop and no tokens burned.

The two also meet at the credential: `./lk headers` is what authenticates the MCP server in the first place. The CLI is not a second path bolted on beside MCP — it is what gets MCP connected.

#### Native vs MCP Toolbox

| | MCP Toolbox (local binary) | Native (Looker-hosted) |
|---|---|---|
| Install | 292 MB download per machine, updated forever | A URL |
| Transport | stdio subprocess | Streamable HTTP |
| Version | You pin it — currently v1.8.0 | Google pins it — currently 1.4.0 |
| Tools | 46, from `--prebuilt looker,looker-dev` | 40, from the admin allowlist |
| Governance | Client-side, per developer, advisory | Admin panel, instance-wide, enforced |
| Auth | API3 key in the subprocess environment | Bearer token, or OAuth 2.1 + PKCE |
| Failure mode | "Why won't the server start" | "Why is the endpoint slow" |

Two rows deserve more than a table cell.

**Version is the real trade.** The hosted server reports 1.4.0 while the downloadable binary is on v1.8.0. You stop patching, and you also stop choosing. If you depend on something that landed in Toolbox after 1.4.0, stay where you are for now.

**Governance is the real win.** With a downloaded Toolbox, the tool set was whatever `--prebuilt` shipped, and any restriction had to be re-implemented in every client by every developer who installed it. Now a tool switched off in the admin panel does not exist for anyone. That is the difference between a policy and a suggestion.

Migrating is mostly deletion: add the new server, move your git workflow to the CLI, then delete the binary, the download step, the launcher script and the `toolbox` line in `.gitignore`. In this repo that removed 292 MB, a checksum routine, a stdio wrapper, and an entire class of "why won't the server start" support question.

#### What MCP cannot do

The gaps are not random. The server covers Looker as a *semantic model* and stops at the edge of Looker as an *administered system*.

**Git, entirely.** `list_git_branches`, `get_git_branch`, `create_git_branch`, `switch_git_branch` and `delete_git_branch` all shipped with the local binary. The managed server exposes none of them. File editing and `dev_mode` are present, so the agent can write LookML — it just cannot get itself onto a branch to write it safely. The CLI covers that half:

```shell
./lk api project create_git_branch --project_id my_project --name my_branch
./lk project checkout my_project my_branch
```

**Commit is missing from both, and that one is not an MCP limitation.** The Looker API has no commit endpoint at all. Search the CLI's entire surface and you get deploy verbs:

```shell
./lk meta search commit
```

```plaintext
Found 7 matching commands:
  looker-cli api project create_git_branch     - Checkout New Git Branch
  looker-cli api project deploy_to_production  - Deploy To Production
  looker-cli api project tag_ref               - Tag Ref
  looker-cli api project update_git_branch     - Update Project Git Branch
  ...
```

So the agent creates the branch, writes the files, validates them and runs the tests — then stops. Committing the workspace is an IDE operation. The loop that looks like it should close (branch → edit → validate → commit → deploy) closes at every step except the second to last, and that step needs a browser.

Plan around it rather than fighting it. The agent does the branch, the edits, the validation and the tests; a human commits in the Looker IDE; the terminal deploys:

```shell
./lk project deploy my_project
```

`deploy_to_production` never had an MCP equivalent either, so the deploy was always a CLI call. The commit is the only step neither interface can reach.

**`get_field_value_suggestions`.** Gone. To find valid filter values, query the field's suggest explore directly — `get_dimensions` names it in the `suggest_explore` and `suggest_dimension` attributes of any suggestable field.

**The entire administrative surface.** Users, groups, roles, permissions, user attributes, schedules, alerts, connections, themes and sessions have no MCP tools and never did. Every one is a `./lk api` call.

Two permission failures look like bugs and are not: `health_analyze` and `health_vacuum` need System Activity access and return *Access Denied* without it, and `plan ls` returns 404 without `see_schedules`.

Everything else — discovery, querying, content creation, LookML files, validation, tests, health — is present and works.

#### Summary

The native install is a smaller thing to own than what it replaced. A 292 MB download, a stdio wrapper and a `--prebuilt` flag collapsed into a URL and a `headersHelper`. Google patches the server, the admin panel governs which tools exist, and System Activity logs what the agent did.

What you give up is specific and covered: five git tools and `get_field_value_suggestions`, all of which the CLI handles. What you should fix before production is the auth shortcut — swap the API3 token helper for a registered OAuth client so actions are attributed to a person rather than a key.

The durable lesson is the division of labor. The MCP server is for discovery and judgement; the CLI is for execution and persistence. Install only one and you will find the seam within a week — most likely on a Tuesday afternoon, halfway through a LookML change, at the commit step.

#### References

* [Looker-managed MCP server | Google Cloud Documentation](https://docs.cloud.google.com/looker/docs/mcp)
* [Admin settings — Model Context Protocol (MCP) | Google Cloud Documentation](https://docs.cloud.google.com/looker/docs/admin-panel-platform-mcp)
* [Looker CLI | GitHub](https://github.com/looker-open-source/looker-cli)
* [MCP Toolbox for Databases | GitHub](https://github.com/googleapis/genai-toolbox)
