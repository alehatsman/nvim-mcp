--- Visual selection MCP tool
---@module 'mcp.tools.visual'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')
local util = require('mcp.tools.util')

local VALID_MODES = { 'v', 'V', 'ctrl-v' }
local MODE_KEYS = { v = 'v', V = 'V', ['ctrl-v'] = '\x16' }
local MODE_NAMES = { v = 'character', V = 'line', ['\x16'] = 'block' }

--- vim_visual: Create visual selection
tools.register('vim_visual', function(args, connection)
  local mode = args.mode
  local bufnr = args.buffer or 0

  local mode_err = util.validate_enum(mode, VALID_MODES, 'mode')
  if mode_err then return nil, mode_err end

  local api_start, start_err = util.ui_to_api_line(args.start_line)
  if start_err then return nil, start_err end

  local api_end, end_err = util.ui_to_api_line(args.end_line)
  if end_err then return nil, end_err end

  local sc_err = util.validate_integer(args.start_col, 'start_col')
  if sc_err then return nil, sc_err end

  local ec_err = util.validate_integer(args.end_col, 'end_col')
  if ec_err then return nil, ec_err end

  if args.start_col < 1 or args.end_col < 1 then
    return nil, protocol.invalid_params('start_col and end_col must be >= 1')
  end

  local mode_key = MODE_KEYS[mode]
  -- Convert 1-indexed cols to 0-indexed
  local nvim_start_col = args.start_col - 1
  local nvim_end_col = args.end_col - 1

  local _, err = connection:exec_lua(
    [[
    local bufnr, mode, start_line, start_col, end_line, end_col = ...
    vim.api.nvim_buf_set_mark(bufnr, '<', start_line + 1, start_col, {})
    vim.api.nvim_buf_set_mark(bufnr, '>', end_line + 1, end_col, {})
    vim.api.nvim_input(mode)
    vim.api.nvim_input('`<o`>')
  ]],
    { bufnr, mode_key, api_start, nvim_start_col, api_end, nvim_end_col }
  )

  if err then
    return nil, protocol.internal_error('Failed to create visual selection: ' .. err)
  end

  return {
    content = {
      {
        type = 'text',
        text = string.format(
          'Created %s visual selection from (%d,%d) to (%d,%d)',
          MODE_NAMES[mode_key] or 'unknown',
          args.start_line,
          args.start_col,
          args.end_line,
          args.end_col
        ),
      },
    },
  }
end, protocol.ToolSchemas.vim_visual)

return {}
