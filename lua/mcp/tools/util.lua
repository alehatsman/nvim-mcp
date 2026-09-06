--- Shared utilities for the MCP tool layer
--- @module mcp.tools.util

local protocol = require('mcp.protocol')

local M = {}

--- Convert 1-indexed UI line to 0-indexed Neovim API line.
--- Returns nil, McpError on invalid input.
function M.ui_to_api_line(line)
  if type(line) ~= 'number' or line ~= math.floor(line) then
    return nil, protocol.invalid_params('line must be an integer')
  end
  if line < 1 then
    return nil, protocol.invalid_params('line must be >= 1')
  end
  return line - 1, nil
end

--- Validate a 1-indexed inclusive line range.
--- Returns api_start (0-indexed inclusive), api_end (0-indexed exclusive), nil on success.
--- Returns nil, nil, McpError on failure.
function M.validate_line_range(start_line, end_line)
  if type(start_line) ~= 'number' or start_line ~= math.floor(start_line) then
    return nil, nil, protocol.invalid_params('start_line must be an integer')
  end
  if type(end_line) ~= 'number' or end_line ~= math.floor(end_line) then
    return nil, nil, protocol.invalid_params('end_line must be an integer')
  end
  if start_line < 1 then
    return nil, nil, protocol.invalid_params('start_line must be >= 1')
  end
  if end_line < start_line then
    return nil, nil, protocol.invalid_params('end_line must be >= start_line')
  end
  -- nvim_buf_set_lines: start is 0-indexed inclusive, end is 0-indexed exclusive
  return start_line - 1, end_line, nil
end

--- Validate that value is one of the allowed values.
--- Returns McpError or nil.
function M.validate_enum(value, allowed, name)
  for _, v in ipairs(allowed) do
    if value == v then
      return nil
    end
  end
  return protocol.invalid_params(
    string.format('%s must be one of: %s', name, table.concat(allowed, ', '))
  )
end

--- Validate that value is an integer.
--- Returns McpError or nil.
function M.validate_integer(value, name)
  if type(value) ~= 'number' or value ~= math.floor(value) then
    return protocol.invalid_params(name .. ' must be an integer')
  end
  return nil
end

--- Check if a buffer is marked sensitive (b:mcp_sensitive == true).
--- Returns true only if the variable is explicitly set to true.
function M.is_sensitive(connection, bufnr)
  local val, err = connection:call('nvim_buf_get_var', bufnr, 'mcp_sensitive')
  return err == nil and val == true
end

return M
