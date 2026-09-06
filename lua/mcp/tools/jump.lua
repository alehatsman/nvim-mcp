--- Jump list navigation MCP tool
---@module 'mcp.tools.jump'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_jump: Navigate jump list
tools.register('vim_jump', function(args, connection)
  local action = args.action

  if action == 'back' then
    -- Jump back (Ctrl-O)
    local _, err = connection:call('nvim_input', '\x0f') -- Ctrl-O
    if err then
      return nil, protocol.internal_error('Failed to jump back: ' .. err)
    end
    return {
      content = {
        { type = 'text', text = 'Jumped back in jump list' },
      },
    }
  elseif action == 'forward' then
    -- Jump forward (Ctrl-I / Tab)
    local _, err = connection:call('nvim_input', '\t') -- Ctrl-I (Tab)
    if err then
      return nil, protocol.internal_error('Failed to jump forward: ' .. err)
    end
    return {
      content = {
        { type = 'text', text = 'Jumped forward in jump list' },
      },
    }
  elseif action == 'list' then
    -- Get jump list
    local jumplist, err = connection:exec_lua([[
      local jumplist, current_idx = unpack(vim.fn.getjumplist())
      local result = {}
      for i, jump in ipairs(jumplist) do
        local marker = (i == current_idx + 1) and '>' or ' '
        table.insert(result, string.format('%s %3d  %4d  %s',
          marker, i, jump.lnum, jump.bufnr and vim.fn.bufname(jump.bufnr) or ''))
      end
      return table.concat(result, '\n')
    ]], {})

    if err then
      return nil, protocol.internal_error('Failed to get jump list: ' .. err)
    end

    return {
      content = {
        {
          type = 'text',
          text = string.format('Jump list:\n%s', jumplist or '[Empty]'),
        },
      },
    }
  else
    return nil,
      protocol.invalid_params('Invalid action: ' .. action .. ' (must be back, forward, or list)')
  end
end, protocol.ToolSchemas.vim_jump)

return {}
