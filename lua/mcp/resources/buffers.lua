--- Buffer list resource
---@module 'mcp.resources.buffers'

local resources = require('mcp.resources')
local protocol = require('mcp.protocol')
local util = require('mcp.tools.util')

--- nvim://buffers: List all open buffers with metadata
resources.register(
  'nvim://buffers',
  'Buffer List',
  'List all open buffers with metadata',
  'application/json',
  function(connection)
    local buffers, err = connection:call('nvim_list_bufs')
    if err then
      return nil, protocol.internal_error('Failed to list buffers: ' .. err)
    end

    local buffer_list = {}
    for _, bufnr in ipairs(buffers) do
      local loaded, _ = connection:call('nvim_buf_is_loaded', bufnr)
      if loaded then
        local name, _ = connection:call('nvim_buf_get_name', bufnr)
        local line_count, _ = connection:call('nvim_buf_line_count', bufnr)
        local modified, _ = connection:call('nvim_get_option_value', 'modified', { buf = bufnr })
        local filetype, _ = connection:call('nvim_get_option_value', 'filetype', { buf = bufnr })
        local sensitive = util.is_sensitive(connection, bufnr)

        table.insert(buffer_list, {
          bufnr = bufnr,
          name = name or '[No Name]',
          line_count = line_count or 0,
          modified = modified or false,
          filetype = filetype or '',
          sensitive = sensitive,
        })
      end
    end

    local json = vim.json.encode(buffer_list)

    return {
      contents = {
        {
          uri = 'nvim://buffers',
          mimeType = 'application/json',
          text = json,
        },
      },
    }
  end
)

return {}
