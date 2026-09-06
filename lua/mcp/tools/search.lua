--- Search and replace MCP tools
---@module 'mcp.tools.search'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- vim_search: Search for a pattern
tools.register('vim_search', function(args, connection)
  local pattern = args.pattern
  local ignoreCase = args.ignoreCase
  local wholeWord = args.wholeWord

  -- Build search pattern
  local search_pattern = pattern

  if wholeWord then
    search_pattern = '\\<' .. pattern .. '\\>'
  end

  -- Build search flags
  local flags = ''
  if ignoreCase then
    flags = '\\c' -- Case insensitive
  end

  -- Execute search
  local cmd = '/' .. flags .. search_pattern
  local _, err = connection:call('nvim_input', cmd .. '\r')
  if err then
    return nil, protocol.internal_error('Failed to execute search: ' .. err)
  end

  return {
    content = {
      {
        type = 'text',
        text = string.format('Searching for: %s', search_pattern),
      },
    },
  }
end, protocol.ToolSchemas.vim_search)

--- vim_search_replace: Find and replace text
tools.register('vim_search_replace', function(args, connection)
  local pattern = args.pattern
  local replacement = args.replacement
  local global = args.global
  local ignoreCase = args.ignoreCase
  local confirm = args.confirm

  -- Build flags
  local flags = ''
  if global then
    flags = flags .. 'g'
  end
  if ignoreCase then
    flags = flags .. 'i'
  end
  if confirm then
    flags = flags .. 'c'
  end

  -- Escape pattern and replacement (\ must be escaped first)
  local escaped_pattern = pattern:gsub('\\', '\\\\'):gsub('/', '\\/')
  local escaped_replacement = replacement:gsub('\\', '\\\\'):gsub('&', '\\&'):gsub('~', '\\~'):gsub('/', '\\/')

  -- Execute substitution
  local cmd = string.format('%%s/%s/%s/%s', escaped_pattern, escaped_replacement, flags)
  local result, err = connection:call('nvim_exec2', cmd, { output = true })
  if err then
    return nil, protocol.internal_error('Failed to execute substitution: ' .. err)
  end

  local output = result.output or 'Substitution complete'

  return {
    content = {
      { type = 'text', text = output },
    },
  }
end, protocol.ToolSchemas.vim_search_replace)

return {}
