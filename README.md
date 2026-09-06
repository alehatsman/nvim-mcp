# nvim-mcp

A [Model Context Protocol](https://modelcontextprotocol.io/) server for Neovim. Lets
MCP-aware AI clients (Claude Code, Claude Desktop, etc.) inspect and edit a running
Neovim instance's buffers, run searches, drive LSP, and more — over a real JSON-RPC 2.0
interface, not a bespoke integration per client.

> **Status: exploratory.** This started as a proposal for `neovim/neovim`
> ([neovim/neovim#35457](https://github.com/neovim/neovim/issues/35457)) and was split out
> here as a standalone plugin instead, since core inclusion isn't the near-term direction
> the maintainers there are taking. See [`doc/mcp.txt`](doc/mcp.txt) for the full reference.

## How it works

```
your editor session                    MCP client (Claude Code, etc.)
┌─────────────────┐    msgpack-RPC     ┌──────────────────────────┐
│ nvim --listen    │◄──────────────────┤ nvim --headless (this    │◄── stdio JSON-RPC
│ /tmp/nvim.sock   │      socket        │ plugin's server process) │
└─────────────────┘                    └──────────────────────────┘
```

The MCP server is a **separate**, isolated headless Neovim process. It doesn't run inside
the Neovim instance you're actually editing in — it connects to it over a socket, the same
way `nvim --remote` or any other RPC client would. Your editing session needs nothing but
a listen address; it doesn't even need this plugin installed.

## Quick start

1. Install this plugin so it's on `'runtimepath'` — via `vim.pack.add()`, lazy.nvim, or
   any other plugin manager. This is only needed for the *server* process below, not for
   the Neovim instance you're editing in.

2. Start the Neovim instance you want an AI client to work with:
   ```sh
   nvim --listen /tmp/nvim.sock
   ```
   (Or just open a `:terminal` inside any running Neovim — `$NVIM` is set automatically
   and gets picked up with zero config.)

3. Point your MCP client at this command:
   ```sh
   env MCP_SOCKET_PATH=/tmp/nvim.sock \
       nvim --headless -u NONE -U NONE -i NONE -n \
            --cmd "set rtp+=/path/to/nvim-mcp" \
            --cmd "luafile /path/to/nvim-mcp/scripts/mcp_server_headless.lua"
   ```
   For Claude Code: `claude mcp add nvim -e MCP_SOCKET_PATH=/tmp/nvim.sock -- nvim --headless -u NONE -U NONE -i NONE -n --cmd "set rtp+=/path/to/nvim-mcp" --cmd "luafile /path/to/nvim-mcp/scripts/mcp_server_headless.lua"`

4. Run `:checkhealth mcp` inside the target Neovim instance to confirm the module loads
   and (once a client has connected) that the connection is alive.

## Tools

26 tools are registered by default — buffer read/edit/save, window/tab/fold management,
marks/registers/macros, search & project-wide grep, quickfix, undo/redo, options, and a
set of LSP tools (diagnostics, hover, definition, references, rename). A 27th,
`vim_command` (arbitrary allowlisted ex-command execution), is opt-in only via
`MCP_ALLOW_COMMANDS=1` — it's off by default because it's the one tool that can reach
outside the sandboxed editing surface. See `doc/mcp.txt` for the full list and schemas.

Buffers can be marked `sensitive` (`vim.b[bufnr].mcp_sensitive = true`) to redact their
contents from every read/search tool while still exposing metadata — useful for files
with secrets open alongside the ones you want the AI to see.

## Status & known gaps

- Test coverage is currently written against Neovim's internal test harness
  (`test.testutil`), which doesn't travel with a standalone plugin. Porting to
  [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)'s busted-compatible runner is
  in progress — see `tests/`.
- Real end-to-end testing (a live client, a live second process, a real buffer) has
  caught bugs that pure unit tests with mocked connections missed — most of `tests/`
  today mocks the RPC layer. Treat that split as the thing to fix before trusting this
  in anything but a sandbox.
- Not yet aligned with `vim.json.rpc` ([neovim/neovim#38525](https://github.com/neovim/neovim/pull/38525)),
  the generic JSON-RPC client neovim/neovim is extracting from `vim.lsp.rpc` for exactly
  this kind of use case. That PR is still unmerged; this plugin ships its own minimal
  stdio transport for now and can migrate once it lands.

## License

Apache-2.0, matching the neovim/neovim project this was split from.
