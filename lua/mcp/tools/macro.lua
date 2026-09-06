--- Macro recording and playback MCP tool
---@module 'mcp.tools.macro'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_macro: Record, stop, or play macros
tools.register('vim_macro', function(args, connection)
  local action = args.action
  local register = args.register

  if action == 'record' then
    if not register or #register ~= 1 then
      return nil, protocol.invalid_params('register is required for record action')
    end

    -- Start recording
    local _, err = connection:call('nvim_input', 'q' .. register)
    if err then
      return nil, protocol.internal_error('Failed to start recording: ' .. err)
    end

    return {
      content = {
        { type = 'text', text = string.format('Started recording macro to register %s', register) },
      },
    }
  elseif action == 'stop' then
    -- Stop recording
    local _, err = connection:call('nvim_input', 'q')
    if err then
      return nil, protocol.internal_error('Failed to stop recording: ' .. err)
    end

    return {
      content = {
        { type = 'text', text = 'Stopped recording macro' },
      },
    }
  elseif action == 'play' then
    if not register or #register ~= 1 then
      return nil, protocol.invalid_params('register is required for play action')
    end

    -- Play macro
    local _, err = connection:call('nvim_input', '@' .. register)
    if err then
      return nil, protocol.internal_error('Failed to play macro: ' .. err)
    end

    return {
      content = {
        { type = 'text', text = string.format('Played macro from register %s', register) },
      },
    }
  else
    return nil,
      protocol.invalid_params('Invalid action: ' .. action .. ' (must be record, stop, or play)')
  end
end, protocol.ToolSchemas.vim_macro)

return {}
