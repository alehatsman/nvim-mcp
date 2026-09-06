--- Tab management MCP tool
---@module 'mcp.tools.tab'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_tab: Manage tabs
tools.register('vim_tab', function(args, connection)
  local action = args.action

  if action == 'new' then
    local _, err = connection:call('nvim_command', 'tabnew')
    if err then
      return nil, protocol.internal_error('Failed to create new tab: ' .. err)
    end
    return {
      content = {
        { type = 'text', text = 'Created new tab' },
      },
    }
  elseif action == 'close' then
    local _, err = connection:call('nvim_command', 'tabclose')
    if err then
      return nil, protocol.internal_error('Failed to close tab: ' .. err)
    end
    return {
      content = {
        { type = 'text', text = 'Closed current tab' },
      },
    }
  elseif action == 'next' then
    local _, err = connection:call('nvim_command', 'tabnext')
    if err then
      return nil, protocol.internal_error('Failed to switch to next tab: ' .. err)
    end
    return {
      content = {
        { type = 'text', text = 'Switched to next tab' },
      },
    }
  elseif action == 'prev' then
    local _, err = connection:call('nvim_command', 'tabprev')
    if err then
      return nil, protocol.internal_error('Failed to switch to previous tab: ' .. err)
    end
    return {
      content = {
        { type = 'text', text = 'Switched to previous tab' },
      },
    }
  elseif action == 'first' then
    local _, err = connection:call('nvim_command', 'tabfirst')
    if err then
      return nil, protocol.internal_error('Failed to switch to first tab: ' .. err)
    end
    return {
      content = {
        { type = 'text', text = 'Switched to first tab' },
      },
    }
  elseif action == 'last' then
    local _, err = connection:call('nvim_command', 'tablast')
    if err then
      return nil, protocol.internal_error('Failed to switch to last tab: ' .. err)
    end
    return {
      content = {
        { type = 'text', text = 'Switched to last tab' },
      },
    }
  elseif action == 'list' then
    local tabs, tab_err = connection:exec_lua([[
      local tabs = vim.api.nvim_list_tabpages()
      local current_tab = vim.api.nvim_get_current_tabpage()
      local result = {}

      for i, tab in ipairs(tabs) do
        local wins = vim.api.nvim_tabpage_list_wins(tab)
        local marker = (tab == current_tab) and '>' or ' '
        table.insert(result, string.format('%s Tab %d: %d windows', marker, i, #wins))
      end

      return table.concat(result, '\n')
    ]], {})

    if tab_err then
      return nil, protocol.internal_error('Failed to list tabs: ' .. tab_err)
    end

    return {
      content = {
        { type = 'text', text = string.format('Tabs:\n%s', tabs) },
      },
    }
  else
    return nil,
      protocol.invalid_params(
        'Invalid action: ' .. action .. ' (must be new, close, next, prev, first, last, or list)'
      )
  end
end, protocol.ToolSchemas.vim_tab)

return {}
