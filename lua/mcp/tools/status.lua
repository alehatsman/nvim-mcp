--- Session status MCP tool
---@module 'mcp.tools.status'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_status: Get comprehensive session status
tools.register('vim_status', function(args, connection)
  local bufnr = args.buffer or 0

  -- Build status object
  local status = {}

  -- Get cursor position
  local cursor, cursor_err = connection:call('nvim_win_get_cursor', 0)
  if not cursor_err then
    status.cursor = { line = cursor[1], column = cursor[2] }
  end

  -- Get mode
  local mode, mode_err = connection:call('nvim_get_mode')
  if not mode_err then
    status.mode = mode.mode
  end

  -- Get buffer info
  local name, _ = connection:call('nvim_buf_get_name', bufnr)
  status.buffer = {
    number = bufnr,
    name = name or '[No Name]',
  }

  -- Get buffer line count
  local line_count, _ = connection:call('nvim_buf_line_count', bufnr)
  if line_count then
    status.buffer.line_count = line_count
  end

  -- Get working directory
  local cwd, _ = connection:call('nvim_call_function', 'getcwd', {})
  if cwd then
    status.working_directory = cwd
  end

  -- Get LSP clients (requires running Lua code on remote)
  local lsp_result, _ = connection:exec_lua([[
    local bufnr = ...
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    local client_names = {}
    for _, client in ipairs(clients) do
      table.insert(client_names, client.name)
    end
    return client_names
  ]], { bufnr })

  status.lsp_clients = lsp_result or {}

  -- Detect plugins (requires running Lua code on remote)
  local plugins_result, _ = connection:exec_lua([[
    local plugins = {}
    local checks = {
      telescope = 'telescope',
      treesitter = 'nvim-treesitter',
      cmp = 'cmp',
    }
    for name, module in pairs(checks) do
      local ok = pcall(require, module)
      if ok then
        table.insert(plugins, name)
      end
    end
    return plugins
  ]], {})

  status.plugins = plugins_result or {}

  -- Get window info
  local windows, _ = connection:call('nvim_list_wins')
  if windows then
    status.windows = #windows
  end

  -- Get tab info
  local tabs, _ = connection:call('nvim_list_tabpages')
  if tabs then
    status.tabs = #tabs
  end

  -- Format as JSON
  local json_output = vim.json.encode(status)

  return {
    content = {
      { type = 'text', text = json_output },
    },
  }
end, protocol.ToolSchemas.vim_status)

return {}
