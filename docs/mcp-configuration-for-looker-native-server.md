---
title: The Native Looker MCP Server
published: false
series: Looker
date: 2026-08-12 00:00:00 UTC
tags: mcp,looker,lookml,cli
canonical_url:
cover_image:
---

# The Native Looker MCP Server

*Looker now hosts its own MCP server. Here is what that changes, what it costs, and how to connect Claude Code, Codex and Gemini CLI to it.*

#### The 292 MB elephant

Every previous paper in this series began the same way: download a binary.

MCP Toolbox is a fine piece of software — the "swiss army knife" that connects data sources to MCP — but the shape of the integration was always slightly wrong. To let an agent talk to a hosted analytics platform, you downloaded 292 MB onto your laptop, taught it your API credentials, launched it as a subprocess over stdio, and then kept it updated forever. The server ran on your side of the wire, and every client machine needed its own copy.

Looker has closed that gap. The instance now hosts the MCP server itself.

```plaintext
https://your-instance.looker.app/mcp
```

That is the whole install. There is nothing to download.

#### What is actually running there

It is worth being precise, because the answer is funnier than you might expect. Ask the endpoint to introduce itself:

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

`"name":"Toolbox"`. It is the same software. Google simply moved it to the other end of the connection and took over running it.

That reframes the decision. Moving to the native server is not a bet on new technology — it is the same server you were already running, minus the operational responsibility. What you are actually trading is **version control for maintenance**: the hosted server reports 1.4.0 while the current downloadable binary is 1.8.0, and you no longer choose when that changes.

#### Turning it on

The server is admin-gated. An admin enables it at:

**Admin → Platform → Model Context Protocol**

That page also holds the allowlist of which AI tools agents may call. This is the governance story, and it is better than what the local binary offered: with a downloaded Toolbox, the tool set was whatever `--prebuilt looker,looker-dev` shipped, and any restriction had to happen in the client. Now a tool switched off in the admin panel does not exist as far as any client is concerned.

Preview caveats, all of which matter for planning:

* Customer-hosted (on-premise) instances are **not supported**.
* There are **no fine-grained scopes** yet — tool access is a single global allowlist, not per-user or per-group.
* **Dynamic Client Registration is unavailable**, so OAuth clients must be registered by an admin.
* Tool-list changes take about **30 seconds** to reach clients, which must then reconnect.
* Server capacity is fixed, so timeouts are possible under load.

#### Authentication: the honest version

The documented path is **OAuth 2.1 with PKCE**. The instance advertises everything a client needs:

```shell
curl -s "$LOOKER_BASE_URL/.well-known/oauth-authorization-server"
```

```json
{"issuer":"https://your-instance.looker.app",
 "authorization_endpoint":"https://your-instance.looker.app/auth",
 "token_endpoint":"https://your-instance.looker.app/api/token",
 "response_types_supported":["code"],
 "grant_types_supported":["authorization_code","refresh_token"],
 "token_endpoint_auth_methods_supported":["client_secret_basic","none"],
 "scopes_supported":["cors_api","api"],
 "code_challenge_methods_supported":["S256"]}
```

`"none"` in `token_endpoint_auth_methods_supported` and `S256` in `code_challenge_methods_supported` are PKCE's signature: a public client, no client secret. There is a matching `/.well-known/oauth-protected-resource` document, which is how a spec-compliant MCP client discovers where to authenticate.

OAuth is the right answer, and it has a real benefit beyond ceremony: **actions are attributed to the human who authorised them**, in System Activity and in Cloud Audit Logs. It has one real cost: an admin must register each agent as an OAuth client by hand, because Dynamic Client Registration is not available in preview.

For evaluation there is a shorter road. The endpoint accepts an ordinary Looker API access token as a bearer credential:

```shell
curl -s -X POST "$LOOKER_MCP_URL" \
  -H "Authorization: Bearer $LOOKER_MCP_TOKEN" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call",
       "params":{"name":"get_models","arguments":{}}}'
```

Two things are worth noticing about the endpoint's behaviour. `initialize` and `tools/list` answer **without** credentials — metadata is open, which is what lets a client discover the server before authenticating. But `tools/call` refuses:

```json
{"jsonrpc":"2.0","id":2,"error":{"code":-32600,
 "message":"missing access token in the 'Authorization' header"}}
```

Nothing touches data without a token. The tradeoff of the bearer-token shortcut is attribution: every agent action is recorded against the API3 key's user rather than an individual. Fine for a proof of concept, wrong for a team.

#### The token lifetime problem

Looker access tokens live for one hour. This is the single practical wrinkle of the bearer approach, and how well a client handles it varies a lot.

The repo's CLI wrapper mints tokens from the API3 credentials already in `.env`:

```shell
./lk token      # bare token
./lk headers    # {"Authorization": "Bearer ..."}
```

Both are credentials on stdout. They are meant to be consumed by a client, not read in a terminal where they land in scrollback.

**Claude Code** solves expiry properly. Its `headersHelper` field names a *command* rather than a static value, and it runs that command on every connection — and again automatically after a `401` or `403`, retrying the call once with fresh headers:

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

Expiry heals itself. A stale token produces one 401 that you never see.

One trap here, and it catches everyone once: `${LOOKER_MCP_URL}` is expanded **by Claude Code itself**, not by a shell. A stdio server can source `.env` inside its own wrapper script; a remote server has no wrapper. The variable must exist in the environment of the process you launch `claude` from — which is why the setup script is *sourced*, not executed.

**Codex** takes an environment variable instead of a command:

