--- Tests for MCP tools utility module
local t = require('test.testutil')
local describe, it, before_each = t.describe, t.it, t.before_each
local n = require('test.functional.testnvim')()
local t_mcp = require('test.functional.plugin.mcp.testutil')

local clear_mcp = t_mcp.clear_mcp
local exec_lua = n.exec_lua
local eq = t.eq
local matches = t.matches

describe('MCP tools util', function()
  before_each(clear_mcp)

  describe('ui_to_api_line', function()
    it('converts 1-indexed to 0-indexed', function()
      local api_line = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        local result = util.ui_to_api_line(1)
        return result
      end)
      eq(0, api_line)
    end)

    it('converts line 5 to 4', function()
      local api_line = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        local result, _ = util.ui_to_api_line(5)
        return result
      end)
      eq(4, api_line)
    end)

    it('rejects line 0', function()
      local err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        local _, e = util.ui_to_api_line(0)
        return e
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
      matches('must be >= 1', err.message)
    end)

    it('rejects negative line', function()
      local err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        local _, e = util.ui_to_api_line(-5)
        return e
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)

    it('rejects non-integer float', function()
      local err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        local _, e = util.ui_to_api_line(1.5)
        return e
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
      matches('integer', err.message)
    end)

    it('rejects string', function()
      local err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        local _, e = util.ui_to_api_line('5')
        return e
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('validate_line_range', function()
    it('returns correct 0-indexed range', function()
      local s, e = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        local a, b = util.validate_line_range(3, 7)
        return a, b
      end)
      eq(2, s)  -- 3 - 1 = 2
      eq(7, e)  -- end is exclusive, kept as-is
    end)

    it('accepts single-line range', function()
      local s, e = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        local a, b = util.validate_line_range(5, 5)
        return a, b
      end)
      eq(4, s)
      eq(5, e)
    end)

    it('rejects end_line < start_line', function()
      local err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        local _, _, e = util.validate_line_range(10, 5)
        return e
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
      matches('end_line must be >= start_line', err.message)
    end)

    it('rejects start_line < 1', function()
      local s, e, err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        return util.validate_line_range(0, 5)
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)

    it('rejects non-integer start_line', function()
      local s, e, err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        return util.validate_line_range(1.5, 5)
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('validate_enum', function()
    it('accepts valid value', function()
      local err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        return util.validate_enum('insert', { 'insert', 'replace', 'replaceAll' }, 'operation')
      end)
      assert(err == nil)
    end)

    it('rejects invalid value', function()
      local err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        return util.validate_enum('delete', { 'insert', 'replace', 'replaceAll' }, 'operation')
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
      matches('operation must be one of', err.message)
    end)

    it('rejects nil value', function()
      local err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        return util.validate_enum(nil, { 'a', 'b' }, 'field')
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('validate_integer', function()
    it('accepts integer', function()
      local err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        return util.validate_integer(42, 'count')
      end)
      assert(err == nil)
    end)

    it('rejects float', function()
      local err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        return util.validate_integer(3.14, 'count')
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
      matches('count must be an integer', err.message)
    end)

    it('rejects string', function()
      local err = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        return util.validate_integer('5', 'count')
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('is_sensitive', function()
    it('returns true when b:mcp_sensitive is true', function()
      local result = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        local connection = {
          call = function(_, method, bufnr, key)
            if method == 'nvim_buf_get_var' and key == 'mcp_sensitive' then
              return true, nil
            end
          end,
        }
        return util.is_sensitive(connection, 0)
      end)
      assert(result == true)
    end)

    it('returns false when variable is absent', function()
      local result = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        local connection = {
          call = function(_, method, bufnr, key)
            if method == 'nvim_buf_get_var' then
              return nil, 'Key not found: mcp_sensitive'
            end
          end,
        }
        return util.is_sensitive(connection, 0)
      end)
      assert(result == false)
    end)

    it('returns false when variable is false', function()
      local result = exec_lua(function()
        local util = require('vim.mcp.tools.util')
        local connection = {
          call = function(_, method, bufnr, key)
            if method == 'nvim_buf_get_var' then
              return false, nil
            end
          end,
        }
        return util.is_sensitive(connection, 0)
      end)
      assert(result == false)
    end)
  end)
end)
