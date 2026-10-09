# Claude Desktop (MCP)

Claude Desktop can read posts and *suggest* edits through a small MCP server
at `/mcp`. It can't change anything itself: every edit lands in
`/office/suggestions` and only reaches the post when it's accepted there,
which saves a revision like any other edit.

## Tools

| Tool               | Does                                                            |
| ------------------ | --------------------------------------------------------------- |
| `list_posts`       | id, title, slug, status, dates for every post (drafts included) |
| `get_post`         | full markdown + metadata, by id or slug                         |
| `search_posts`     | case-insensitive search over title, description, markdown       |
| `suggest_edit`     | files a find-and-replace suggestion for review                  |
| `list_suggestions` | what's already been suggested (pending by default)              |

## How it's locked down

1. **Tailnet only.** `JamieWeb.Plugs.TailnetOnly` 404s anything not addressed
   to `MCP_HOST` (`stekpi.tailebf707.ts.net`) or carrying a `cf-ray` header,
   so nothing that comes through the Cloudflare tunnel gets in. Unset
   `MCP_HOST` and the endpoint is off.
2. **Bearer token.** Create tokens at `/office/mcp`. Only a sha256 hash is
   stored, they expire after 90 days, and they can be revoked there. Browser
   sessions don't work on `/mcp` and MCP tokens don't work anywhere else.
3. **Suggest, don't write.** No tool can edit, publish, unpublish or delete.
   A suggestion has to match exactly once when filed *and* when accepted;
   if the post has moved on it's marked stale instead.
4. **Logged.** Each tool call logs `mcp tools/call <name> token_id=… user_id=…`.

## Claude Desktop setup

1. Create a token at <http://stekpi.tailebf707.ts.net:4000/office/mcp>
   (or the public office) and store it as `JC_MCP_TOKEN` in a 1Password
   environment of its own, so the bridge doesn't get the site's other secrets.
2. Add this to `~/Library/Application Support/Claude/claude_desktop_config.json`
   under `mcpServers`, then restart Claude Desktop:

```json
"jamiecurle.com": {
  "command": "/Users/jc/.local/share/mise/installs/1password/latest/bin/op",
  "args": [
    "run", "--environment", "<mcp-environment-id>", "--",
    "/Users/jc/.local/share/mise/shims/npx", "-y", "mcp-remote",
    "http://stekpi.tailebf707.ts.net:4000/mcp",
    "--allow-http", "--transport", "http-only",
    "--header", "Authorization:Bearer ${JC_MCP_TOKEN}"
  ]
}
```

Absolute paths because Claude Desktop doesn't load the shell's `PATH`.
`--allow-http` is fine here: the hop is inside Tailscale's WireGuard tunnel.

## Belt and braces

Add a Cloudflare WAF custom rule blocking `http.request.uri.path wildcard
"/mcp*"` on jamiecurle.com, so public requests are dropped at the edge before
they reach the app at all.
