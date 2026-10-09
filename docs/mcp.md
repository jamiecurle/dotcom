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
   (or the public office).
2. Add this to `~/Library/Application Support/Claude/claude_desktop_config.json`
   under `mcpServers`, paste the token into `env`, then fully quit (Cmd-Q) and
   reopen Claude Desktop:

```json
"jamiecurle.com": {
  "command": "/Users/jc/.local/share/mise/shims/npx",
  "args": [
    "-y", "mcp-remote",
    "http://stekpi.tailebf707.ts.net:4000/mcp",
    "--allow-http", "--transport", "http-only",
    "--header", "Authorization:Bearer ${JC_MCP_TOKEN}"
  ],
  "env": { "JC_MCP_TOKEN": "<token from /office/mcp>" }
}
```

The token sits in plain text in that file, so keep the file to yourself. The
token only works from inside the tailnet, can read posts (drafts included)
and file suggestions but change nothing, and expires after 90 days. If it
leaks, revoke it at `/office/mcp` and make a new one.

The absolute `npx` path is there because Claude Desktop doesn't load the
shell's `PATH`. `--allow-http` is fine here: the hop is inside Tailscale's
WireGuard tunnel. `mcp-remote` fills in `${JC_MCP_TOKEN}` from `env`.

For local development, point the URL at `http://localhost:4000/mcp` (not
`127.0.0.1`, which the dev host check rejects) and use a token made in your
dev office.

## Belt and braces

A Cloudflare WAF custom rule blocks `/mcp*` on jamiecurle.com, so public
requests get a 403 at the edge before they reach the app at all.
