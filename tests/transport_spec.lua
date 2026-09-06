--- Tests for MCP transport layer
local t = require('test.testutil')
local describe, it, before_each = t.describe, t.it, t.before_each
local n = require('test.functional.testnvim')()
local t_mcp = require('test.functional.plugin.mcp.testutil')

local clear_mcp = t_mcp.clear_mcp
local exec_lua = n.exec_lua
local eq = t.eq

describe('MCP transport', function()
  before_each(clear_mcp)

  describe('process_chunk', function()
    it('fires on_message once for a single complete message', function()
      local count = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local received = {}
        local tr = Transport.new()
        tr.on_message = function(msg) table.insert(received, msg) end
        tr:process_chunk('{"jsonrpc":"2.0","method":"test"}\n')
        return #received
      end)
      eq(1, count)
    end)

    it('fires on_message with correct message content', function()
      local method = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local received = {}
        local tr = Transport.new()
        tr.on_message = function(msg) table.insert(received, msg) end
        tr:process_chunk('{"jsonrpc":"2.0","method":"ping"}\n')
        return received[1] and received[1].method
      end)
      eq('ping', method)
    end)

    it('fires on_message twice for two messages in one chunk', function()
      local count = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local received = {}
        local tr = Transport.new()
        tr.on_message = function(msg) table.insert(received, msg) end
        tr:process_chunk(
          '{"jsonrpc":"2.0","method":"first"}\n{"jsonrpc":"2.0","method":"second"}\n'
        )
        return #received
      end)
      eq(2, count)
    end)

    it('accumulates partial chunks before firing', function()
      local count = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local received = {}
        local tr = Transport.new()
        tr.on_message = function(msg) table.insert(received, msg) end
        -- Send message in two parts: no newline yet
        tr:process_chunk('{"jsonrpc":"2.0","meth')
        local count_after_partial = #received
        -- Complete the message
        tr:process_chunk('od":"test"}\n')
        return count_after_partial * 10 + #received
      end)
      -- 0 after partial, 1 after complete → encoded as 01
      eq(1, count)
    end)

    it('does not fire on_message for partial chunk without newline', function()
      local count = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local received = {}
        local tr = Transport.new()
        tr.on_message = function(msg) table.insert(received, msg) end
        tr:process_chunk('{"jsonrpc":"2.0","method":"incomplete"')
        return #received
      end)
      eq(0, count)
    end)

    it('skips empty lines', function()
      local count = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local received = {}
        local tr = Transport.new()
        tr.on_message = function(msg) table.insert(received, msg) end
        tr:process_chunk('\n\n{"jsonrpc":"2.0","method":"test"}\n\n')
        return #received
      end)
      eq(1, count)
    end)
  end)

  describe('process_line', function()
    it('delivers parsed message to on_message', function()
      local msg = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local received = {}
        local tr = Transport.new()
        tr.on_message = function(m) table.insert(received, m) end
        tr:process_line('{"jsonrpc":"2.0","id":1,"method":"tools/list"}')
        return received[1]
      end)
      assert(msg ~= nil)
      eq(1, msg.id)
      eq('tools/list', msg.method)
    end)

    it('handles batch array: delivers each message', function()
      local count = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local received = {}
        local tr = Transport.new()
        tr.on_message = function(m) table.insert(received, m) end
        tr:process_line('[{"jsonrpc":"2.0","method":"a"},{"jsonrpc":"2.0","method":"b"}]')
        return #received
      end)
      eq(2, count)
    end)

    it('sends parse error response for invalid JSON (stdout handle must be nil)', function()
      -- When stdout_handle is nil, send() is a no-op; we just verify no Lua error is raised
      local ok = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local tr = Transport.new()
        -- stdout_handle is nil by default, so send() silently returns
        local ok, _ = pcall(function()
          tr:process_line('not valid json {{{')
        end)
        return ok
      end)
      eq(true, ok)
    end)
  end)

  describe('pending_requests counter', function()
    it('increments pending_requests', function()
      local count = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local tr = Transport.new()
        tr:increment_pending()
        tr:increment_pending()
        return tr.pending_requests
      end)
      eq(2, count)
    end)

    it('decrements pending_requests', function()
      local count = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local tr = Transport.new()
        tr:increment_pending()
        tr:increment_pending()
        tr:decrement_pending()
        return tr.pending_requests
      end)
      eq(1, count)
    end)

    it('does not call on_exit when stdin is still open', function()
      local exited = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local tr = Transport.new()
        local did_exit = false
        tr.on_exit = function() did_exit = true end
        tr:increment_pending()
        tr:decrement_pending()
        return did_exit
      end)
      eq(false, exited)
    end)

    it('calls on_exit when stdin closed and pending reaches zero', function()
      local exited = exec_lua(function()
        local Transport = require('vim.mcp.transport')
        local tr = Transport.new()
        local did_exit = false
        tr.on_exit = function() did_exit = true end
        tr.stdin_closed = true
        tr:increment_pending()
        tr:decrement_pending() -- triggers exit check
        return did_exit
      end)
      eq(true, exited)
    end)
  end)
end)
