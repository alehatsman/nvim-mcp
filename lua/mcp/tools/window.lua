--- Window management MCP tool
---@module 'mcp.tools.window'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_window: Manage windows
tools.register('vim_window', function(args, connection)
  local action = args.action

  if action == 'split' then
    local _, err = connection:call('nvim_command', 'split')
    if err then
      return nil, protocol.internal_error('Failed to split window: ' .. err)
    end
    return {
      content = {
        { type = 'text', text = 'Created horizontal split' },
      },
    }
  elseif action == 'vsplit' then
    local _, err = connection:call('nvim_command', 'vsplit')
    if err then
      return nil, protocol.internal_error('Failed to vsplit window: ' .. err)
    end
    return {
      content = {
        { type = 'text', text = 'Created vertical split' },
      },
    }
  elseif action == 'close' then
    local _, err = connection:call('nvim_command', 'close')
    if err then
      return nil, protocol.internal_error('Failed to close window: ' .. err)
    end
    return {
      content = {
        { type = 'text', text = 'Closed current window' },
      },
    }
  elseif action == 'navigate' then
    if not args.direction then
      return nil, protocol.invalid_params('direction is required for navigate action')
    end

    local direction = args.direction
    if not vim.tbl_contains({ 'h', 'j', 'k', 'l' }, direction) then
      return nil, protocol.invalid_params('direction must be h, j, k, or l')
    end

    local _, err = connection:call('nvim_command', 'wincmd ' .. direction)
    if err then
      return nil, protocol.internal_error('Failed to navigate window: ' .. err)
    end

    local dir_name = ({
      h = 'left',
      j = 'down',
      k = 'up',
      l = 'right',
    })[direction]

    return {
      content = {
        { type = 'text', text = string.format('Navigated to window %s', dir_name) },
      },
    }
  else
    return nil,
      protocol.invalid_params('Invalid action: ' .. action .. ' (must be split, vsplit, close, or navigate)')
  end
end, protocol.ToolSchemas.vim_window)

return {}
