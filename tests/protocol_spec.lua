--- Tests for MCP protocol module
local t = require('test.testutil')
local describe, it, before_each = t.describe, t.it, t.before_each
local n = require('test.functional.testnvim')()
local t_mcp = require('test.functional.plugin.mcp.testutil')

local clear_mcp = t_mcp.clear_mcp
local exec_lua = n.exec_lua
local eq = t.eq

describe('MCP protocol', function()
  before_each(clear_mcp)

  it('defines protocol version', function()
    local version = exec_lua(function()
      return require('vim.mcp.protocol').PROTOCOL_VERSION
    end)
    eq('2025-11-25', version)
  end)

  it('defines message types', function()
    local types = exec_lua(function()
      return require('vim.mcp.protocol').MessageType
    end)
    eq('initialize', types.Initialize)
    eq('notifications/initialized', types.Initialized)
    eq('tools/list', types.ListTools)
    eq('tools/call', types.CallTool)
    eq('resources/list', types.ListResources)
    eq('resources/read', types.ReadResource)
  end)

  it('has supported versions set', function()
    local versions = exec_lua(function()
      local p = require('vim.mcp.protocol')
      return {
        v25 = p.SUPPORTED_VERSIONS_SET['2025-11-25'],
        v24 = p.SUPPORTED_VERSIONS_SET['2024-11-05'],
        vunk = p.SUPPORTED_VERSIONS_SET['9999-99-99'],
      }
    end)
    eq(true, versions.v25)
    eq(true, versions.v24)
    eq(nil, versions.vunk)
  end)

  it('negotiates protocol version: echoes supported client version', function()
    local result = exec_lua(function()
      local p = require('vim.mcp.protocol')
      local cv = '2024-11-05'
      return p.SUPPORTED_VERSIONS_SET[cv] and cv or p.PROTOCOL_VERSION
    end)
    eq('2024-11-05', result)
  end)

  it('negotiates protocol version: falls back to highest for unknown', function()
    local result = exec_lua(function()
      local p = require('vim.mcp.protocol')
      local cv = '1900-01-01'
      return p.SUPPORTED_VERSIONS_SET[cv] and cv or p.PROTOCOL_VERSION
    end)
    eq('2025-11-25', result)
  end)

  it('defines error codes', function()
    local codes = exec_lua(function()
      return require('vim.mcp.protocol').ErrorCodes
    end)
    eq(-32700, codes.ParseError)
    eq(-32600, codes.InvalidRequest)
    eq(-32601, codes.MethodNotFound)
    eq(-32602, codes.InvalidParams)
    eq(-32603, codes.InternalError)
  end)

  it('creates MCP errors', function()
    local err = exec_lua(function()
      local protocol = require('vim.mcp.protocol')
      local err = protocol.invalid_params('test error', { field = 'value' })
      return { code = err.code, message = err.message, data = err.data }
    end)
    eq(-32602, err.code)
    eq('test error', err.message)
    eq({ field = 'value' }, err.data)
  end)

  it('defines tool schemas', function()
    local schemas = exec_lua(function()
      return require('vim.mcp.protocol').ToolSchemas
    end)
    -- Check some key tools exist
    assert(schemas.vim_buffer ~= nil, 'vim_buffer schema should exist')
    assert(schemas.vim_command ~= nil, 'vim_command schema should exist')
    assert(schemas.vim_status ~= nil, 'vim_status schema should exist')
  end)

  it('vim_command schema requires command parameter', function()
    local schema = exec_lua(function()
      return require('vim.mcp.protocol').ToolSchemas.vim_command
    end)
    eq('object', schema.type)
    eq(1, #schema.required)
    eq('command', schema.required[1])
  end)

  it('vim_edit schema has correct operation enum', function()
    local schema = exec_lua(function()
      return require('vim.mcp.protocol').ToolSchemas.vim_edit
    end)
    local ops = schema.properties.operation.enum
    assert(vim.tbl_contains(ops, 'insert'))
    assert(vim.tbl_contains(ops, 'replace'))
    assert(vim.tbl_contains(ops, 'replaceAll'))
  end)
end)
