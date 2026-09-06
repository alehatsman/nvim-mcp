--- Option management MCP tool
---@module 'mcp.tools.option'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_option: Get or set Vim options
tools.register('vim_option', function(args, connection)
  local action = args.action
  local name = args.name
  local scope = args.scope or 'local'

  if scope ~= 'global' and scope ~= 'local' then
    return nil, protocol.invalid_params('scope must be global or local')
  end

  local scope_opts = { scope = scope }

  if action == 'get' then
    local value, err = connection:call('nvim_get_option_value', name, scope_opts)
    if err then
      return nil, protocol.internal_error('Failed to get option ' .. name .. ': ' .. err)
    end
    return {
      content = {
        { type = 'text', text = string.format('%s = %s', name, vim.inspect(value)) },
      },
    }
  elseif action == 'set' then
    if args.value == nil then
      return nil, protocol.invalid_params('value is required for set action')
    end
    local _, err = connection:call('nvim_set_option_value', name, args.value, scope_opts)
    if err then
      return nil, protocol.internal_error('Failed to set option ' .. name .. ': ' .. err)
    end
    return {
      content = {
        { type = 'text', text = string.format('Set %s = %s', name, vim.inspect(args.value)) },
      },
    }
  else
    return nil, protocol.invalid_params(
      'Invalid action: ' .. action .. ' (must be get or set)'
    )
  end
end, protocol.ToolSchemas.vim_option)

return {}
