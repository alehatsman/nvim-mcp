--- Current session resource
---@module 'mcp.resources.session'

local resources = require('mcp.resources')
local protocol = require('mcp.protocol')
local util = require('mcp.tools.util')

--- nvim://session: Current buffer contents with line numbers
resources.register(
  'nvim://session',
  'Current Neovim Session',
  'Current buffer contents with line numbers',
  'text/plain',
  function(connection)
    local bufnr, err = connection:call('nvim_get_current_buf')
    if err then
      return nil, protocol.internal_error('Failed to get current buffer: ' .. err)
    end

    local name, _ = connection:call('nvim_buf_get_name', bufnr)

    -- Sensitive buffer: return metadata only
    if util.is_sensitive(connection, bufnr) then
      local line_count, _ = connection:call('nvim_buf_line_count', bufnr)
      return {
        contents = {
          {
            uri = 'nvim://session',
            mimeType = 'text/plain',
            text = string.format(
              'Buffer %d: %s\n[Content redacted: buffer is marked sensitive]\nLines: %d',
              bufnr,
              name or '[No Name]',
              line_count or 0
            ),
          },
        },
      }
    end

    local lines, lines_err = connection:call('nvim_buf_get_lines', bufnr, 0, -1, false)
    if lines_err then
      return nil, protocol.internal_error('Failed to get buffer lines: ' .. lines_err)
    end

    local numbered_lines = {}
    for i, line in ipairs(lines) do
      table.insert(numbered_lines, string.format('%4d  %s', i, line))
    end

    local content = table.concat(numbered_lines, '\n')
    if #content == 0 then
      content = '[Empty buffer]'
    end

    local header = string.format('Buffer %d: %s\n\n', bufnr, name or '[No Name]')

    return {
      contents = {
        {
          uri = 'nvim://session',
          mimeType = 'text/plain',
          text = header .. content,
        },
      },
    }
  end
)

return {}
