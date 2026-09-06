--- Buffer editing MCP tool
---@module 'mcp.tools.edit'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')
local util = require('mcp.tools.util')

local VALID_OPERATIONS = { 'insert', 'replace', 'replaceAll' }

--- vim_edit: Edit buffer content
tools.register('vim_edit', function(args, connection)
  local bufnr = args.buffer or 0
  local operation = args.operation
  local text = args.text

  local op_err = util.validate_enum(operation, VALID_OPERATIONS, 'operation')
  if op_err then return nil, op_err end

  if type(text) ~= 'string' then
    return nil, protocol.invalid_params('text is required and must be a string')
  end

  if operation == 'insert' then
    if args.line == nil then
      return nil, protocol.invalid_params('line is required for insert operation')
    end
    local api_line, line_err = util.ui_to_api_line(args.line)
    if line_err then return nil, line_err end

    local lines = vim.split(text, '\n', { plain = true })
    local _, err = connection:call('nvim_buf_set_lines', bufnr, api_line, api_line, false, lines)
    if err then
      return nil, protocol.internal_error('Failed to insert text: ' .. err)
    end

    return {
      content = {
        {
          type = 'text',
          text = string.format('Inserted %d line(s) at line %d', #lines, args.line),
        },
      },
    }

  elseif operation == 'replace' then
    if args.start_line == nil or args.end_line == nil then
      return nil,
        protocol.invalid_params('start_line and end_line are required for replace operation')
    end
    local api_start, api_end, range_err = util.validate_line_range(args.start_line, args.end_line)
    if range_err then return nil, range_err end

    local lines = vim.split(text, '\n', { plain = true })
    local _, err = connection:call('nvim_buf_set_lines', bufnr, api_start, api_end, false, lines)
    if err then
      return nil, protocol.internal_error('Failed to replace text: ' .. err)
    end

    return {
      content = {
        {
          type = 'text',
          text = string.format(
            'Replaced lines %d-%d with %d line(s)',
            args.start_line,
            args.end_line,
            #lines
          ),
        },
      },
    }

  else -- replaceAll
    local lines = vim.split(text, '\n', { plain = true })
    local _, err = connection:call('nvim_buf_set_lines', bufnr, 0, -1, false, lines)
    if err then
      return nil, protocol.internal_error('Failed to replace buffer: ' .. err)
    end

    return {
      content = {
        {
          type = 'text',
          text = string.format('Replaced entire buffer with %d line(s)', #lines),
        },
      },
    }
  end
end, protocol.ToolSchemas.vim_edit)

return {}
