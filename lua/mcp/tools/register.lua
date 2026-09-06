--- Register management MCP tool
---@module 'mcp.tools.register'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_register: Set register contents
tools.register('vim_register', function(args, connection)
  local register = args.register
  local content = args.content

  if not register or #register ~= 1 then
    return nil, protocol.invalid_params('register must be a single character')
  end

  -- Set register using Lua code on remote
  local _, err = connection:exec_lua([[
    local register, content = ...
    vim.fn.setreg(register, content)
  ]], { register, content })

  if err then
    return nil, protocol.internal_error('Failed to set register: ' .. err)
  end

  return {
    content = {
      {
        type = 'text',
        text = string.format('Set register "%s" to: %s', register, content:sub(1, 50)),
      },
    },
  }
end, protocol.ToolSchemas.vim_register)

return {}