```toml
[mcp_servers."looker-managed"]
url = "https://your-instance.looker.app/mcp"
bearer_token_env_var = "LOOKER_MCP_TOKEN"
enabled = true
tool_timeout_sec = 120
default_tools_approval_mode = "writes"
```

```shell
export LOOKER_MCP_TOKEN=$(./lk token)
codex
```

Simpler config, worse expiry story: when the hour is up, Codex starts returning 401s and you re-export and restart. `default_tools_approval_mode = "writes"` is the line worth copying regardless of transport — discovery and queries run unattended, anything that mutates the instance stops and asks.

**Gemini CLI** registers it in one command:

```shell
gemini mcp add --transport http looker "$LOOKER_MCP_URL"
```

Notice what disappeared from all three configs: `startup_timeout_sec`. It existed because a 292 MB binary had to boot and handshake before the client would call the server ready. An endpoint that is already running has nothing to wait for.

#### The tool set: 40, not 46

The managed server exposes 40 tools. The local `looker,looker-dev` toolsets expose 46. The difference is not random, and you should know it before planning a LookML workflow.

**Metadata / Discovery (9)**
`get_models`, `get_explores`, `get_dimensions`, `get_measures`, `get_filters`, `get_parameters`, `get_dashboards`, `get_looks`, `get_projects`

**Querying / Running (7)**
`query`, `query_sql`, `query_url`, `run_look`, `run_dashboard`, `run_lookml_tests`, `get_lookml_tests`

**Connections / Introspection (5)**
`get_connections`, `get_connection_databases`, `get_connection_schemas`, `get_connection_tables`, `get_connection_table_columns`

**Content creation (6)**
`make_look`, `make_dashboard`, `add_dashboard_element`, `add_dashboard_filter`, `create_view_from_table`, `generate_embed_url`

**LookML project & files (9)**
`get_project_files`, `get_project_file`, `create_project_file`, `update_project_file`, `delete_project_file`, `get_project_directories`, `create_project_directory`, `delete_project_directory`, `validate_project`

**Development mode (1)**
`dev_mode`

**Health (3)**
`health_analyze`, `health_pulse`, `health_vacuum`

The six that are absent:

* **`create_git_branch`, `switch_git_branch`, `list_git_branches`, `get_git_branch`, `delete_git_branch`** — the entire git group.
* **`get_field_value_suggestions`** — valid-value lookups for filterable fields.

#### Closing the gap with the CLI

The missing six are not a dead end, because the [Looker CLI](https://github.com/looker-open-source/looker-cli) covers every one of them:

```shell
./lk project branch my_project --all                 # list branches
./lk project checkout my_project my_branch           # switch
./lk api project create_git_branch \
     --project_id my_project --name my_branch        # create
./lk api project delete_git_branch --project_id my_project --branch_name old
```

So the LookML loop gains one step and loses nothing:

1. **CLI** — open the branch.
2. **MCP** — `dev_mode`, read and edit files, `validate_project`, `run_lookml_tests`.
3. **CLI** — `./lk project deploy my_project`.

That third step was always CLI-only; no version of the MCP server, hosted or local, has ever had a deploy tool. Which is the general lesson of this series: the MCP server is for discovery and judgement, and the CLI is for execution and persistence. The native server sharpens that division rather than changing it.

For `get_field_value_suggestions`, query the field's suggest explore directly — `get_dimensions` tells you which explore and dimension to use, in the `suggest_explore` and `suggest_dimension` attributes of any suggestable field.

#### Migrating from the local binary

A short checklist, in the order that avoids breaking things:

1. **Enable the server** in Admin → Platform → MCP, and check the tool allowlist.
2. **Prove the endpoint answers** with the `initialize` call above, before touching any client config.
3. **Decide on auth.** OAuth for anything shared; bearer token for a solo evaluation.
4. **Add the new server alongside the old one.** Tools are namespaced per server (`mcp__looker-managed__query` vs `mcp__looker-toolbox__query`), so both can run at once. The cost is a doubled tool list in the model's context, so this is a transition state, not a destination.
5. **Re-home your git workflow** onto the CLI before you remove the local server, since that is the one capability that actually disappears.
6. **Delete the binary and its plumbing** — the download step, the launcher script, the `LOOKER_TOOLBOX` variable, the `toolbox` line in `.gitignore`.

Step 6 is the satisfying one. In this repository it removed 292 MB, a download-and-checksum routine, a stdio wrapper, and an entire class of "why won't the server start" support question. What replaced it was four lines of JSON and a token command.

#### Summary

The Looker-managed MCP server is the same MCP Toolbox software, hosted by Google at your instance's own `/mcp` endpoint. It removes the local binary, the download, the launcher and the update treadmill. It adds admin-level governance over which tools exist at all, and per-user attribution once you move to OAuth.

It costs you six tools — five git-branch operations and one field-suggestion helper — all of which the Looker CLI already covers, and it pins you to Google's version of the server rather than your own.

For a Looker developer already running the CLI beside their agent, that is a straightforward trade. The interesting half of the work was never in the transport anyway.

#### References

* [Looker-managed MCP server | Google Cloud Documentation](https://docs.cloud.google.com/looker/docs/mcp)
* [Admin settings — Model Context Protocol (MCP) | Google Cloud Documentation](https://docs.cloud.google.com/looker/docs/admin-panel-platform-mcp)
* [Use Looker with MCP, Gemini CLI and other Agents | Google Cloud Documentation](https://docs.cloud.google.com/looker/docs/connect-ide-to-looker-using-mcp-toolbox)
* [Looker CLI | GitHub](https://github.com/looker-open-source/looker-cli)
* [MCP Toolbox for Databases | GitHub](https://github.com/googleapis/genai-toolbox)
