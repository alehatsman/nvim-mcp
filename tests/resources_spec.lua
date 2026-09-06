--- Tests for MCP resources
local t = require('test.testutil')
local describe, it, before_each = t.describe, t.it, t.before_each
local n = require('test.functional.testnvim')()
local t_mcp = require('test.functional.plugin.mcp.testutil')

local clear_mcp = t_mcp.clear_mcp
local exec_lua = n.exec_lua
local eq = t.eq
local matches = t.matches

describe('MCP resources', function()
  before_each(clear_mcp)

  describe('resource registry', function()
    it('registers 2 resources', function()
      local count = exec_lua(function()
        local resources = require('vim.mcp.resources')
        return #resources.list()
      end)
      eq(2, count)
    end)

    it('lists all resource definitions', function()
      local resources = exec_lua(function()
        return require('vim.mcp.resources').list()
      end)
      for _, resource in ipairs(resources) do
        assert(resource.uri ~= nil, 'Resource should have uri')
        assert(resource.name ~= nil, 'Resource should have name')
        assert(resource.description ~= nil, 'Resource should have description')
        assert(resource.mimeType ~= nil, 'Resource should have mimeType')
      end
    end)

    it('includes session and buffers resources', function()
      local uris = exec_lua(function()
        local resources = require('vim.mcp.resources')
        local uris = {}
        for uri, _ in pairs(resources.registry) do
          table.insert(uris, uri)
        end
        return uris
      end)
      assert(vim.tbl_contains(uris, 'nvim://session'))
      assert(vim.tbl_contains(uris, 'nvim://buffers'))
    end)
  end)

  describe('nvim://session', function()
    it('returns current buffer with line numbers', function()
      local result = exec_lua(function()
        local resources = require('vim.mcp.resources')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_get_current_buf' then
              return 1
            elseif method == 'nvim_buf_get_name' then
              return 'test.lua'
            elseif method == 'nvim_buf_get_var' then
              return nil, 'Key not found'
            elseif method == 'nvim_buf_get_lines' then
              return { 'line 1', 'line 2', 'line 3' }
            end
          end,
        }
        return resources.read('nvim://session', connection)
      end)

      assert(result.contents ~= nil)
      assert(#result.contents == 1)
      eq('nvim://session', result.contents[1].uri)
      eq('text/plain', result.contents[1].mimeType)
      matches('line 1', result.contents[1].text)
      matches('line 2', result.contents[1].text)
      matches('line 3', result.contents[1].text)
    end)

    it('includes buffer header', function()
      local result = exec_lua(function()
        local resources = require('vim.mcp.resources')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_get_current_buf' then
              return 5
            elseif method == 'nvim_buf_get_name' then
              return 'test.lua'
            elseif method == 'nvim_buf_get_var' then
              return nil, 'Key not found'
            elseif method == 'nvim_buf_get_lines' then
              return { 'content' }
            end
          end,
        }
        return resources.read('nvim://session', connection)
      end)

      matches('Buffer 5: test.lua', result.contents[1].text)
    end)

    it('redacts content for sensitive buffer', function()
      local result = exec_lua(function()
        local resources = require('vim.mcp.resources')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_get_current_buf' then
              return 3
            elseif method == 'nvim_buf_get_name' then
              return 'passwords.txt'
            elseif method == 'nvim_buf_get_var' then
              return true, nil -- mcp_sensitive = true
            elseif method == 'nvim_buf_line_count' then
              return 10
            end
          end,
        }
        return resources.read('nvim://session', connection)
      end)

      assert(result.contents ~= nil)
      matches('redacted', result.contents[1].text)
      matches('passwords.txt', result.contents[1].text)
      assert(not result.contents[1].text:find('secret'))
    end)
  end)

  describe('nvim://buffers', function()
    it('returns buffer list as JSON', function()
      local result = exec_lua(function()
        local resources = require('vim.mcp.resources')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_list_bufs' then
              return { 1, 2, 3 }
            elseif method == 'nvim_buf_is_loaded' then
              return true
            elseif method == 'nvim_buf_get_name' then
              return 'test.lua'
            elseif method == 'nvim_buf_line_count' then
              return 100
            elseif method == 'nvim_buf_get_option' then
              local bufnr, opt = ...
              if opt == 'modified' then
                return false
              elseif opt == 'filetype' then
                return 'lua'
              end
            elseif method == 'nvim_buf_get_var' then
              return nil, 'Key not found'
            end
          end,
        }
        return resources.read('nvim://buffers', connection)
      end)

      assert(result.contents ~= nil)
      assert(#result.contents == 1)
      eq('nvim://buffers', result.contents[1].uri)
      eq('application/json', result.contents[1].mimeType)

      local buffers = vim.json.decode(result.contents[1].text)
      assert(#buffers == 3)
      assert(buffers[1].bufnr ~= nil)
      assert(buffers[1].name ~= nil)
      assert(buffers[1].line_count ~= nil)
      assert(buffers[1].modified ~= nil)
      assert(buffers[1].filetype ~= nil)
    end)

    it('marks sensitive buffers in metadata', function()
      local result = exec_lua(function()
        local resources = require('vim.mcp.resources')
        local connection = {
          call = function(_, method, bufnr, ...)
            if method == 'nvim_list_bufs' then
              return { 1, 2 }
            elseif method == 'nvim_buf_is_loaded' then
              return true
            elseif method == 'nvim_buf_get_name' then
              return bufnr == 1 and 'normal.lua' or 'secret.lua'
            elseif method == 'nvim_buf_line_count' then
              return 5
            elseif method == 'nvim_buf_get_option' then
              return false
            elseif method == 'nvim_buf_get_var' then
              -- buffer 2 is sensitive
              if bufnr == 2 then
                return true, nil
              end
              return nil, 'Key not found'
            end
          end,
        }
        return resources.read('nvim://buffers', connection)
      end)

      local buffers = vim.json.decode(result.contents[1].text)
      assert(#buffers == 2)
      -- find buffer 1 and 2
      local b1, b2
      for _, b in ipairs(buffers) do
        if b.bufnr == 1 then b1 = b end
        if b.bufnr == 2 then b2 = b end
      end
      assert(b1 ~= nil and b1.sensitive == false)
      assert(b2 ~= nil and b2.sensitive == true)
    end)
  end)

  describe('error handling', function()
    it('returns error for unknown resource', function()
      local result, err = exec_lua(function()
        local resources = require('vim.mcp.resources')
        local connection = {}
        return resources.read('nvim://nonexistent', connection)
      end)

      assert(err ~= nil)
      assert(err.code == -32601) -- MethodNotFound
    end)

    it('handles resource read errors', function()
      local result, err = exec_lua(function()
        local resources = require('vim.mcp.resources')
        local connection = {
          call = function(_, method, ...)
            error('Connection error')
          end,
        }
        return resources.read('nvim://session', connection)
      end)

      assert(err ~= nil)
      assert(err.code == -32603) -- InternalError
    end)
  end)
end)
