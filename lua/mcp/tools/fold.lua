--- Code folding MCP tool
---@module 'mcp.tools.fold'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')
local util = require('mcp.tools.util')

local VALID_ACTIONS = { 'create', 'open', 'close', 'toggle', 'openall', 'closeall', 'delete' }

local ACTION_CMDS = {
  open     = { cmd = 'normal! zo', msg = 'Opened fold under cursor' },
  close    = { cmd = 'normal! zc', msg = 'Closed fold under cursor' },
  toggle   = { cmd = 'normal! za', msg = 'Toggled fold under cursor' },
  openall  = { cmd = 'normal! zR', msg = 'Opened all folds' },
  closeall = { cmd = 'normal! zM', msg = 'Closed all folds' },
  delete   = { cmd = 'normal! zd', msg = 'Deleted fold under cursor' },
}

--- vim_fold: Manage code folds
tools.register('vim_fold', function(args, connection)
  local action = args.action

  local action_err = util.validate_enum(action, VALID_ACTIONS, 'action')
  if action_err then return nil, action_err end

  if action == 'create' then
    if args.start_line == nil or args.end_line == nil then
      return nil,
        protocol.invalid_params('start_line and end_line are required for create action')
    end

    local sl_err = util.validate_integer(args.start_line, 'start_line')
    if sl_err then return nil, sl_err end

    local el_err = util.validate_integer(args.end_line, 'end_line')
    if el_err then return nil, el_err end

    if args.start_line < 1 then
      return nil, protocol.invalid_params('start_line must be >= 1')
    end
    if args.end_line < args.start_line then
      return nil, protocol.invalid_params('end_line must be >= start_line')
    end

    local cmd = string.format('%d,%dfold', args.start_line, args.end_line)
    local _, err = connection:call('nvim_command', cmd)
    if err then
      return nil, protocol.internal_error('Failed to create fold: ' .. err)
    end

    return {
      content = {
        {
          type = 'text',
          text = string.format(
            'Created fold from line %d to %d',
            args.start_line,
            args.end_line
          ),
        },
      },
    }
  end

  local ac = ACTION_CMDS[action]
  local _, err = connection:call('nvim_command', ac.cmd)
  if err then
    return nil, protocol.internal_error('Failed to ' .. action .. ' fold: ' .. err)
  end

  return {
    content = {
      { type = 'text', text = ac.msg },
    },
  }
end, protocol.ToolSchemas.vim_fold)

return {}
