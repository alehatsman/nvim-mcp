--- MCP connection to Neovim instance
--- Handles socket connection and RPC communication
---@module 'mcp.connection'

local log = require('mcp.log')

--- @class Connection
--- @field type string Connection type ('socket')
--- @field channel number RPC channel ID
--- @field socket_path string Socket path
local Connection = {}
Connection.__index = Connection

--- Discover Neovim socket path
--- Priority: $NVIM > $NVIM_SOCKET_PATH > serverlist()
--- @return string? socket_path Socket path or nil if not found
function Connection.discover_socket()
  -- 1. $NVIM — set automatically by Neovim for :terminal child processes
  local nvim_env = vim.env.NVIM
  if nvim_env and nvim_env ~= '' then
    log.debug('Using $NVIM socket:', nvim_env)
    return nvim_env
  end

  -- 2. $NVIM_SOCKET_PATH — conventional variable users set in their shell config
  local socket_env = vim.env.NVIM_SOCKET_PATH
  if socket_env and socket_env ~= '' then
    log.debug('Using $NVIM_SOCKET_PATH:', socket_env)
    return socket_env
  end

  -- 3. serverlist() scan — this Neovim's own advertised server addresses.
  --    Useful when the MCP server is loaded as a plugin inside a running Neovim
  --    (the headless MCP nvim connects back to the editing nvim via its socket).
  local ok, servers = pcall(vim.fn.serverlist)
  if ok and servers and #servers > 0 then
    log.debug('Using serverlist() socket:', servers[1])
    return servers[1]
  end

  return nil
end

--- Create a new connection to Neovim
--- @param socket_path? string Socket path (auto-discovered if nil)
--- @return Connection?
--- @return string? error Error message if connection failed
function Connection.new(socket_path)
  -- Discover socket if not provided
  if not socket_path or socket_path == '' then
    socket_path = Connection.discover_socket()
    if not socket_path then
      return nil,
        'No Neovim socket found. Set $NVIM, $NVIM_SOCKET_PATH, or set $MCP_SOCKET_PATH.'
    end
  end

  log.info('Connecting to Neovim at:', socket_path)

  -- Detect transport type: host:port -> tcp, everything else -> pipe
  local transport_type = socket_path:match('^[^/\\]+:%d+$') and 'tcp' or 'pipe'
  log.debug('Transport type:', transport_type)
  local ok, channel = pcall(vim.fn.sockconnect, transport_type, socket_path, { rpc = true })
  if not ok then
    return nil, 'Failed to connect to socket: ' .. tostring(channel)
  end

  if not channel or channel == 0 then
    return nil, 'Invalid channel returned from sockconnect'
  end

  -- Verify connection by calling nvim_get_api_info
  local info_ok, info = pcall(vim.fn.rpcrequest, channel, 'nvim_get_api_info')
  if not info_ok or not info then
    vim.fn.chanclose(channel)
    return nil, 'Failed to verify Neovim connection: ' .. tostring(info)
  end

  local v = info[2].version
  log.info('Connected to Neovim, channel:', channel, 'version:', v.major .. '.' .. v.minor)

  local self = setmetatable({
    type = 'socket',
    channel = channel,
    socket_path = socket_path,
  }, Connection)

  return self
end

--- Call a Neovim API method
--- @param method string API method name (e.g., 'nvim_buf_get_lines')
--- @param ... any Method arguments
--- @return any result Result from API call
--- @return string? error Error message if call failed
function Connection:call(method, ...)
  if not self.channel then
    return nil, 'Connection not initialized'
  end

  log.trace('RPC call:', method, ...)

  -- Use vim.rpcrequest (Lua API) instead of vim.fn.rpcrequest (Vimscript)
  local ok, result = pcall(vim.rpcrequest, self.channel, method, ...)
  if not ok then
    log.error('RPC call failed:', method, result)
    return nil, tostring(result)
  end

  return result, nil
end

--- Execute Lua code on the remote Neovim instance
--- @param code string Lua code to execute
--- @return any result Result from execution
--- @return string? error Error message if execution failed
function Connection:exec_lua(code, args)
  return self:call('nvim_exec_lua', code, args or {})
end

--- Close the connection
function Connection:close()
  if self.channel then
    log.info('Closing connection, channel:', self.channel)
    pcall(vim.fn.chanclose, self.channel)
    self.channel = nil
  end
end

--- Check if connection is alive
--- @return boolean
function Connection:is_alive()
  if not self.channel then
    return false
  end

  -- Try a simple API call to check if connection is alive
  local ok = pcall(vim.fn.rpcrequest, self.channel, 'nvim_get_api_info')
  return ok
end

return Connection
