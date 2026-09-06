--- MCP stdio transport layer
--- Handles newline-delimited JSON communication over stdin/stdout
---@module 'mcp.transport'

local log = require('mcp.log')

--- @class Transport
--- @field stdin_handle any Stdin uv pipe handle
--- @field stdout_handle any Stdout uv pipe handle
--- @field read_buffer string Accumulator for partial lines
--- @field on_message? function Message callback
--- @field on_exit? function Exit callback
--- @field pending_requests number Counter for in-flight requests
--- @field stdin_closed boolean Whether stdin has been closed
local Transport = {}
Transport.__index = Transport

--- Create a new transport
--- @return Transport
function Transport.new()
  local self = setmetatable({
    stdin_handle = nil,
    stdout_handle = nil,
    read_buffer = '',
    on_message = nil,
    on_exit = nil,
    pending_requests = 0,
    stdin_closed = false,
  }, Transport)
  return self
end

--- Start the transport (begin reading stdin)
--- @param on_message function Callback for incoming messages: function(message)
--- @param on_exit function Callback for transport closure: function(code, signal)
function Transport:start(on_message, on_exit)
  self.on_message = on_message
  self.on_exit = on_exit

  -- Create pipe handles
  self.stdin_handle = vim.uv.new_pipe(false)
  self.stdout_handle = vim.uv.new_pipe(false)

  if not self.stdin_handle or not self.stdout_handle then
    log.error('Failed to create pipe handles')
    if on_exit then
      on_exit(1, 0)
    end
    return
  end

  -- Open stdin (fd 0) and stdout (fd 1)
  local stdin_ok = self.stdin_handle:open(0)
  local stdout_ok = self.stdout_handle:open(1)

  if not stdin_ok or not stdout_ok then
    log.error('Failed to open stdin/stdout')
    if on_exit then
      on_exit(1, 0)
    end
    return
  end

  log.info('Transport started, reading from stdin')

  -- Start reading from stdin
  self.stdin_handle:read_start(function(err, chunk)
    if err then
      log.error('Read error')
      self:close()
      if self.on_exit then
        self.on_exit(1, 0)
      end
      return
    end

    if not chunk then
      -- EOF - mark stdin closed, exit if no pending requests
      self.stdin_closed = true
      if self.pending_requests == 0 then
        self:close()
        if self.on_exit then
          self.on_exit(0, 0)
        end
      end
      return
    end

    -- Process incoming data
    self:process_chunk(chunk)
  end)
end

--- Process a chunk of data from stdin
--- @param chunk string Data chunk
function Transport:process_chunk(chunk)
  -- Add chunk to buffer
  self.read_buffer = self.read_buffer .. chunk

  -- Process complete lines (newline-delimited JSON)
  while true do
    local newline_pos = self.read_buffer:find('\n', 1, true)
    if not newline_pos then
      break
    end

    -- Extract line (excluding newline)
    local line = self.read_buffer:sub(1, newline_pos - 1)
    self.read_buffer = self.read_buffer:sub(newline_pos + 1)

    -- Skip empty lines
    if line ~= '' then
      self:process_line(line)
    end
  end
end

--- Process a complete line (JSON message)
--- @param line string JSON message line
function Transport:process_line(line)
  log.trace('Received line')

  -- Parse JSON
  local ok, decoded = pcall(vim.json.decode, line)
  if not ok then
    log.error('JSON parse error')
    -- Send parse error response
    self:send({
      jsonrpc = '2.0',
      id = vim.NIL,
      error = {
        code = -32700,
        message = 'Parse error',
      },
    })
    return
  end

  -- Handle batch arrays
  if type(decoded) == 'table' and decoded[1] then
    for _, msg in ipairs(decoded) do
      if self.on_message then
        self.on_message(msg)
      end
    end
  elseif self.on_message then
    self.on_message(decoded)
  end
end

--- Increment pending request counter
function Transport:increment_pending()
  self.pending_requests = self.pending_requests + 1
end

--- Decrement pending request counter and check for exit
function Transport:decrement_pending()
  self.pending_requests = self.pending_requests - 1
  if self.stdin_closed and self.pending_requests == 0 then
    self:close()
    if self.on_exit then
      self.on_exit(0, 0)
    end
  end
end

--- Send a message to stdout
--- @param message table JSON-RPC message
function Transport:send(message)
  if not self.stdout_handle then
    return
  end

  -- Encode message to JSON
  local ok, encoded = pcall(vim.json.encode, message)
  if not ok then
    log.error('JSON encode error')
    return
  end

  -- Send newline-delimited JSON
  local data = encoded .. '\n'

  self.stdout_handle:write(data, function(err)
    if err then
      log.error('Write error')
    end
  end)
end

--- Close the transport
function Transport:close()
  log.info('Closing transport')

  if self.stdin_handle then
    if not self.stdin_handle:is_closing() then
      self.stdin_handle:read_stop()
      self.stdin_handle:close()
    end
    self.stdin_handle = nil
  end

  if self.stdout_handle then
    if not self.stdout_handle:is_closing() then
      self.stdout_handle:close()
    end
    self.stdout_handle = nil
  end
end

--- Check if transport is closing
--- @return boolean
function Transport:is_closing()
  return self.stdin_handle == nil or self.stdout_handle == nil
end

return Transport
