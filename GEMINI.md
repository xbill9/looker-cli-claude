I am a Looker developer. I have expertise in LookML, Looker administration, and embedding Looker content.

## Developer Guidelines & Workflow

When developing Looker integrations, LookML models, or embedding content:
1. **LookML Best Practices**: Always use clean hierarchy, reuse dimensions/measures with extends where appropriate, and document fields using `description` tags.
2. **Access Control**: Keep security filters and access filters top of mind when designing models to ensure data security.
3. **Caching**: Define datagroups in LookML to optimize query caching and database performance.
4. **Embedding Looker**: Use the Looker Embed SDK for secure SSO embedding of dashboards, looks, and explores.

## Tooling in this repository

Two interfaces reach the same Looker instance with the same API3 credentials:

- **Looker CLI** — the primary interface, run through the `./lk` wrapper (`./lk model ls`, `./lk folder tree 1`, `./lk project deploy <project>`). Covers the full API, writes results to files, and is the only way to deploy.
- **Looker-managed MCP server** (`LOOKER_BASE_URL/mcp`, preview) — semantic-model discovery, conversational querying, content creation, and LookML editing in dev mode. Hosted by the instance; connect Gemini CLI with `gemini mcp add --transport http looker "$LOOKER_MCP_URL"`. It has no git-branch tools, so branching goes through the CLI.

Discover and decide with MCP; execute and persist with the CLI. See `docs/hybrid-workflows.md` for worked combinations, and `README.md` for setup.

## Relevant Links

*   [Looker business intelligence platform embedded analytics](https://cloud.google.com/looker)
*   [What is Model Context Protocol (MCP)? A guide](https://cloud.google.com/blog/topics/developers-practitioners/what-is-model-context-protocol-mcp-guide)
*   [Google Cloud MCP servers overview](https://docs.cloud.google.com/python/docs/samples/mcp-overview)
*   [Looker-managed MCP server](https://docs.cloud.google.com/looker/docs/mcp)
*   [Admin settings — Model Context Protocol (MCP)](https://docs.cloud.google.com/looker/docs/admin-panel-platform-mcp)
*   [Looker CLI](https://github.com/looker-open-source/looker-cli)
*   [Level Up Your Agents: Announcing Google's Official Skills Repository](https://cloud.google.com/blog/topics/developers-practitioners/level-your-agents-announcing-googles-official-skills-repository)

