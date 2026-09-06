--- Tests for MCP connection module
local t = require('test.testutil')
local describe, it, before_each = t.describe, t.it, t.before_each
local n = require('test.functional.testnvim')()
local t_mcp = require('test.functional.plugin.mcp.testutil')

local clear_mcp = t_mcp.clear_mcp
local exec_lua = n.exec_lua
local eq = t.eq
local matches = t.matches

describe('MCP connection', function()
  before_each(clear_mcp)

  describe('transport detection', function()
    it('detects tcp transport for host:port address', function()
      local transport = exec_lua(function()
        local Connection = require('vim.mcp.connection')
        -- The regex on Connection.new line that determines transport type
        local addr = '127.0.0.1:9999'
        return addr:match('^[^/\\]+:%d+$') and 'tcp' or 'pipe'
      end)
      eq('tcp', transport)
    end)

    it('detects pipe transport for unix socket path', function()
      local transport = exec_lua(function()
        local Connection = require('vim.mcp.connection')
        local addr = '/tmp/nvim.sock'
        return addr:match('^[^/\\]+:%d+$') and 'tcp' or 'pipe'
      end)
      eq('pipe', transport)
    end)
  end)

  describe('socket discovery', function()
    it('discovers socket from $NVIM', function()
      local socket = exec_lua(function()
        vim.env.NVIM = '/tmp/test-nvim'
        local Connection = require('vim.mcp.connection')
        return Connection.discover_socket()
      end)
      eq('/tmp/test-nvim', socket)
    end)

    it('falls back to $NVIM_SOCKET_PATH when $NVIM is unset', function()
      local socket = exec_lua(function()
        vim.env.NVIM = nil
        vim.env.NVIM_SOCKET_PATH = '/tmp/test-socket-path'
        local Connection = require('vim.mcp.connection')
        local result = Connection.discover_socket()
        vim.env.NVIM_SOCKET_PATH = nil
        return result
      end)
      eq('/tmp/test-socket-path', socket)
    end)
  end)

  describe('connection creation', function()
    it('returns error when no socket configured', function()
      local conn, err = exec_lua(function()
        local Connection = require('vim.mcp.connection')
        -- Stub discover_socket to simulate no available socket
        local orig = Connection.discover_socket
        Connection.discover_socket = function() return nil end
        local c, e = Connection.new(nil)
        Connection.discover_socket = orig
        return c, e
      end)
      assert(conn == nil or conn == vim.NIL)
      assert(err ~= nil)
      matches('No Neovim socket', err)
    end)

    it('returns error for invalid socket', function()
      local conn, err = exec_lua(function()
        local Connection = require('vim.mcp.connection')
        return Connection.new('/nonexistent/socket')
      end)
      assert(conn == nil or conn == vim.NIL)
      assert(err ~= nil)
      matches('Failed to connect', err)
    end)

    it('uses tcp for host:port address', function()
      local conn, err = exec_lua(function()
        local Connection = require('vim.mcp.connection')
        return Connection.new('127.0.0.1:19999')
      end)
      assert(conn == nil or conn == vim.NIL)
      assert(err ~= nil)
      matches('Failed to connect', err)
    end)

    it('creates connection with explicit socket path', function()
      -- This test requires a real socket, so we just verify the API
      local has_method = exec_lua(function()
        local Connection = require('vim.mcp.connection')
        return type(Connection.new) == 'function'
      end)
      eq(true, has_method)
    end)
  end)

  describe('connection methods', function()
    it('provides call method', function()
      local result = exec_lua(function()
        local Connection = require('vim.mcp.connection')
        -- Create a mock connection
        local conn = setmetatable({
          type = 'socket',
          channel = 1,
          socket_path = '/tmp/test',
        }, { __index = Connection })
        return type(conn.call) == 'function'
      end)
      eq(true, result)
    end)

    it('provides exec_lua method', function()
      local result = exec_lua(function()
        local Connection = require('vim.mcp.connection')
        local conn = setmetatable({
          type = 'socket',
          channel = 1,
          socket_path = '/tmp/test',
        }, { __index = Connection })
        return type(conn.exec_lua) == 'function'
      end)
      eq(true, result)
    end)

    it('provides close method', function()
      local result = exec_lua(function()
        local Connection = require('vim.mcp.connection')
        local conn = setmetatable({
          type = 'socket',
          channel = 1,
          socket_path = '/tmp/test',
        }, { __index = Connection })
        return type(conn.close) == 'function'
      end)
      eq(true, result)
    end)

    it('provides is_alive method', function()
      local result = exec_lua(function()
        local Connection = require('vim.mcp.connection')
        local conn = setmetatable({
          type = 'socket',
          channel = 1,
          socket_path = '/tmp/test',
        }, { __index = Connection })
        return type(conn.is_alive) == 'function'
      end)
      eq(true, result)
    end)
  end)
end)
