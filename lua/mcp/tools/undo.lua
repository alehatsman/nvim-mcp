--- Undo/redo MCP tool
---@module 'mcp.tools.undo'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_undo: Undo or redo changes in the current buffer
tools.register('vim_undo', function(args, connection)
  local action = args.action
  local count = math.max(1, args.count or 1)

  if action == 'undo' then
    local result, err = connection:exec_lua([[
      local count = ...
      for _ = 1, count do vim.cmd('undo') end
      local ut = vim.fn.undotree()
      return { seq_cur = ut.seq_cur, seq_last = ut.seq_last }
    ]], { count })
    if err then
      return nil, protocol.internal_error('Failed to undo: ' .. err)
    end
    return {
      content = {
        {
          type = 'text',
          text = string.format('Undo %d change(s) (undo state: %d/%d)',
            count,
            result and result.seq_cur or 0,
            result and result.seq_last or 0),
        },
      },
    }
  elseif action == 'redo' then
    local result, err = connection:exec_lua([[
      local count = ...
      for _ = 1, count do vim.cmd('redo') end
      local ut = vim.fn.undotree()
      return { seq_cur = ut.seq_cur, seq_last = ut.seq_last }
    ]], { count })
    if err then
      return nil, protocol.internal_error('Failed to redo: ' .. err)
    end
    return {
      content = {
        {
          type = 'text',
          text = string.format('Redo %d change(s) (undo state: %d/%d)',
            count,
            result and result.seq_cur or 0,
            result and result.seq_last or 0),
        },
      },
    }
  else
    return nil, protocol.invalid_params(
      'Invalid action: ' .. action .. ' (must be undo or redo)'
    )
  end
end, protocol.ToolSchemas.vim_undo)

return {}
