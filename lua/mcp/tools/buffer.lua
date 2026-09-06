--- Buffer-related MCP tools
---@module 'mcp.tools.buffer'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')
local util = require('mcp.tools.util')

--- vim_buffer: Get buffer contents with line numbers
tools.register('vim_buffer', function(args, connection)
  local bufnr = args.buffer or 0

  -- Sensitive buffer: deny content, return metadata only
  if util.is_sensitive(connection, bufnr) then
    local name, _ = connection:call('nvim_buf_get_name', bufnr)
    local line_count, _ = connection:call('nvim_buf_line_count', bufnr)
    return {
      content = {
        {
          type = 'text',
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

  local lines, err = connection:call('nvim_buf_get_lines', bufnr, 0, -1, false)
  if err then
    return nil, protocol.internal_error('Failed to get buffer lines: ' .. err)
  end

  local name, _ = connection:call('nvim_buf_get_name', bufnr)

  local numbered_lines = {}
  for i, line in ipairs(lines) do
    table.insert(numbered_lines, string.format('%4d  %s', i, line))
  end

  local content = table.concat(numbered_lines, '\n')
  if #content == 0 then
    content = '[Empty buffer]'
  end

  return {
    content = {
      {
        type = 'text',
        text = string.format('Buffer %d: %s\n\n%s', bufnr, name or '[No Name]', content),
      },
    },
  }
end, protocol.ToolSchemas.vim_buffer)

--- vim_buffer_switch: Switch to a different buffer
tools.register('vim_buffer_switch', function(args, connection)
  if args.buffer then
    local val_err = util.validate_integer(args.buffer, 'buffer')
    if val_err then return nil, val_err end

    local _, err = connection:call('nvim_set_current_buf', args.buffer)
    if err then
      return nil, protocol.internal_error('Failed to switch buffer: ' .. err)
    end
    return {
      content = {
        { type = 'text', text = string.format('Switched to buffer %d', args.buffer) },
      },
    }
  end

  if args.filename then
    local buffers, list_err = connection:call('nvim_list_bufs')
    if list_err then
      return nil, protocol.internal_error('Failed to list buffers: ' .. list_err)
    end

    for _, bufnr in ipairs(buffers) do
      local loaded, _ = connection:call('nvim_buf_is_loaded', bufnr)
      if loaded then
        local name, _ = connection:call('nvim_buf_get_name', bufnr)
        if name and name:find(args.filename, 1, true) then
          local _, switch_err = connection:call('nvim_set_current_buf', bufnr)
          if switch_err then
            return nil, protocol.internal_error('Failed to switch buffer: ' .. switch_err)
          end
          return {
            content = {
              {
                type = 'text',
                text = string.format('Switched to buffer %d: %s', bufnr, name),
              },
            },
          }
        end
      end
    end

    return nil, protocol.invalid_params('No buffer found matching: ' .. args.filename)
  end

  return nil, protocol.invalid_params('Must specify either buffer number or filename')
end, protocol.ToolSchemas.vim_buffer_switch)

--- vim_buffer_save: Save buffer to disk
tools.register('vim_buffer_save', function(args, connection)
  local bufnr = args.buffer or 0

  local name, name_err = connection:call('nvim_buf_get_name', bufnr)
  if name_err or not name or name == '' then
    return nil, protocol.invalid_params('Buffer has no filename (use :saveas to set one)')
  end

  -- nvim_buf_call takes a Lua function, which can't cross the RPC boundary
  -- to the connected Neovim process (msgpack has no function type). Ship
  -- the closure as Lua source instead; it's only ever built and called
  -- inside the remote process, so no function value is ever serialized.
  local _, err = connection:call(
    'nvim_exec_lua',
    'local bufnr = ... vim.api.nvim_buf_call(bufnr, function() vim.cmd("write") end)',
    { bufnr }
  )

  if err then
    return nil, protocol.internal_error('Failed to save buffer: ' .. err)
  end

  return {
    content = {
      { type = 'text', text = string.format('Saved buffer %d: %s', bufnr, name) },
    },
  }
end, protocol.ToolSchemas.vim_buffer_save)

return {}
