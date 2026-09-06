--- Quickfix list MCP tool
---@module 'mcp.tools.quickfix'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_quickfix: Manage quickfix list
tools.register('vim_quickfix', function(args, connection)
  local action = args.action

  if action == 'list' then
    local items, err = connection:call('nvim_call_function', 'getqflist', {})
    if err then
      return nil, protocol.internal_error('Failed to get quickfix list: ' .. err)
    end

    local lines = {}
    for i, item in ipairs(items or {}) do
      local fname = ''
      if item.bufnr and item.bufnr > 0 then
        local name, _ = connection:call('nvim_buf_get_name', item.bufnr)
        fname = name or '[No Name]'
      end
      table.insert(lines, string.format('%d: %s:%d:%d: %s',
        i, fname, item.lnum or 0, item.col or 0, item.text or ''))
    end

    return {
      content = {
        {
          type = 'text',
          text = #lines > 0 and table.concat(lines, '\n') or '[Empty quickfix list]',
        },
      },
    }
  elseif action == 'next' then
    local _, err = connection:call('nvim_command', 'cnext')
    if err then
      return nil, protocol.internal_error('Failed to go to next quickfix entry: ' .. err)
    end
    return { content = { { type = 'text', text = 'Moved to next quickfix entry' } } }
  elseif action == 'prev' then
    local _, err = connection:call('nvim_command', 'cprev')
    if err then
      return nil, protocol.internal_error('Failed to go to previous quickfix entry: ' .. err)
    end
    return { content = { { type = 'text', text = 'Moved to previous quickfix entry' } } }
  elseif action == 'first' then
    local _, err = connection:call('nvim_command', 'cfirst')
    if err then
      return nil, protocol.internal_error('Failed to go to first quickfix entry: ' .. err)
    end
    return { content = { { type = 'text', text = 'Moved to first quickfix entry' } } }
  elseif action == 'last' then
    local _, err = connection:call('nvim_command', 'clast')
    if err then
      return nil, protocol.internal_error('Failed to go to last quickfix entry: ' .. err)
    end
    return { content = { { type = 'text', text = 'Moved to last quickfix entry' } } }
  elseif action == 'clear' then
    local _, err = connection:call('nvim_call_function', 'setqflist', { {}, 'r' })
    if err then
      return nil, protocol.internal_error('Failed to clear quickfix list: ' .. err)
    end
    return { content = { { type = 'text', text = 'Quickfix list cleared' } } }
  else
    return nil, protocol.invalid_params(
      'Invalid action: ' .. action .. ' (must be list, next, prev, first, last, or clear)'
    )
  end
end, protocol.ToolSchemas.vim_quickfix)

return {}
