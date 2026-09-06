--- Test utilities for MCP tests
local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua
local fn = n.fn
local api = n.api

local M = {}

--- Clear with MCP-specific settings
function M.clear_mcp()
  clear({
    env = {
      NVIM_LUA_NOTRACK = '1',
      NVIM_APPNAME = 'nvim_mcp_test',
      VIMRUNTIME = os.getenv('VIMRUNTIME'),
      MCP_ALLOW_COMMANDS = '1',
    },
  })
end

--- Create a fake MCP client that communicates via stdio
function M.create_fake_mcp_client()
  return exec_lua(function()
    local Transport = require('vim.mcp.transport')
    local protocol = require('vim.mcp.protocol')

    local client = {
      transport = Transport.new(),
      message_id = 0,
      pending_responses = {},
      received_messages = {},
    }

    function client:start()
      self.transport:start(
        function(message)
          table.insert(self.received_messages, message)
        end,
        function(code, signal)
          self.exited = true
          self.exit_code = code
          self.exit_signal = signal
        end
      )
    end

    function client:send_request(method, params)
      self.message_id = self.message_id + 1
      local id = self.message_id
      self.transport:send({
        jsonrpc = '2.0',
        id = id,
        method = method,
        params = params,
      })
      return id
    end

    function client:send_notification(method, params)
      self.transport:send({
        jsonrpc = '2.0',
        method = method,
        params = params,
      })
    end

    function client:wait_for_response(id, timeout)
      timeout = timeout or 5000
      local start = vim.uv.now()
      while vim.uv.now() - start < timeout do
        for i, msg in ipairs(self.received_messages) do
          if msg.id == id then
            table.remove(self.received_messages, i)
            return msg
          end
        end
        vim.uv.run('nowait')
      end
      error('Timeout waiting for response to request ' .. id)
    end

    return client
  end)
end

--- Create a test Neovim server with socket
--- @param socket_path string Socket path for the test server
--- @return table server Server handle
function M.create_test_server(socket_path)
  socket_path = socket_path or '/tmp/nvim_mcp_test'

  -- Start a test Neovim instance with socket
  local server = fn.jobstart({
    n.nvim_prog,
    '--clean',
    '--headless',
    '--listen',
    socket_path,
  }, {
    rpc = false,
  })

  -- Wait for socket to be available
  vim.wait(5000, function()
    local stat = vim.uv.fs_stat(socket_path)
    return stat ~= nil
  end)

  return {
    job = server,
    socket_path = socket_path,
    stop = function()
      fn.jobstop(server)
      os.remove(socket_path)
    end,
  }
end

--- Send a JSON-RPC message to stdin and read response
--- @param message table JSON-RPC message
--- @return table response JSON-RPC response
function M.send_mcp_message(message)
  return exec_lua(function(msg)
    -- Simulate stdin/stdout transport
    local json_str = vim.json.encode(msg)
    -- In tests, we'll use a mock transport
    return { jsonrpc = '2.0', id = msg.id, result = { test = 'response' } }
  end, message)
end

return M
