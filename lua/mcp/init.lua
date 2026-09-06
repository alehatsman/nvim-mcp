--- MCP (Model Context Protocol) server for Neovim
---@module 'mcp'

local Transport = require('mcp.transport')
local Connection = require('mcp.connection')
local protocol = require('mcp.protocol')
local log = require('mcp.log')

--- @class Server
--- @field transport Transport? Transport instance
--- @field connection Connection? Connection to Neovim
--- @field capabilities table Server capabilities
--- @field client_info table? Client information from initialize
--- @field initialized boolean Whether MCP handshake has completed
local Server = {
  transport = nil,
  connection = nil,
  capabilities = nil,
  client_info = nil,
  initialized = false,
}

--- Start the MCP server
--- @param opts? table Options: { socket_path?: string, log_level?: string, log_file?: string }
--- @return Server
function Server.start(opts)
  opts = opts or {}

  -- Configure logging
  if opts.log_level then
    log.level = log.levels[opts.log_level:upper()] or log.levels.INFO
  end
  if opts.log_file then
    log.log_file = opts.log_file
  end

  log.info('Starting MCP server')

  -- Create connection to Neovim
  local conn, conn_err = Connection.new(opts.socket_path)
  if not conn then
    log.error('Failed to connect to Neovim:', conn_err)
    error(conn_err)
  end
  Server.connection = conn

  -- Initialize capabilities
  Server.capabilities = {
    tools = vim.empty_dict(),
    resources = {
      subscribe = false,
      listChanged = false,
    },
    prompts = {
      listChanged = false,
    },
  }

  -- Load tool/resource/prompt modules (which register themselves)
  require('mcp.tools')
  require('mcp.resources')
  require('mcp.prompts')

  -- Create and start transport
  Server.transport = Transport.new()
  Server.transport:start(
    function(message)
      local id = message.id
      -- Increment pending for requests (those with an id); notifications have id == nil
      if id ~= nil then
        Server.transport:increment_pending()
      end
      vim.schedule(function()
        Server.handle_message(message)
      end)
    end,
    function(code, signal)
      log.info('Transport closed, code:', code, 'signal:', signal)
      if Server.connection then
        Server.connection:close()
      end
      vim.schedule(function()
        vim.cmd('qa!')
      end)
    end
  )

  log.info('MCP server started')
  return Server
end

--- Handle incoming message
--- @param message table JSON-RPC message
function Server.handle_message(message)
  local method = message.method
  local id = message.id

  -- Handle notifications/initialized from client: mark server ready, no response
  if method == protocol.MessageType.Initialized then
    Server.initialized = true
    log.info('Client sent notifications/initialized; server ready')
    return
  end

  -- Reject all non-lifecycle methods before handshake completes
  if not Server.initialized
    and method ~= protocol.MessageType.Initialize
    and method ~= protocol.MessageType.Ping
  then
    if id ~= nil then
      Server.send_error(
        id,
        protocol.ErrorCodes.InvalidRequest,
        'Server not initialized: send initialize first'
      )
    end
    return
  end

  -- Dispatch
  if method == protocol.MessageType.Initialize then
    Server.handle_initialize(id, message.params)
  elseif method == protocol.MessageType.Ping then
    Server.send_response(id, {})
  elseif method == protocol.MessageType.ListTools then
    Server.handle_tools_list(id)
  elseif method == protocol.MessageType.CallTool then
    Server.handle_tool_call(id, message.params)
  elseif method == protocol.MessageType.ListResources then
    Server.handle_resources_list(id)
  elseif method == protocol.MessageType.ReadResource then
    Server.handle_resource_read(id, message.params)
  elseif method == protocol.MessageType.ListPrompts then
    Server.handle_prompts_list(id)
  elseif method == protocol.MessageType.GetPrompt then
    Server.handle_prompt_get(id, message.params)
  else
    -- Unknown method (-32601)
    if id ~= nil then
      Server.send_error(id, protocol.ErrorCodes.MethodNotFound, 'Method not found: ' .. tostring(method))
    end
  end
end

--- Handle initialize request
--- @param id any Request ID
--- @param params? table Initialize parameters
function Server.handle_initialize(id, params)
  log.info('Received initialize request')

  if params then
    Server.client_info = params.clientInfo
    log.info('Client:', params.clientInfo and params.clientInfo.name or 'unknown')
  end

  -- Negotiate protocol version: echo client version if supported, else use highest
  local client_version = params and params.protocolVersion or ''
  local response_version = protocol.SUPPORTED_VERSIONS_SET[client_version]
    and client_version
    or protocol.PROTOCOL_VERSION

  Server.send_response(id, {
    protocolVersion = response_version,
    capabilities = Server.capabilities,
    serverInfo = {
      name = 'mcp-neovim-server',
      version = '0.1.0',
    },
  })
  -- Client will now send notifications/initialized; we wait before accepting tools/resources/prompts
