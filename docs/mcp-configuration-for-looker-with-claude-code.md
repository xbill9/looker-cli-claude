---
title: MCP Configuration for Looker with Claude Code
published: true
series: Looker
date: 2026-07-11 16:34:15 UTC
tags: mcps,claudecode,lookml,cli
canonical_url: https://xbill999.medium.com/mcp-configuration-for-looker-with-claude-code-2fcc1e6fbadb
---

<!--
Local archive of the published source article.
Pulled verbatim from https://dev.to/gde/mcp-configuration-for-looker-with-claude-code-21jh
(dev.to API `body_markdown`, published 2026-07-12). Do not hand-edit — re-pull instead.
The Codex adaptation lives in ./mcp-configuration-for-looker-with-codex.md
-->

This article covers the MCP setup and configuration for using Looker with Claude Code to enhance and extend Looker operations over MCP.

![](https://cdn-images-1.medium.com/max/1024/1*w-s-xwbBgDthpu0KKgy-4A.jpeg)

#### Deja Vu — What is Old is New!

This paper is a re-visiting of the original article which used Gemini CLI:

[MCP Configuration for Looker with Gemini CLI](https://medium.com/google-cloud/mcp-configuration-for-looker-with-gemini-cli-55e5671197fb)

In this updated version, the Claude Code CLI is used to integrate Looker functionality.

#### What is Looker?

Looker is a cloud-based business intelligence (BI) and data analytics platform owned by Google Cloud that enables organizations to analyze, visualize, and share data in real-time. It uses a unique modeling language called LookML to define data relationships, offering a centralized “single source of truth” for metrics. Looker focuses on embedded analytics and live data exploration rather than storing data itself.

More information is available here:

[Looker business intelligence platform embedded analytics](https://cloud.google.com/looker)

#### Key Features and Capabilities

- LookML (Looker Modeling Language): A code-based modeling language that allows data analysts to define dimensions, aggregates, and calculations, ensuring consistent metrics across the organization.
- Live Data Connection: Looker does not import data; it queries your data warehouse directly (e.g., BigQuery, Snowflake, Redshift) in real-time, ensuring data is always up to date.
- Embedded Analytics: Looker can be embedded into other applications, websites, or portals, allowing businesses to provide data insights directly within their own tools.
- Self-Service BI: Users can explore data, create visualizations, and build custom dashboards using a browser-based interface without needing deep SQL knowledge.
- Workflow Integration: Actionable data insights can be sent directly to other applications, such as triggering an email based on specific business rules.

#### Looker? I thought Big Query Did everything!

Semantic layer is where all the cool kids hang out.

#### What is MCP?

Unless you have been living off grid without Internet- MCP is the new universal connector and next “Big Thing”.

More information is here:

[What is Model Context Protocol (MCP)? A guide](https://cloud.google.com/discover/what-is-model-context-protocol)

#### Google MCP Strategy

Google has gone all-in for all the core Cloud services to provide connections over MCP. An overview is here:

[Google Cloud MCP servers overview | Google Cloud Documentation](https://docs.cloud.google.com/mcp/overview)

#### The Looker-managed MCP server

Until recently, connecting an agent to Looker meant running MCP Toolbox — the "swiss army" knife that connects your data sources to MCP — as a local binary that you downloaded, configured and kept up to date.

Looker now hosts that server for you. Every Looker (Google Cloud core) and Looker (original) instance exposes an MCP endpoint on its own base URL:

```plaintext
https://780eb09e-7dab-4076-9ec1-ecf9d8414630.looker.app/mcp
```

This is the **native** install: no binary, no download, no local process to babysit. The instance *is* the server. It is the same Toolbox software underneath — ask the endpoint who it is and it answers `{"name":"Toolbox"}` — but Google runs it, patches it and scales it.

[Looker-managed MCP server | Google Cloud Documentation](https://docs.cloud.google.com/looker/docs/mcp)

#### Looker MCP Setup

The native server is **admin-gated**. Before any client can connect, an admin has to switch it on:

**Admin → Platform → Model Context Protocol**

That page does two jobs. It enables the server, and it holds the allowlist of which AI tools agents are permitted to call. A tool switched off there simply does not appear in any client's tool list, no matter what the client asks for.

[Admin settings — Model Context Protocol (MCP) | Google Cloud Documentation](https://docs.cloud.google.com/looker/docs/admin-panel-platform-mcp)

Two things worth knowing before you start:

* The feature is in **preview**, and customer-hosted (on-premise) instances are not supported.
* The documented authentication path is **OAuth 2.1 with PKCE**, which needs an admin to register each agent as an OAuth client. This paper takes the shorter road for evaluation — an API3 key exchanged for a short-lived access token — and comes back to OAuth at the end.

The older local-binary route still works, and is documented here:

[Use Looker with MCP, Gemini CLI and other Agents | Google Cloud Documentation](https://docs.cloud.google.com/looker/docs/connect-ide-to-looker-using-mcp-toolbox)

#### Google Skills Repository

Google Skills give your MCP client well known approaches to work with the core Google products including Big Query.

The full details are here:

[Level Up Your Agents: Announcing Google's Official Skills Repository | Google Cloud Blog](https://cloud.google.com/blog/topics/developers-practitioners/level-up-your-agents-announcing-googles-official-skills-repository)

To install the Skills in Claude Code CLI:

```shell
npx skills install github.com/google/skills
```

#### What you talkin ‘bout Willis?

That was a lot of setup! But wait- there is more! So what is different about this lab compared to all the others out there?

This demo is one of the first deep dives into configuring Looker for MCP. Claude Code provides a complete working environment with a full MCP client. Looker exposes the key features of the platform over the MCP layer.

#### Where do I start?

The strategy for configuring Looker with MCP is a incremental step by step approach.

First, the Looker configuration settings are retrieved. Then, these settings are used to configure Claude Code. Finally- Claude Code is used as a MCP client to the Looker environment. Several samples are run using the Looker MCP Tools directly from the Claude Code CLI.

#### Looker Admin Setup

For Looker (Google Cloud core) — Admins do not directly create keys for standard users; instead, they enable the permission for users to manage their own.

Navigate to the [Looker Admin Users page](https://docs.cloud.google.com/looker/docs/admin-panel-users-users) (Admin > Users).

1. Click Edit next to the specific user.
2. Locate the API Keys field and toggle it to Enabled.
3. Once enabled, the user can generate their own keys by going to their personal [Account settings page](https://docs.cloud.google.com/looker/docs/user-account) (User Icon > Account > API Keys).

#### Looker Instance URL

To connect to the Looker setup — you need to derive your Looker Base URL. Typically this will be the hostname in the Looker app domain.

For the test instance- this is an example of what the URL looks like (note the HTTPS prefix and no trailing slash):

```plaintext
https://780eb09e-7dab-4076-9ec1-ecf9d8414630.looker.app
```

#### Looker User Setup

First Login to your Looker User environment. Go to Profile->Account (in upper right hand side) and bring up the user settings:

![](https://cdn-images-1.medium.com/max/717/1*jQYo5HxPJlG7AgFFSOUKZA.jpeg)

If the API Key box is unavailable- contact your Admin to enable the API setup on a per user basis.

Once you have access to create API keys- the settings will look similar to this:

![](https://cdn-images-1.medium.com/max/628/1*Lr2mRWlXuO0py9fVOUAJ5A.png)

Then click the “Manage” button to setup the API Keys:

![](https://cdn-images-1.medium.com/max/1024/1*0t4hhGedONm5LvI7mMWX1w.png)

Click Create New API key to generate the API Key. Save the **Client ID** and **Client Secret**.

#### Setup the Basic Claude Code CLI Environment

At this point you should have a working Shell environment and a working Claude Code installation. All of the relevant code examples and documentation is available in GitHub.

The next step is to clone the GitHub repository to your local environment:

```shell
cd ~
git clone https://github.com/xbill9/looker-mcp-claude
cd looker-mcp-claude
```

Then run **init.sh** from the cloned directory.

The script will attempt to determine your shell environment and set the correct variables:

```shell
source init.sh
```

This helper script will prompt for your Looker Instance details:

```shell
xbill@penguin:~/looker-mcp-claude$ source set_env.sh 
Looker Base URL (e.g. https://your-company.looker.com): https://780eb09e-7dab-4076-9ec1-ecf9d8414630.looker.app
Looker Client ID: 
Looker Client Secret: 
Environment successfully set up. Looker MCP config lives in .mcp.json (Claude format).

IMPORTANT: run this with 'source set_env.sh' (not './set_env.sh'). Claude Code
expands ${LOOKER_MCP_URL} in .mcp.json from its own environment, so that
variable must be exported in the shell that launches 'claude'.

Current Environment (.env) — secret masked:
GOOGLE_GENAI_USE_VERTEXAI=True
GOOGLE_CLOUD_PROJECT=comglitn
GOOGLE_CLOUD_LOCATION=us-central1
GENAI_MODEL="gemini-2.5-flash"
LOOKER_BASE_URL=https://780eb09e-7dab-4076-9ec1-ecf9d8414630.looker.app
LOOKER_CLIENT_ID= **************
LOOKER_CLIENT_SECRET= ********
LOOKER_VERIFY_SSL=true
LOOKER_MCP_URL=https://780eb09e-7dab-4076-9ec1-ecf9d8414630.looker.app/mcp
```

Note what is *absent* from that output. In the previous version of this setup, this step downloaded a 292 MB `toolbox` binary and wrote its path into `.env`. With the native server there is nothing to download — the script now only resolves credentials and derives one new variable, `LOOKER_MCP_URL`.

If your session times out or you need to re-authenticate- you can run the **set\_env.sh** script to reset your environment variables:

```shell
source set_env.sh
```

Variables like PROJECT\_ID need to be setup for use in the various build scripts- so the **set\_env** script can be used to reset the environment if you time-out.

#### Wiring Claude Code to the native endpoint

The whole client configuration is now four lines of `.mcp.json`:

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

Compare that with what it replaced — a `bash -c` wrapper that sourced `.env`, checked three variables, and exec'd a 292 MB binary with `--stdio --prebuilt looker,looker-dev`. The server moved to Looker's side of the wire, and the config collapsed to a URL and an auth command.

Two details matter here.

**`${LOOKER_MCP_URL}` is expanded by Claude Code itself**, not by a shell. A stdio server can source `.env` inside its own wrapper; a remote server cannot, because there is no wrapper. The variable has to exist in the environment of the process you launch `claude` from — which is exactly why `set_env.sh` is *sourced* rather than executed.

**`headersHelper` solves the token lifetime problem.** Looker access tokens live for one hour. A static `Authorization` header pasted into `.mcp.json` would work beautifully until it silently stopped. `headersHelper` instead names a command that Claude Code runs at every connection — and again automatically on a `401` or `403`, retrying the call once with the fresh result. Expiry heals itself.

The command it runs is a small wrapper in the repo, `./lk headers`, which mints a token from the API3 credentials already in `.env` and prints exactly one thing:

```json
{"Authorization": "Bearer ey..."}
```

That is the whole authentication story for evaluation purposes. It is worth being clear-eyed about the tradeoff: every action an agent takes is attributed to the API3 key's user, not to an individually authorised human. For anything past a proof of concept, register an OAuth client and let Claude Code do the PKCE dance — the instance advertises the endpoints at `/.well-known/oauth-authorization-server`.

#### Initial Connection

Start up Claude Code after all the environment variables have been set:

```shell
xbill@penguin:~/looker-mcp-claude$ claude
```

Then use the **/mcp list :**

```markdown
> /mcp
   Manage MCP servers
   1 server

     Project MCPs (/home/xbill/looker-mcp-claude/.mcp.json)
   ❯ looker-managed · ✔ connected · 40 tools

> list looker MCP tools
```

the full list of tools is here:

```markdown
╭─── Claude Code v2.1.207 ─────────────────────────────────────────────────────────────────────────────────────────╮
│ │ Tips for getting started │
│ Welcome back xbill! │ Run /init to create a CLAUDE.md file with instructions for… │
│ │ ─────────────────────────────────────────────────────────── │
│ ▐▛███▜▌ │ What's new │
│ ▝▜█████▛▘ │ Auto mode is now available without `CLAUDE_CODE_ENABLE_AUT… │
│ ▘▘ ▝▝ │ Fixed the terminal freezing and keystrokes lagging while s… │
│ Opus 4.8 (1M context) · Claude Max · xbill@glitnir.com's Organization │ /release-notes for more │
│ ~/looker-mcp-claude │ │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯

❯ list looker mcp tools

Here are the Looker MCP tools (mcp __looker-managed__ *) available in this session, grouped by function:

Metadata / Discovery

- get_models — list LookML models
- get_explores — list explores
- get_dimensions — list dimensions in an explore
- get_measures — list measures in an explore
- get_filters — list filters
- get_parameters — list parameters
- get_dashboards — list dashboards
- get_looks — list Looks
- get_projects — list LookML projects

Querying / Running

- query — run a Looker query
- query_sql — run raw SQL against a connection
- query_url — build a query URL
- run_look — run a saved Look
- run_dashboard — run a dashboard
- run_lookml_tests / get_lookml_tests — LookML data tests

Connections / Database Introspection

- get_connections
- get_connection_databases
- get_connection_schemas
- get_connection_tables
- get_connection_table_columns

Content Creation

- make_look — create a Look
- make_dashboard — create a dashboard
- add_dashboard_element — add a tile to a dashboard
- add_dashboard_filter — add a filter to a dashboard
- create_view_from_table — generate a LookML view from a DB table
- generate_embed_url — create an SSO embed URL

LookML Project / File Management

- get_project_files / get_project_file / create_project_file / update_project_file / delete_project_file
- get_project_directories / create_project_directory / delete_project_directory
- validate_project

Development Mode

- dev_mode — toggle development mode

Health / Diagnostics

- health_analyze
- health_pulse
- health_vacuum

That's 40 tools total. Want me to run any of them (e.g., list your models, connections, or dashboards) to verify connectivity?
```

#### What the native server does not do

Two capabilities from the local-binary era are absent from the managed tool set, and it is better to find out now than halfway through a LookML change.

**Git branch management.** `list_git_branches`, `get_git_branch`, `create_git_branch`, `switch_git_branch` and `delete_git_branch` are not exposed. LookML file editing and `dev_mode` are — so you can work in dev mode, you just cannot open the branch from MCP. The Looker CLI covers it:

```shell
./lk api project create_git_branch --project_id my_project --name my_branch
./lk project checkout my_project my_branch
./lk project branch my_project
```

**`get_field_value_suggestions`.** Ask the model for valid filter values and it will have to query the field's suggest explore directly instead.

Everything else — discovery, querying, content creation, LookML files, validation, tests, health — is present. The practical shape of a LookML change becomes: open the branch with the CLI, edit and validate over MCP, deploy with the CLI (`./lk project deploy`, which has never had an MCP equivalent).

You can drill down with Claude to get details on the actual MCP tools:

```markdown
 explain what make_look MCP tool does

make_look — creates a saved Look in Looker

A Look in Looker is a saved query bundled with a visualization. This tool builds one programmatically: you describe a query (which explore, which fields, filters, sorts, etc.) plus optional chart settings, and Looker saves it as a persistent, shareable Look.

What it does

1. Takes a query definition (model + explore + fields + filters/sorts/pivots).
2. Optionally applies a visualization config (chart type and styling).
3. Saves it as a named Look — by default in your personal folder (or a folder you specify).
4. Returns a JSON object with the new Look's url, id, and slug.

The title must be unique within the target folder.

Parameters

Required

┌─────────┬────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Param │ Meaning │
├─────────┼────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ model │ LookML model name (from get_models) │
├─────────┼────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ explore │ Explore to query (from get_explores) │
├─────────┼────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ fields │ List of fields — dimensions, measures, filters, or parameters — e.g. ["orders.created_date", │
│ │ "orders.count"] │
├─────────┼────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ title │ Unique name for the Look │
└─────────┴────────────────────────────────────────────────────────────────────────────────────────────────────┘

Optional

┌───────────────────┬──────────────────────────────────────────────────────────────────────────────────────────┐
│ Param │ Meaning │
├───────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤
│ description │ Free-text description of the Look's purpose │
├───────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤
│ filters │ Object keyed by view.field → filter expression. Pass values bare (e.g. parameter values │
│ │ like first_touch, not "first_touch") │
├───────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤
│ filter_expression │ A single filter-expression string alternative │
├───────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤
│ sorts │ e.g. ["orders.count desc 0"] │
├───────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤
│ pivots │ Fields to pivot on (must also appear in fields) │
├───────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤
│ limit │ Row cap (default 500) │
├───────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤
│ folder │ Destination folder id (blank = personal folder) │
├───────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤
│ vis_config │ JSON chart config (chart type + styling), same shape as query_url's vis_config │
├───────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤
│ dynamic_fields │ Table calculations / custom measures / custom dimensions │
├───────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤
│ tz │ Query timezone │
└───────────────────┴──────────────────────────────────────────────────────────────────────────────────────────┘

How it differs from neighboring tools

- query — runs a query and returns data; nothing is saved.
- query_url — builds a shareable Explore URL for a query; still nothing saved to content.
- make_look — persists the query+visualization as a reusable content object (a Look) that shows up in Looker's UI and can be added to dashboards.
- run_look — executes an already-saved Look and returns its results.

Example call shape

{
  "model": "ecommerce",
  "explore": "orders",
  "fields": ["orders.created_month", "orders.count"],
  "title": "Monthly Order Count",
  "description": "Orders per month, last 12 months",
  "filters": { "orders.created_date": "12 months" },
  "sorts": ["orders.created_month desc"],
  "vis_config": { "type": "looker_column" }
}
→ returns { "url": "...", "id": "123", "slug": "abc123" }.

Want me to list your models/explores so you could actually create one?

✻
```

#### All Right Already! Can you actually do something with Looker?

At this point- Claude Code CLI is connected to the Looker-managed MCP server and has direct access to all the Looker MCP Tools. Any operations with the Tools come back directly into the Claude Context.

To get an overview of Dashboards:

```markdown
❯ get_dashboards

Called looker-managed

Here are the dashboards in your Looker instance (16 total):

┌─────┬───────────────────────────────────────┬───────────────────────────────────────────────────────────────┐
│ ID │ Title │ Description │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 1 │ 2) Business Pulse - Intermediate │ │
│ │ visualization examples │ │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 2 │ 1) Business Pulse - Basic │ │
│ │ visualization examples │ │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 3 │ 3) Business Pulse - Advanced │ │
│ │ visualization examples │ │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 4 │ Agreement for Shared Use of this │ │
│ │ Looker Instance │ │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 5 │ test │ │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 6 │ test │ │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 7 │ Inventory │ │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 8 │ TestJC │ │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 9 │ Self-serve industry │ │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 10 │ TestOrdersByCity │ │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 11 │ My Dashboard │ │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 12 │ test-orders │ │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 13 │ E-commerce Overview │ A custom dashboard showing key e-commerce metrics. │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 14 │ 💎 VIP Customer Intelligence │ Real-time insights into top-performing revenue segments, │
│ │ │ leveraging Advanced LTV and Ranking logic. │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 15 │ ☁️ Cloud Optimization Hub │ Operationalizing AI-driven cost savings from the Google Cloud │
│ │ │ Recommender API. │
├─────┼───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ 16 │ Top Users & Countries Overview │ An executive dashboard highlighting top spenders and │
│ │ │ high-performing countries globally. │
└─────┴───────────────────────────────────────┴───────────────────────────────────────────────────────────────┘

A few observations:
- There are several test/scratch dashboards (5, 6, 8, 10, 11, 12) that look like leftovers — candidates for cleanup.
- The numbered "Business Pulse" set (1–3) are example/tutorial dashboards.
- The most substantive content appears to be 13–16 (E-commerce, VIP Customer Intelligence, Cloud Optimization Hub, Top Users & Countries).

Want me to run one of these (run_dashboard) to see its data, or inspect the tiles/filters on a specific one?
```

You can also get models:

```markdown
❯ get_models

  Called looker-managed

Here are the LookML models in your instance (11 total):

┌──────────────────────┬─────────────────────┬───────────────────────────────────┬──────────────────────────┐
│ Model name │ Label │ Project │ Connection(s) │
├──────────────────────┼─────────────────────┼───────────────────────────────────┼──────────────────────────┤
│ basic_ecomm │ Z) Sample LookML │ sample_thelook_ecommerce │ default_bigquery_connect │
│ │ │ │ ion │
├──────────────────────┼─────────────────────┼───────────────────────────────────┼──────────────────────────┤
│ intermediate_ecomm │ Z) Sample LookML │ sample_thelook_ecommerce │ default_bigquery_connect │
│ │ │ │ ion │
├──────────────────────┼─────────────────────┼───────────────────────────────────┼──────────────────────────┤
│ advanced_ecomm │ Z) Sample LookML │ sample_thelook_ecommerce │ default_bigquery_connect │
│ │ │ │ ion │
├──────────────────────┼─────────────────────┼───────────────────────────────────┼──────────────────────────┤
│ extension-api-explor │ Extension-api-explo │ marketplace_extension_api_explore │ default_bigquery_connect │
│ er │ rer │ r │ ion │
├──────────────────────┼─────────────────────┼───────────────────────────────────┼──────────────────────────┤
│ data_block_acs_bigqu │ Census Data Block │ marketplace_acs_census-v2 │ american-community-surve │
│ ery │ │ │ y │
├──────────────────────┼─────────────────────┼───────────────────────────────────┼──────────────────────────┤
│ gcp_billing_block │ Google Cloud │ marketplace_gcp-billing │ billing-export-sample │
│ │ Billing │ │ │
├──────────────────────┼─────────────────────┼───────────────────────────────────┼──────────────────────────┤
│ chrome-ux-block │ Chrome-ux-block │ marketplace_chrome-ux-block │ chrome-ux │
├──────────────────────┼─────────────────────┼───────────────────────────────────┼──────────────────────────┤
│ london_bicycles │ London Bicycles │ london_bicycles │ london-bicycles │
├──────────────────────┼─────────────────────┼───────────────────────────────────┼──────────────────────────┤
│ gde_rk │ Gde Rk │ gde_rk │ (8 connections) │
├──────────────────────┼─────────────────────┼───────────────────────────────────┼──────────────────────────┤
│ data-dictionary │ Data-dictionary │ marketplace_extension_data_dictio │ default_bigquery_connect │
│ │ │ nary │ ion │
├──────────────────────┼─────────────────────┼───────────────────────────────────┼──────────────────────────┤
│ bq_agent_analytics │ Bq Agent Analytics │ agent_events │ default_bigquery_connect │
│ │ │ │ ion │
└──────────────────────┴─────────────────────┴───────────────────────────────────┴──────────────────────────┘

Notable groupings:
- theLook e-commerce samples (basic_ecomm, intermediate_ecomm, advanced_ecomm) — Looker's standard demo dataset, likely what powers most of your dashboards.
- Marketplace blocks — Census/ACS, GCP Billing, Chrome UX, Data Dictionary, API Explorer.
- Public datasets — london_bicycles.
- gde_rk — a multi-connection catch-all model.
- bq_agent_analytics — agent event analytics.

Want me to pull the explores for one of these (get_explores)? advanced_ecomm or intermediate_ecomm are probably the richest starting points.
```

And drill into the details:

```markdown
> ❯ get_measures for advanced_example_ecommerc

  Called looker-managed

Here are the 20 measures in the advanced_euped by view:

order_items — core sales metrics

┌────────────────────────────────────────────────────┬─────────┐
│ Field │ Label │ Type │
├────────────────────────────────────────────────────┼─────────┤
│ order_items.count │ # of Order Items │ count │
├────────────────────────────────────────────────────┼─────────┤
│ order_items.total_sale_price │ Sales │ sum │
├────────────────────────────────────────────────────┼─────────┤
│ order_items.average_sale_price │ Average Price │ average │
├────────────────────────────────────────────────────┼─────────┤
│ order_items.first_order_date │ First Order Date │ date │
├────────────────────────────────────────────────────┼─────────┤
│ order_items.count_for_drill_to_item_details │ Count for Drill to Item Details │ count │
├────────────────────────────────────────────────────┼─────────┤
│ order_items.count_for_sale_price_trend_drill │ Count for Sale Price Trend Drill │ count │
└────────────────────────────────────────────────────┴─────────┘

users / products / inventory_items

┌────────────────────────────────────────────────────────────────┬────────────────┐
│ Field │ Label │ Type │
├────────────────────────────────────────────────────────────────┼────────────────┤
│ users.count │ # of Users │ count_distinct │
├────────────────────────────────────────────────────────────────┼────────────────┤
│ products.count │ Count Distinct Products │ count_distinct │
├────────────────────────────────────────────────────────────────┼────────────────┤
│ inventory_items.total_cost │ Total Cost │ sum │
├────────────────────────────────────────────────────────────────┼────────────────┤
│ inventory_items.average_cost │ Average Cost │ average │
├────────────────────────────────────────────────────────────────┼────────────────┤
│ priority_item_filter_feature_support.count_high_priority_items │ # of Order Items (Priority │ sum │
│ y) │ │
└────────────────────────────────────────────────────────────────┴────────────────────────────┴────────────────┘

User-summary measures (demonstrate filtered vs. lifetime symmetric-aggregate patterns)

┌────────────────────────────────────────────────────────────┬──────────────────────────────────┬──────────────┐
│ Field Label │ Type │
├────────────────────────────────────────────────────────────┼──────────────────────────────────┼──────────────┤
│ user_summary_filtered.total_sales_for_thles (Filtered Summary) │ sum_distinct │
├────────────────────────────────────────────────────────────┼──────────────────────────────────┼──────────────┤
│ user_summary_unfiltered.total_sales_for_les (Lifetime) │ sum_distinct │
├────────────────────────────────────────────────────────────┼──────────────────────────────────┼──────────────┤
│ user_summary_filtered.total_items_for_thems (Filtered Summary) │ sum_distinct │
├────────────────────────────────────────────────────────────┼──────────────────────────────────┼──────────────┤
│ user_summary_unfiltered.total_items_for_ems (Lifetime) │ sum_distinct │
├────────────────────────────────────────────────────────────┼──────────────────────────────────┼──────────────┤
│ user_summary_filtered.average_sale_price Price (Filtered │ number │
│ │ Summary) │ │
├──────────────────────────────────────────────────────────────────┼──────────────┤
│ user_summary_unfiltered.average_sale_price_for_these_users │ Avg Sale Price (Lifetime) │ number │
└──────────────────────────────────────────────────────────────────┴──────────────┘

!Special Measures! — advanced ratio/compar

┌───────────────────────────────────────────────┬────────────────────────┬────────┐
│ Field │ Label │ Type │
├───────────────────────────────────────────────┼────────────────────────┼────────┤
│ user_summary_and_order_items_fields.percent_of_lifetime_unfiltered_sales │ % of Purchasing Users' │ number │
│ │ Total Sales │ │
├────────────────────────────────────────────────────────────────────────────┼────────────────────────┼────────┤
│ user_summary_and_order_items_fields.percems │ % of Purchasing Users' │ number │
│ │ Total Items │ │
├───────────────────────────────────────────────┼────────────────────────┼────────┤
│ │ Avg Price vs These │ │
│ user_summary_and_order_items_fields.filterage │ Users' Avg Price │ number │
│ │ (Lifetime) │ │
└───────────────────────────────────────────────┴────────────────────────┴────────┘

Notes:
- The filtered vs. lifetime measures showcase Looker's advanced pattern for comparing a filtered subset against a user's full lifetime totals (useful for co
- The count_for_*_drill measures exist specifically to support drill-down interactions on dashboard tiles.     
```

and dig deeper on the details:

```markdown
❯ get_dimensions for advanced_example_ecommerce

  Called looker-managed

Here are the dimensions in advanced_example_ecommerce (~90 fields). Grouping by view and collapsing the date/time groups:

order_items — transaction attributes

- Timeframes (each as date/week/month/quar_*, shipped_at_*, delivered_at_*,returned_at_*
- order_items.sale_price (number), sale_pr20–50, 50–100, >= 100)
- order_items.status (string), status_in_order (1 - Processing, 1x - Cancelled, 2 - Shipped, 3 - Complete, 3x -
Returned)
- order_items.validation_status (Valid / Invalid / Unknown), is_valid (yesno)
- order_items.shipped_to_delivered_days (d

products

- products.brand, category, department, na
- products.cost, retail_price (numbers)

inventory_items

- inventory_items.cost (number)

users — customer demographics & geo

- users.age / age_tier (Below 20, 20–29, … 70+)
- users.gender, traffic_source
- Geo: city, state, country, postal_code, street_address, latitude, longitude
- Identity: first_name, last_name, email
- Created timeframes: users.created_at_*

priority_item_filter_feature_support — parameter-driven flags (yesno)

- is_high_priority_item, is_high_value_item, meets_priority_parameter_selection

user_summary_filtered / user_summary_unfiltered — LTV / ranking derived tables

These come in parallel pairs (Filtered Summary vs. Lifetime), demonstrating symmetric-aggregate + derived-table ranking patterns:
- user_revenue_rank / user_revenue_rank_quartile / user_revenue_rank_group (Top 1000, 1st 25%, … Bottom 25%)
- is_top_rank_group (Top Revenue Group / N
- order_item_count / order_item_count_group (Single Item, 2 Items, 3+ Items)
- first_order_date / first_order_month
- total_sale_price, total_user_count, user_id

System Keys (IDs)

order_items.id, order_id, user_id, product_id, inventory_item_id; products.id, sku, distribution_center_id;
users.id

---
You now have everything to build a query. Some ready-to-run examples I could execute with the query tool:

1. Sales by product category — products.category × order_items.total_sale_price, sorted desc
2. Top countries by revenue — users.countrice
3. Monthly sales trend — order_items.created_at_month × order_items.total_sale_price
4. VIP tiers — user_summary_unfiltered.usecount + order_items.total_sale_price
```

Let’s see what VIP tiers looks like!

```markdown
 Called looker-managed

VIP Tiers — Lifetime Revenue Rank Group (advanced_example_ecommerce)

Ordered by total sales:

┌─────────────┬────────┬─────────────┬─────────────┬────────────────┐
│ Rank Group │ Users │ Total Sales │ Order Items │ Avg Sale Price │
├─────────────┼────────┼─────────────┼─────────────┼────────────────┤
│ 1st 25% │ 15,569 │ $4,134,224 │ 53,458 │ $77.34 │
├─────────────┼────────┼─────────────┼─────────────┼────────────────┤
│ 2nd 25% │ 16,554 │ $1,931,678 │ 36,005 │ $53.65 │
├─────────────┼────────┼─────────────┼─────────────┼────────────────┤
│ 3rd 25% │ 16,557 │ $947,615 │ 24,026 │ $39.44 │
├─────────────┼────────┼─────────────┼─────────────┼────────────────┤
│ Top 1000 ⭐ │ 1,000 │ $731,207 │ 4,893 │ $149.44 │
├─────────────┼────────┼─────────────┼─────────────┼────────────────┤
│ Bottom 25% │ 16,560 │ $382,605 │ 17,800 │ $21.49 │
└─────────────┴────────┴─────────────┴─────────────┴────────────────┘

What this shows

- Steep revenue concentration. The top quartile (1st 25%) drives $4.13M — about 55% of the ~$7.4M lifetime total — while the bottom 25% contributes only ~5%, despite having more users.
- The "Top 1000" is a distinct elite segment, not a quartile — it overlaps with the 1st 25%. Just 1,000 users generate $731K, and their $149 average sale price is nearly 2× the top quartile's and 7× the bottom's. These are the true VIPs — high-value baskets, not just frequent buyers.
- Basket value declines cleanly down the tiers: $77 → $54 → $39 → $21. Rank correlates strongly with per-item spend, not just order count.

Reading note

The quartile groups (1st/2nd/3rd/Bottom 25%) partition all purchasing users, while Top 1000 is a separate flag that sits inside the 1st quartile — so its dollars are also counted in the 1st 25% row. Don't sum the column.

```

and now build out a Look:

```markdown
  Called looker-managed

✅ Look created — "VIP Tiers — Lifetime Revenue Rank Groups"

- ID: 8
- URL: /looks/8 (open at <your-looker-host>/looks/8)
- Viz: horizontal bar chart, sorted by total sales, value labels on
- Saved to: your personal folder

It captures the query we ran — the 5 revenue-rank tiers with user counts, total sales, order volume, and average sale price.

Want me to:
- Add it to a dashboard (add_dashboard_element) — e.g. the existing "💎 VIP Customer Intelligence" (id 14)?
- Adjust the viz — switch to a table or column chart, or change the sort/colors (I'd recreate it, since make_look creates rather than edits)?
- Create companion Looks — Top 1000 by country/category?
```

#### But Wait! There’s More!

Once the Tools are exposed by MCP -they have full access to Looker resources. Time to update a Dashboard:

```markdown
And build a Dashboard:

❯ - Add it to a dashboard (add_dashboard_element) — e.g. the existing "💎 VIP Customer Intelligence" (id 14)? Create companion Looks — Top 1000 by country/category?

I'll do all three in parallel — add the tile to dashboard 14, and create both companion Looks.

  Called looker-managed 3 times

All three succeeded. Let me quickly pull the underlying data for the two new Looks so you can see what they contain.

  Called looker-managed 2 times

All done. Summary of what was created:

✅ Dashboard tile added

"VIP Tiers — Lifetime Revenue Rank Groups" is now a tile on 💎 VIP Customer Intelligence (dashboard id 14).

✅ Two companion Looks created

Look 9 — Top 1000 VIPs by Country (/looks/9)

┌──────────────────────────┬───────────┬─────────────┬───────────┐
│ Country │ VIP Users │ Total Sales │ Avg Price │
├──────────────────────────┼───────────┼─────────────┼───────────┤
│ China │ 359 │ $259,129 │ $147.23 │
├──────────────────────────┼───────────┼─────────────┼───────────┤
│ United States │ 224 │ $163,185 │ $147.41 │
├──────────────────────────┼───────────┼─────────────┼───────────┤
│ Brasil │ 143 │ $106,613 │ $155.64 │
├──────────────────────────┼───────────┼─────────────┼───────────┤
│ South Korea │ 53 │ $37,381 │ $129.34 │
├──────────────────────────┼───────────┼─────────────┼───────────┤
│ France │ 52 │ $37,178 │ $149.31 │
├──────────────────────────┼───────────┼─────────────┼───────────┤
│ Spain │ 47 │ $35,646 │ $163.51 │
├──────────────────────────┼───────────┼─────────────┼───────────┤
│ Germany │ 43 │ $32,112 │ $158.19 │
├──────────────────────────┼───────────┼─────────────┼───────────┤
│ United Kingdom │ 37 │ $28,494 │ $178.09 │
├──────────────────────────┼───────────┼─────────────┼───────────┤
│ …6 more (AU, BE, JP, PL) │ │ │ │
└──────────────────────────┴───────────┴─────────────┴───────────┘

Look 10 — Top 1000 VIPs by Product Category (/looks/10)

┌─────────────────────┬─────────────┬───────┬───────────┐
│ Category │ Total Sales │ Items │ Avg Price │
├─────────────────────┼─────────────┼───────┼───────────┤
│ Outerwear & Coats │ $245,412 │ 664 │ $369.60 │
├─────────────────────┼─────────────┼───────┼───────────┤
│ Suits & Sport Coats │ $70,838 │ 278 │ $254.81 │
├─────────────────────┼─────────────┼───────┼───────────┤
│ Jeans │ $58,421 │ 423 │ $138.11 │
├─────────────────────┼─────────────┼───────┼───────────┤
│ Active │ $48,295 │ 220 │ $219.52 │
├─────────────────────┼─────────────┼───────┼───────────┤
│ Sweaters │ $36,618 │ 325 │ $112.67 │
├─────────────────────┼─────────────┼───────┼───────────┤
│ Dresses │ $35,942 │ 185 │ $194.28 │
├─────────────────────┼─────────────┼───────┼───────────┤
│ …9 more │ │ │ │
└─────────────────────┴─────────────┴───────┴───────────┘

Notable insights

- Geography is concentrated: China + US + Brasil = ~726 of the 1,000 VIPs and the bulk of VIP revenue. The UK has the highest per-item spend ($178) despite few users.
- Outerwear dominates category spend — $245K, more than the next three categories combined, at a striking $369.60 average sale price. High-ticket outerwear is the signature purchase of your best customers.
```

This will look similar to :

![](https://cdn-images-1.medium.com/max/1024/1*3JaHl5lIFlvUVvSSrlvEYw.png)

And can also be accessed directly in Looker:

![](https://cdn-images-1.medium.com/max/1024/1*ZLW3bl8JlEIa-BUPU8V-xw.png)

it slices — it dices!

```markdown

❯ explain dashboard 17

💎 VIP Customer Intelligence v2 — Dashboard 17

Purpose: "Real-time insights into top-performing revenue segments, leveraging Advanced LTV and Ranking logic."
Source: advanced_ecomm → advanced_example_ecommerce explore
Link: https://780eb09e-7dab-4076-9ec1-ecf9d8414630.looker.app/dashboards/ywmXQvB4Z6O24llupYw5P5

This is a single-audience dashboard: it answers "who are our best 1,000 customers, and what/where/how do they buy?" Nearly every tile is scoped to the Tent. Data is fresh (I ran all 10 tiles just now — all succeed). Here's what it says, tile by tile and as a whole.

---
The headline (KPI tiles)

- Total VIP Sales: $731,207 — lifetime rev
- VIP User Count: 1,000 — confirms the segment is exactly the top-1000 flag (a sanity check that the ranking logic
is wired correctly).
- Implied ~$731 lifetime value per VIP — vs. a full-base average far below that.

How concentrated is revenue? (VIP Tiers)

The rank-group bar puts the VIPs in context of all purchasing users:

┌────────────┬────────┬────────┬────────────┐
│ Tier │ Users │ Sales │ Avg baske
├────────────┼────────┼────────┼────────────┤
│ 1st 25% │ 15,569 │ $4.13M │ $7
├────────────┼────────┼────────┼────────────┤
│ 2nd 25% │ 16,554 │ $1.93M │ $5
├────────────┼────────┼────────┼────────────┤
│ 3rd 25% │ 16,557 │ $948K │ $3
├────────────┼────────┼────────┼────────────┤
│ Top 1000 │ 1,000 │ $731K │ $14
├────────────┼────────┼────────┼────────────┤
│ Bottom 25% │ 16,560 │ $383K │ $2
└────────────┴────────┴────────┴────────────┘

Read: revenue is steeply top-loaded — the 1st quartile is ~55% of all lifetime revenue. The Top 1000 is an elite
flag inside that 1st quartile (its $731K in't add them). Their $149 average basket is ~2× the next tier and 7× the bottom.

What makes a VIP a VIP? (Spend Benchmark + Frequency)

- Spend Benchmark: the average-sale-price-by-tier column isolates the single biggest differentiator — basket
value. $149 (Top 1000) → $77 → $54 → $39 → how much per item, not just how often.
- Purchase Frequency Distribution: 829 of 1,000 VIPs buy 3+ items; only 74 are single-item. So VIPs are both
high-basket and repeat buyers — the combin LTV.

Where are they? (Country + State)

- Country: China ($259K, 359 users), US ($26 of the 1,000 VIPs and the bulk ofrevenue. Tail markets (UK, Germany, Spain) have small counts but the highest per-item spend (UK $178).
- State: Guangdong ($49K) tops all states,nd England ($24K) — the China concentration shows through at state level too (Guangdong, Shanghai, Zhejiang, Beijing, Hebei all rank).

What do they buy? (Category)

- Outerwear & Coats dominates at $245K with a $370 average sale price — more than the next three categories
combined. Suits ($71K) and Active ($48K) fted in high-ticket apparel.

Who are they? (Customer Details table)

Named leaderboard of the top 10 by revenuerance, $1,849, 8 items), then Mark Nolan(US), John Hill (Brasil). This is the actionable list for a retention/concierge team to act on individually.

---
The story the dashboard tells

▎ A tiny, geographically concentrated segmbuying high-ticket outerwear, repeatedly.1,000 users (a rounding error of the customer base) generate $731K; they spend 7× the bottom tier per item, 83% are multi-item buyers, they cluster in Cnature purchase is premium outerwear.

What you'd do with it: target VIP-lookalikake sure outerwear inventory andmerchandising never disappoints this group; build a concierge program around the named top-10; and watch the
monthly trend (climbing to $43K in Jul 202he segment.

Analyst caveats

- Don't sum the tier bars — Top 1000 overl
- "Valid orders only" — the explore excludes cancelled/returned items, so these are net figures.
- Layout still needs arranging — tiles werdrag them into rows (KPIs top, tablebottom) in the editor.
- This is Looker's synthetic theLook samply/names as illustrative, not a realcustomer book.

```

#### So what else can Claude do?

Health checks / Instance maintenance:

```markdown
Running a full health sweep — usage analysis, six pulse checks, and cleanup candidates — in parallel.

  Called looker-managed 10 times

The health sweep surfaced a real finding on the first try — just not the one we were shopping for. Here's what happened.

Result: the native health tools are blocked by a permissions gap

Almost every check failed identically:
status=400 Bad Request error={"message":"Access Denied", .../queries/run...}

┌────────────────────────────────────┬─────────────────────────────────────────────────────────────────────────┐
│ Check │ Outcome │
├────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ health_analyze models / explores │ ❌ Access Denied / null │
├────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ health_pulse db_connections │ ❌ Access Denied │
├────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ health_pulse dashboard_errors │ ❌ Access Denied │
├────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ health_pulse dashboard_performance │ ❌ Access Denied │
├────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ health_pulse explore_performance │ ❌ Access Denied │
├────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ health_pulse schedule_failures │ ❌ Access Denied │
├────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ health_pulse legacy_features │ ⚠️ "Unsupported in Looker (Google Cloud core)" — expected, not an error │
├────────────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ health_vacuum models / explores │ ❌ Access Denied / null │
└────────────────────────────────────┴─────────────────────────────────────────────────────────────────────────┘

Why (the actual diagnosis)

All the health tools work by querying Looker's System Activity model (i __looker / system__ activity — the history, dashboard, query explores). Running those requires the see_system_activity permission on the role attached to the API3 credentials this MCP server authenticates with. The uniform Access Denied on /queries/run is the textbook signature of that permission being absent. legacy_features returning "Unsupported" is normal — it's a Looker-Core-only check and this is a Core instance.

This is itself a valid demo outcome: Claude ran an instance audit and immediately isolated that your MCP service account can query data but not System Activity metadata.

The fix (one-time, in Looker admin)

Grant the API user's role see_system_activity (or attach a role that has it — the built-in Admin role does):
Admin → Roles, edit the role bound to your API3 client ID, add the see_system_activity permission. Re-run and all the health checks light up.

---
Meanwhile — a metadata-based audit does work

The get_dashboards / run_dashboard tools don't touch System Activity, so I can deliver a real cleanup pass right now from what we've already gathered:

🧹 Cleanup candidates (from the dashboard inventory)

┌──────┬──────────────────────────────┬─────────────────────────────────────────┐
│ ID │ Title │ Flag │
├──────┼──────────────────────────────┼─────────────────────────────────────────┤
│ 5, 6 │ "test" (×2, duplicate name) │ Scratch — almost certainly deletable │
├──────┼──────────────────────────────┼─────────────────────────────────────────┤
│ 8 │ TestJC │ Scratch │
├──────┼──────────────────────────────┼─────────────────────────────────────────┤
│ 10 │ TestOrdersByCity │ Scratch │
├──────┼──────────────────────────────┼─────────────────────────────────────────┤
│ 11 │ My Dashboard │ Default/placeholder name │
├──────┼──────────────────────────────┼─────────────────────────────────────────┤
│ 12 │ test-orders │ Scratch │
├──────┼──────────────────────────────┼─────────────────────────────────────────┤
│ 14 │ 💎 VIP Customer Intelligence │ Superseded by v2 (#17) — 7 broken tiles │
└──────┴──────────────────────────────┴─────────────────────────────────────────┘

That's ~7 dashboards worth reviewing for deletion — the six obvious test/placeholder ones plus the now-obsolete #14.
```

#### Show me the Money!

But the key value is when you push what the combination of Claude Code, the LLM model, and the Looker tools over MCP:

```markdown
❯ "Are we at risk of losing our best customers?"

I'll investigate this using your Looker instance. Let me start by discovering what data is available, then dig into customer retention signals.

  Called looker-managed

This is the thelook e-commerce dataset. Let me explore the richest model.

  Called looker-managed 3 times

Rich model — there's a lifetime revenue-rank on each user, so I can define "best customers" precisely (Top Revenue Group / Top 1000) and track their activity over time. First, let me find the data's date range so I know what "recent" means.

  Called looker-managed

Data runs right up to today (July 2026). Now the core analysis: track the Top Revenue Group's monthly spend and active-customer count over the last ~2 years to see if the best customers are pulling back.

  Called looker-managed

The business is growing overall, so a raw trend hides churn. The real risk signal for "losing" customers is recency — how many of our best customers have gone quiet. Let me pull, for each top-1000 (lifetime-revenue) customer, their last order date and lifetime spend.

  Called looker-managed 2 times

The max date measure works but I can't derive days-since inline. Let me just pull last-order-date and lifetime spend per top customer and bucket recency myself.

  Called looker-managed

max on a date isn't allowed as a dynamic measure here. I'll switch to a count-based recency approach, which answers the question directly: of the ~1,000 best customers (all-time), how many have actually purchased in each recent window. Running these in parallel.

  Called looker-managed 4 times

Here's what the data says. I defined "best customers" as your Top Revenue Group — the top 1,000 customers by lifetime valid revenue (worth $731K in lifetime sales, ~$731 each). Then I looked at whether they're still actually buying.

Short answer: The cohort's revenue is healthy, but there's a large dormant tail worth watching.

Aggregate spend from top customers is at record highs — valid revenue from the top-customer cohort rose from ~$12–17K/month in late 2024 to $43K in July 2026, growing alongside the overall business. So the franchise isn't collapsing.

But recency tells a more worrying story. Of the 1,000 all-time best customers:

┌───────────────────────┬────────────────┬───────┬───────────────────────────────┐
│ Last purchased within │ # still active │ Share │ → Gone silent │
├───────────────────────┼────────────────┼───────┼───────────────────────────────┤
│ 90 days │ 258 │ 26% │ 74% (742) inactive 3+ months │
├───────────────────────┼────────────────┼───────┼───────────────────────────────┤
│ 180 days │ 419 │ 42% │ 58% (581) inactive 6+ months │
├───────────────────────┼────────────────┼───────┼───────────────────────────────┤
│ 365 days │ 585 │ 59% │ 42% (415) inactive 12+ months │
└───────────────────────┴────────────────┴───────┴───────────────────────────────┘

So ~415 of your top-1,000 customers (42%) haven't placed a valid order in over a year — effectively lapsed. At the cohort's average lifetime value (~$731), that's on the order of ~$300K of historical revenue that has stopped repeating, plus another ~160 who've slipped into the 6–12 month "cooling off" zone.

How to read this

- It's a tail problem, not a top-line collapse. A concentrated set of top customers is very active (driving record months), while a long tail of former big spenders has quietly aged out. That's partly natural — "best customers" is a lifetime label, so it accumulates people who were huge years ago.
- The actionable risk is the 6–12 month "cooling" band (~160 customers) — recently valuable, now slipping, and still winnable. The 12-month+ group is more of a win-back effort.

Suggested next steps (I can do any of these — just say the word)

1. Pull the actual at-risk list — name, email, lifetime spend, and days-since-last-order for the top customers who've gone quiet, so marketing can run a targeted win-back. (Best done via query_sql for a clean per-customer last-order date.)
2. Build a "Best Customer Retention" dashboard in Looker (active-vs-dormant tiles, the recency table above, and the monthly top-cohort trend) so this is monitored ongoing.
3. Add a churn-risk segment to the LookML model (e.g. a days_since_last_order / risk-band dimension) so "at-risk best customers" becomes a reusable, governed field.

Want me to start with the at-risk customer list (#1)? Note that #2 and #3 create/modify content in your live Looker instance, so I'll confirm specifics before doing anything there.
```

Pull At Risk Customers in real time based on your actual data!

```markdown
Your best customers who've gone quiet

These are the 5 highest-lifetime-value members of your Top-1,000 revenue group who have not placed a valid order in 90+ days, ranked by lifetime spend. "Cooling" = last bought 3–6 months ago (most winnable); "Dormant" = 6+ months silent.

┌─────┬───────────────┬───────────────────────────────┬────────────┬──────────┬───────────┬────────┬──────────┐
│ # │ Customer │ Email │ Country │ Channel │ Lifetime │ Orders │ Status │
│ │ │ │ │ │ $ │ │ │
├─────┼───────────────┼───────────────────────────────┼────────────┼──────────┼───────────┼────────┼──────────┤
│ 1 │ Craig │ craigdickerson@example.net │ France │ Email │ $1,849 │ 8 │ 🟡 │
│ │ Dickerson │ │ │ │ │ │ Cooling │
├─────┼───────────────┼───────────────────────────────┼────────────┼──────────┼───────────┼────────┼──────────┤
│ 2 │ Mark Nolan │ marknolan@example.com │ USA │ Organic │ $1,826 │ 7 │ 🟡 │
│ │ │ │ │ │ │ │ Cooling │
├─────┼───────────────┼───────────────────────────────┼────────────┼──────────┼───────────┼────────┼──────────┤
│ 3 │ John Hill │ johnhill@example.org │ Brazil │ Search │ $1,554 │ 4 │ 🔴 │
│ │ │ │ │ │ │ │ Dormant │
├─────┼───────────────┼───────────────────────────────┼────────────┼──────────┼───────────┼────────┼──────────┤
│ 4 │ Glenn Foster │ glennfoster@example.net │ USA │ Facebook │ $1,455 │ 8 │ 🟡 │
│ │ │ │ │ │ │ │ Cooling │
├─────┼───────────────┼───────────────────────────────┼────────────┼──────────┼───────────┼────────┼──────────┤
│ 5 │ Thomas Davis │ thomasdavis@example.net │ Australia │ Search │ $1,435 │ 8 │ 🔴 │
│ │ │ │ │ │ │ │ Dormant │
└─────┴───────────────┴───────────────────────────────┴────────────┴──────────┴───────────┴────────┴──────────┘

Notable: your single highest-lifetime-value customer overall (Craig Dickerson, $1,849) is on this list — cooling, not yet lost. Five of the top 30 are still in the winnable 3–6 month window.

The full at-risk population (all 1,000 top customers)

- 🟢 258 active (bought in last 90 days) — healthy
- 🟡 161 cooling — last order 3–6 months ago ← highest-priority win-back
- 🟠 166 slipping — last order 6–12 months ago
- 🔴 415 lapsed — no order in 12+ months

So 742 of your top 1,000 (74%) haven't purchased in 90+ days, and the table above is the highest-value slice of that group.

Method note: I ranked by lifetime valid spend and defined "at-risk" as no valid order in 90 days (cross-checked against the 90- and 180-day active sets from real order data). The first_order column shows how long they've been a customer, not last order — the MCP server could not compute an exact per-customer last-order date inline, so status is bucketed by 90/180-day windows rather than exact dates.

Want me to go further?

1. Export the full 742-name at-risk list to CSV (or the 161 "cooling" high-priority segment only).
2. Get exact last-order dates per customer (via a Look built on a max-date measure) for precise prioritization.
3. Save this as a Look/dashboard in Looker so marketing can pull it live — this creates content in your instance, so I'll confirm folder/title first.

```

What-if Scenarios!

```markdown
"What if we raised outerwear prices 10% — what happens to VIP revenue and would it dent volume?"

Good follow-up — this is a pricing what-if on the VIP segment. Let me ground it in the actual numbers first: what your VIP customers (Top Revenue Group) currently spend and buy in outerwear. Let me confirm the category name and pull the baseline.

  Called looker-managed

Outerwear is the key finding here: it's your VIPs' #1 category by a wide margin — $245K of their spend (34% of all VIP lifetime revenue), 664 items at an avg $370/item. So this pricing decision hits VIPs where they're most concentrated. Let me pull cost too, so I can show the profit impact (not just revenue).

  Called looker-managed

Here's the model, grounded in your actual VIP outerwear numbers.

Baseline — VIP outerwear today

┌──────────────────┬─────────────────────────┐
│ Metric │ Value │
├──────────────────┼─────────────────────────┤
│ Revenue │ $245,412 │
├──────────────────┼─────────────────────────┤
│ Units sold │ 664 │
├──────────────────┼─────────────────────────┤
│ Avg price / unit │ $369.60 │
├──────────────────┼─────────────────────────┤
│ Cost / unit │ $163.48 │
├──────────────────┼─────────────────────────┤
│ Gross profit │ $136,859 (55.8% margin) │
├──────────────────┼─────────────────────────┤
│ Profit / unit │ $206.11 │
└──────────────────┴─────────────────────────┘

Context: this one category is 34% of all VIP lifetime spend — by far their biggest. So this is a high-leverage, high-exposure lever.

What a +10% price does

The answer hinges entirely on how much volume you lose (price elasticity), which this data can't measure directly — so here are transparent scenarios. New price = $406.56 (+$36.96/unit, and since cost is unchanged, every extra dollar is pure margin).

┌────────────────────┬────────────┬──────────┬──────────┬──────────────┬──────────┐
│ Volume response │ Units (Δ) │ Revenue │ vs today │ Gross profit │ vs today │
├────────────────────┼────────────┼──────────┼──────────┼──────────────┼──────────┤
│ No dip (inelastic) │ 664 (0%) │ $269,956 │ +$24,544 │ $161,405 │ +$24,546 │
├────────────────────┼────────────┼──────────┼──────────┼──────────────┼──────────┤
│ −5% │ 631 (−33) │ $256,458 │ +$11,046 │ $153,335 │ +$16,476 │
├────────────────────┼────────────┼──────────┼──────────┼──────────────┼──────────┤
│ −10% │ 598 (−66) │ $242,960 │ −$2,452 │ $145,266 │ +$8,407 │
├────────────────────┼────────────┼──────────┼──────────┼──────────────┼──────────┤
│ −15% │ 564 (−100) │ $229,462 │ −$15,950 │ $137,197 │ ~flat │
├────────────────────┼────────────┼──────────┼──────────┼──────────────┼──────────┤
│ −20% │ 531 (−133) │ $215,964 │ −$29,449 │ $129,127 │ −$7,732 │
└────────────────────┴────────────┴──────────┴──────────┴──────────────┴──────────┘

The two numbers that matter

- Revenue break-even: ~9% volume loss. You can lose up to ~60 of the 664 units before the price hike stops adding revenue. Lose fewer → revenue grows; more → it shrinks.
- Profit break-even: ~15% volume loss. Because you keep the full $37 markup at zero added cost, profit holds up even if revenue dips. You'd have to lose ~100 units before profit turns negative.

Would it dent volume? Yes, expect a modest dip. For this segment — your most loyal customers, buying a premium ($370) considered-purchase category — elasticity is likely mild (roughly −0.3 to −0.8), which lands you in the top two rows: revenue +$11–20K, profit +$16–22K, and only ~20–50 fewer units (−3% to −8%) — comfortably inside both break-even cushions.

One important strategic caveat

Tie this back to last analysis: 74% of your VIPs (742/1,000) are already cooling or lapsed, and outerwear is their anchor category. A blanket 10% hike risks nudging cooling VIPs out the door — and that churned lifetime value would swamp the ~$15–20K modeled gain. So the math favors the increase, but the execution shouldn't be uniform:
- Raise on healthy/active VIPs; protect the at-risk/cooling ones (grandfather current pricing, or pair the increase with a loyalty perk / free shipping so the effective price is softer).
- Apply to new-season inventory rather than a visible retroactive hike.
- Run it as a holdout test on a VIP subset first — that gives you the real elasticity instead of my assumed range, then scale.

Caveats on the model

- Elasticity is assumed, not measured — no clean price-experiment history exists in this data. A holdout test is the only way to get the true number.
- Baseline is lifetime VIP outerwear. For a forward-looking annual decision, the trailing-12-month figures are the better base — I can pull those and re-run the table.
```

Deep explanations:

```markdown
 "What does filtered_average_vs_unfiltered_average actually compute, and can I trust it?"

Great pick. Let me read the actual LookML that defines this measure. First I'll locate the project files.

  Called looker-managed 2 times

The measure lives in the user_summary_and_order_items_fields view. Let me read it plus the two views it depends on.

  Called looker-managed 3 times

I have the full definition and its two dependency views. Let me verify my reading against live data before giving a verdict — I'll pull the raw ingredients alongside the measure so we can check the arithmetic.

  Called looker-managed

The math reconciles exactly (e.g. Outerwear: 145.37 / 88.47 − 1 = 0.643 ✓). Here's the full teardown.

What filtered_average_vs_unfiltered_average computes

The one-line answer: it's the percent difference between the average item price in the current query context and the same shoppers' average item price over their entire lifetime. Positive = they're buying pricier-than-usual items in this slice.

The actual SQL

lookml
measure: filtered_average_vs_unfiltered_average {
  label: "Avg Price vs These Users' Avg Price (Lifetime)"
  type: number
  sql: (${order_items.average_sale_price} * 1.0
        / nullif(${user_summary_unfiltered.average_sale_price_for_these_users}, 0)) - 1 ;;
  value_format_name: percent_0
}

So it's (filtered_avg ÷ lifetime_avg) − 1, where both "averages" are sales ÷ items (price per item, not per order or total spend).

Where each half comes from — the clever part

┌─────────────┬────────────────────────────────────────────────────────────┬───────────────────────────────────┐
│ Term │ Field │ Respects query filters? │
├─────────────┼────────────────────────────────────────────────────────────┼───────────────────────────────────┤
│ Numerator │ order_items.average_sale_price │ Yes — the avg item price of the │
│ │ │ rows actually in scope │
├─────────────┼────────────────────────────────────────────────────────────┼───────────────────────────────────┤
│ Denominator │ user_summary_unfiltered.average_sale_price_for_these_users │ No — lifetime avg for those same │
│ │ │ users │
└─────────────┴────────────────────────────────────────────────────────────┴───────────────────────────────────┘

The denominator's "lifetime" behavior comes from one line in user_summary_unfiltered:
lookml
derived_table: {
  explore_source: advanced_example_ecommerce { ... bind_all_filters: no } # ← ignores UI filters
}
That derived table is one row per user (ranked by revenue), joined back to order_items by user_id. Because it's a 1-user-row joined to many order-item rows, Looker automatically applies symmetric aggregates so summing lifetime sales/items counts each user exactly once (no fan-out). Its twin, user_summary_filtered, is identical but bind_all_filters: yes — that's the whole "filtered vs. lifetime" family.

Empirically verified (top rows, sorted desc):

┌───────────────────┬──────────────┬──────────────┬─────────┬──────────────────────────┐
│ Category │ Filtered avg │ Lifetime avg │ Measure │ Check │
├───────────────────┼──────────────┼──────────────┼─────────┼──────────────────────────┤
│ Outerwear & Coats │ $145.37 │ $88.47 │ +64% │ 145.37/88.47−1 = 0.643 ✓ │
├───────────────────┼──────────────┼──────────────┼─────────┼──────────────────────────┤
│ Suits │ $118.39 │ $77.38 │ +53% │ ✓ │
├───────────────────┼──────────────┼──────────────┼─────────┼──────────────────────────┤
│ Blazers & Jackets │ $92.51 │ $67.84 │ +36% │ ✓ │
└───────────────────┴──────────────┴──────────────┴─────────┴──────────────────────────┘

Reads as: "When these shoppers buy outerwear, they pay 64% more per item than their usual basket." Makes sense — outerwear is a splurge category.

The measure also ships conditional HTML: green "▲ Higher" above +0.5%, red "Lower" below 0, "Same as Overall Average" within ±0.5%.

---
Can you trust it? ✅ Yes — with three rules

It's correctly built: proper symmetric-aggregate handling, nullif(...,0) guards against divide-by-zero (returns null, never errors), and both sides sit on the same "Valid Orders only" basis since the derived table sources the same explore. The arithmetic verifies against raw fields. No bug here.

But it's a ratio-of-averages, so respect its nature:

1. Don't sum, average, or trust a Totals row for it. Ratio measures don't roll up — a column total re-computes at the total grain and usually isn't what you'd naively expect. Read it per-row only.
2. The baseline is dynamic, not a global constant. The denominator is "lifetime avg for the users present in this row/filter." Change a filter that changes which users appear, and the baseline moves. Two tiles can legitimately show different lifetime baselines. This is the #1 way people misread it.
3. It's about per-item price mix, not spend or loyalty. A +64% here means "pricier items," not "these customers spend more overall" or "buy more often." For those, use the total/count measures instead.

Bottom line

Trustworthy for exactly one question: "in this slice, are these shoppers trading up or down on per-item price versus their own norm?" It's a genuinely elegant use of paired filtered/unfiltered derived tables — just don't aggregate it and don't confuse its dynamic lifetime baseline for a fixed benchmark.

```

Finally — Executive briefings:

```markdown
The dashboard existed already (built earlier today from Looker's advanced_ecomm model, dashboard 14). To make it a proper briefing, I added an executive layer on top of the existing charts:

- A 4-KPI summary strip — the numbers an exec reads first
- A "Bottom line" callout — the strategic takeaway in two sentences

The briefing in 30 seconds

┌───────────────────────┬────────┬───────────────────────────────────────┐
│ Metric │ Value │ Meaning │
├───────────────────────┼────────┼───────────────────────────────────────┤
│ Lifetime revenue │ $7.40M │ All purchasing users │
├───────────────────────┼────────┼───────────────────────────────────────┤
│ Top-1000 VIP revenue │ $731K │ $149 avg basket — ~7× the bottom tier │
├───────────────────────┼────────┼───────────────────────────────────────┤
│ Revenue concentration │ 56% │ Comes from the 1st customer quartile │
├───────────────────────┼────────┼───────────────────────────────────────┤
│ VIP geography │ 72% │ Of VIP spend from China, US, Brasil │
└───────────────────────┴────────┴───────────────────────────────────────┘

Bottom line for the exec team: Revenue is highly concentrated — a 1,000-customer VIP core spends ~7× the average shopper, is geographically narrow (three countries), and is premium-led (Outerwear & Coats alone: $245K at a $370 avg item). The strategic lever is retaining and expanding the VIP core, not broad acquisition.

One note on reading the charts: the Top 1000 tier is an elite flag inside the 1st quartile — its dollars are already counted there, so don't sum the tier bars.

```

![](https://cdn-images-1.medium.com/max/1024/1*BooV1_XioZKS7gwvVLWvRA.png)

![](https://cdn-images-1.medium.com/max/1024/1*VYd5q3ztXlKcw3mxJ6qaFg.png)

These are only high level examples of what can be done with the tech stack!

#### Summary

Claude Code was configured as a Looker MCP client against the **Looker-managed MCP server** — the native endpoint the instance hosts at `LOOKER_BASE_URL/mcp`, with no local binary anywhere in the stack. Then, the MCP connection was used to connect to the Looker Instance and test basic operations. Finally, Claude Code was used for a complete project code review.

The native install is a smaller thing to own than what it replaced. A 292 MB download, a stdio wrapper script and a `--prebuilt looker,looker-dev` flag collapsed into a URL and a `headersHelper`. Google patches the server; the admin panel governs which tools exist; System Activity logs what the agent did.

What you give up is small and specific: five git-branch tools and `get_field_value_suggestions`, all of which the Looker CLI covers. What you should fix before production is the authentication shortcut used here — swap the API3 token helper for a registered OAuth client, so actions are attributed to a person rather than to a key.

*A note on this revision: the setup and configuration sections describe the native MCP install, and the session transcripts have been updated to the `looker-managed` server name and its 40-tool inventory. The analysis, queries and results are unchanged from the original run.*