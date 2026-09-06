--- Mark management MCP tool
---@module 'mcp.tools.mark'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')
local util = require('mcp.tools.util')

--- vim_mark: Set a named mark
tools.register('vim_mark', function(args, connection)
  local mark = args.mark
  local bufnr = args.buffer or 0

  if type(mark) ~= 'string' or #mark ~= 1 then
    return nil, protocol.invalid_params('mark must be a single character (a-z, A-Z)')
  end

  if not mark:match('^[a-zA-Z]$') then
    return nil, protocol.invalid_params('mark must be a letter (a-z or A-Z)')
  end

  local api_line, line_err = util.ui_to_api_line(args.line)
  if line_err then return nil, line_err end

  local col_err = util.validate_integer(args.col, 'col')
  if col_err then return nil, col_err end

  if args.col < 0 then
    return nil, protocol.invalid_params('col must be >= 0')
  end

  -- nvim_buf_set_mark uses 1-indexed line
  local _, err = connection:call('nvim_buf_set_mark', bufnr, mark, api_line + 1, args.col, {})
  if err then
    return nil, protocol.internal_error('Failed to set mark: ' .. err)
  end

  return {
    content = {
      {
        type = 'text',
        text = string.format('Set mark %s at line %d, column %d', mark, args.line, args.col),
      },
    },
  }
end, protocol.ToolSchemas.vim_mark)

return {}
