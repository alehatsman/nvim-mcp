--- Project-wide grep MCP tool
---@module 'mcp.tools.grep'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_grep: Project-wide grep with quickfix
tools.register('vim_grep', function(args, connection)
  local pattern = args.pattern
  local files = args.files or '**/*'

  -- Execute vimgrep (escape / to prevent delimiter injection)
  local escaped_pattern = pattern:gsub('/', '\\/')
  local cmd = string.format('silent! vimgrep /%s/gj %s', escaped_pattern, files)
  local _, err = connection:call('nvim_command', cmd)
  if err then
    return nil, protocol.internal_error('Failed to execute vimgrep: ' .. err)
  end

  -- Get quickfix list
  local qflist, qf_err = connection:exec_lua([[
    local qflist = vim.fn.getqflist()
    if #qflist == 0 then
      return 'No matches found'
    end

    local results = {}
    for i, item in ipairs(qflist) do
      local bufname = vim.fn.bufname(item.bufnr)
      local sensitive = vim.fn.getbufvar(item.bufnr, 'mcp_sensitive', false)
      local text = sensitive and '[Content redacted: buffer is marked sensitive]' or (item.text or '')
      table.insert(results, string.format('%s:%d:%d: %s',
        bufname, item.lnum, item.col, text))
    end

    return table.concat(results, '\n')
  ]], {})

  if qf_err then
    return nil, protocol.internal_error('Failed to get quickfix list: ' .. qf_err)
  end

  return {
    content = {
      {
        type = 'text',
        text = string.format('Grep results for "%s":\n\n%s', pattern, qflist),
      },
    },
  }
end, protocol.ToolSchemas.vim_grep)

return {}
