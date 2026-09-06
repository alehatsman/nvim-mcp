# MCP Tests

> **Not runnable as-is in this repo.** These specs were copied over from the
> `neovim/neovim` core branch this plugin was split from, and still depend on
> `test.testutil` / `test.functional.testnvim` — internal to the Neovim source
> tree, not available to a standalone plugin. Porting them to
> [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)'s busted-compatible
> runner is the next piece of work (see the main README's "Status & known
> gaps"). Kept here so the test cases and coverage aren't lost in the meantime.

This directory contains functional tests for the MCP (Model Context Protocol) server implementation.

## Test Structure

Following Neovim's testing patterns:

```
test/functional/plugin/mcp/
├── README.md              # This file
├── testutil.lua           # MCP test utilities
├── protocol_spec.lua      # Protocol definitions and schemas
├── tools_spec.lua         # All 27 tools (26 always registered, vim_command opt-in)
├── resources_spec.lua     # 2 resources (session, buffers)
├── connection_spec.lua    # Connection and socket discovery
├── transport_spec.lua     # stdio transport (framing, partial reads)
├── lifecycle_spec.lua     # Server startup/shutdown lifecycle
├── e2e_spec.lua           # Full initialize → tools/call round trip
└── util_spec.lua          # Shared tool helpers
```

## Test Framework

Tests use Neovim's own busted-style harness (`test.testutil`), the same one every other
functional spec in the tree uses:
- `describe()` - Test suites
- `it()` - Individual test cases
- `before_each()` - Setup before each test
- `after_each()` - Cleanup after each test

These are no longer Lua globals (see `test(harness): migrate away from magic globals`) —
each spec file aliases them locally:

```lua
local t = require('test.testutil')
local describe, it, before_each = t.describe, t.it, t.before_each
```

## Running Tests

### Run All MCP Tests

```bash
make functionaltest TEST_FILE=test/functional/plugin/mcp
```

### Run a Specific File

```bash
make functionaltest TEST_FILE=test/functional/plugin/mcp/tools_spec.lua
```

### Run with a Name Filter

```bash
make functionaltest TEST_FILE=test/functional/plugin/mcp/tools_spec.lua TEST_FILTER="vim_buffer"
```

(`$BUSTED_ARGS` from older Neovim versions is no longer read by the build; use
`TEST_FILE`/`TEST_FILTER`.)

## Test Coverage

- **protocol_spec.lua** — protocol version, message types, error codes, all 27 tool schemas
- **tools_spec.lua** — registry (27 tools) + behavior for every tool, including the
  security-relevant ones (`vim_command` allowlist/rejection, sensitive-buffer redaction
  in `vim_buffer`/`vim_grep`, path-traversal rejection in `vim_file_open`)
- **resources_spec.lua** — `nvim://session`, `nvim://buffers`
- **connection_spec.lua** — socket discovery priority ($NVIM, $NVIM_SOCKET_PATH, serverlist())
- **transport_spec.lua** — stdio framing, partial/split reads
- **lifecycle_spec.lua** — startup/shutdown, stdin-close handling
- **e2e_spec.lua** — a real `initialize` → `tools/call` round trip end to end

163 tests total, all passing as of the current branch tip.

## Test Utilities

### testutil.lua

```lua
local t_mcp = require('test.functional.plugin.mcp.testutil')

-- Clear Neovim with MCP-specific settings
t_mcp.clear_mcp()
```

## Writing New Tests

```lua
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_mcp = require('test.functional.plugin.mcp.testutil')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear_mcp = t_mcp.clear_mcp
local exec_lua = n.exec_lua
local eq = t.eq

describe('My MCP feature', function()
  before_each(clear_mcp)

  it('does something', function()
    local result = exec_lua(function()
      local mcp = require('vim.mcp')
      return mcp.something()
    end)
    eq(expected_value, result)
  end)
end)
```

### Mock Connection Pattern

Most tool tests don't need a live socket — they pass a stub `connection`:

```lua
local result = exec_lua(function()
  local tools = require('vim.mcp.tools')
  local connection = {
    call = function(_, method, ...)
      if method == 'nvim_buf_get_lines' then
        return { 'line 1', 'line 2' }
      end
    end,
  }
  return tools.call('vim_buffer', { buffer = 0 }, connection)
end)
```

`e2e_spec.lua` is the one file that exercises a real socket + real server process instead.

## Test Maintenance

When adding a new tool:
1. Add its schema to `protocol.lua` (`properties = vim.empty_dict()` for a
   no-argument tool — a plain `{}` encodes as JSON `[]` and breaks strict MCP clients).
2. Register it in `tools/init.lua`.
3. Add its test cases to `tools_spec.lua` and bump the registry-count assertion.
4. Update this README's tool count.