end

--- Handle tools/list request
--- @param id any Request ID
function Server.handle_tools_list(id)
  local tools_module = require('mcp.tools')
  local tools = tools_module.list()
  log.debug('Listing', #tools, 'tools')
  Server.send_response(id, { tools = tools })
end

--- Handle tools/call request
--- @param id any Request ID
--- @param params table Call parameters: { name: string, arguments?: table }
function Server.handle_tool_call(id, params)
  if not params or not params.name then
    Server.send_error(id, protocol.ErrorCodes.InvalidParams, 'Missing tool name')
    return
  end

  local tool_name = params.name
  local arguments = params.arguments or {}

  log.info('Calling tool:', tool_name)

  local tools_module = require('mcp.tools')
  local result, err = tools_module.call(tool_name, arguments, Server.connection)

  if err then
    log.error('Tool call failed:', tool_name, err.message)
    Server.send_error(id, err.code, err.message, err.data)
  else
    Server.send_response(id, result)
  end
end

--- Handle resources/list request
--- @param id any Request ID
function Server.handle_resources_list(id)
  local resources_module = require('mcp.resources')
  local resources = resources_module.list()
  log.debug('Listing', #resources, 'resources')
  Server.send_response(id, { resources = resources })
end

--- Handle resources/read request
--- @param id any Request ID
--- @param params table Read parameters: { uri: string }
function Server.handle_resource_read(id, params)
  if not params or not params.uri then
    Server.send_error(id, protocol.ErrorCodes.InvalidParams, 'Missing resource URI')
    return
  end

  local uri = params.uri
  log.info('Reading resource:', uri)

  local resources_module = require('mcp.resources')
  local result, err = resources_module.read(uri, Server.connection)

  if err then
    log.error('Resource read failed:', uri, err.message)
    Server.send_error(id, err.code, err.message, err.data)
  else
    Server.send_response(id, result)
  end
end

--- Handle prompts/list request
--- @param id any Request ID
function Server.handle_prompts_list(id)
  local prompts_module = require('mcp.prompts')
  local prompts = prompts_module.list()
  log.debug('Listing', #prompts, 'prompts')
  Server.send_response(id, { prompts = prompts })
end

--- Handle prompts/get request
--- @param id any Request ID
--- @param params table Get parameters: { name: string, arguments?: table }
function Server.handle_prompt_get(id, params)
  if not params or not params.name then
    Server.send_error(id, protocol.ErrorCodes.InvalidParams, 'Missing prompt name')
    return
  end

  local prompt_name = params.name
  local arguments = params.arguments or {}

  log.info('Getting prompt:', prompt_name)

  local prompts_module = require('mcp.prompts')
  local result, err = prompts_module.get(prompt_name, arguments, Server.connection)

  if err then
    log.error('Prompt get failed:', prompt_name, err.message)
    Server.send_error(id, err.code, err.message, err.data)
  else
    Server.send_response(id, result)
  end
end

--- Send a successful response
--- @param id any Request ID
--- @param result any Result data
function Server.send_response(id, result)
  if not Server.transport then
    return
  end

  Server.transport:send({
    jsonrpc = '2.0',
    id = id,
    result = result,
  })
  if id ~= nil then
    Server.transport:decrement_pending()
  end
end

--- Send an error response
--- @param id any Request ID
--- @param code number Error code
--- @param message string Error message
--- @param data? any Additional error data
function Server.send_error(id, code, message, data)
  if not Server.transport then
    return
  end

  Server.transport:send({
    jsonrpc = '2.0',
    id = id,
    error = {
      code = code,
      message = message,
      data = data,
    },
  })
  if id ~= nil then
    Server.transport:decrement_pending()
  end
end

--- Send a notification (no response expected)
--- @param method string Method name
--- @param params? table Notification parameters
function Server.send_notification(method, params)
  if not Server.transport then
    return
  end

  Server.transport:send({
    jsonrpc = '2.0',
    method = method,
    params = params,
  })
end

--- Module exports
local M = {}

--- Start the MCP server
--- @param opts? table Options
--- @return Server
function M.start(opts)
  return Server.start(opts)
end

--- Get server status
--- @return table Status information
function M.status()
  local tools_module = require('mcp.tools')
  local resources_module = require('mcp.resources')
  local prompts_module = require('mcp.prompts')

  return {
    running = Server.transport ~= nil,
    connection_alive = Server.connection and Server.connection:is_alive() or false,
    socket_path = Server.connection and Server.connection.socket_path or nil,
    tools_count = #tools_module.list(),
    resources_count = #resources_module.list(),
    prompts_count = #prompts_module.list(),
  }
end

return M
