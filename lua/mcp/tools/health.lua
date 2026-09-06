--- Connection health check MCP tool
---@module 'mcp.tools.health'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_health: Check connection health
tools.register('vim_health', function(args, connection)
  local start_time = vim.uv.hrtime()

  -- Try a simple API call to check connection
  local version, err = connection:call('nvim_get_api_info')

  local response_time = (vim.uv.hrtime() - start_time) / 1000000 -- Convert to milliseconds

  if err then
    return {
      content = {
        {
          type = 'text',
          text = string.format('Connection unhealthy: %s', err),
        },
      },
      isError = true,
    }
  end

  local health_info = {
    connected = true,
    socket_path = connection.socket_path,
    response_time_ms = string.format('%.2f', response_time),
    neovim_version = string.format(
      '%d.%d.%d',
      version[2].version.major,
      version[2].version.minor,
      version[2].version.patch
    ),
  }

  return {
    content = {
      {
        type = 'text',
        text = vim.json.encode(health_info),
      },
    },
  }
end, protocol.ToolSchemas.vim_health)

return {}
