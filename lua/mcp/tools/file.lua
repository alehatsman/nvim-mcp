--- File operations MCP tool
---@module 'mcp.tools.file'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_file_open: Open a file in a new buffer
tools.register('vim_file_open', function(args, connection)
  local filename = args.filename

  if not filename or filename == '' then
    return nil, protocol.invalid_params('filename cannot be empty')
  end

  if filename:find('..', 1, true) then
    return nil, protocol.invalid_params('Path traversal is not allowed')
  end

  -- Open file with :edit command
  local _, err = connection:call('nvim_command', 'edit ' .. vim.fn.fnameescape(filename))
  if err then
    return nil, protocol.internal_error('Failed to open file: ' .. err)
  end

  -- Get the new buffer number
  local bufnr, bufnr_err = connection:call('nvim_get_current_buf')
  if bufnr_err then
    return {
      content = {
        { type = 'text', text = string.format('Opened file: %s', filename) },
      },
    }
  end

  return {
    content = {
      {
        type = 'text',
        text = string.format('Opened file: %s (buffer %d)', filename, bufnr),
      },
    },
  }
end, protocol.ToolSchemas.vim_file_open)

return {}
