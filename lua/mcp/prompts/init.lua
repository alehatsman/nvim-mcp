--- MCP prompts registry
---@module 'mcp.prompts'

local protocol = require('mcp.protocol')
local log = require('mcp.log')

--- @class Prompt
--- @field name string Prompt name
--- @field description string Prompt description
--- @field arguments table Prompt arguments schema
--- @field handler function Prompt handler function

local M = {}

--- Registry of all prompts
--- @type table<string, Prompt>
M.registry = {}

--- Register a prompt
--- @param name string Prompt name
--- @param description string Prompt description
--- @param arguments table Arguments schema
--- @param handler function Handler function: function(args, connection) -> messages, error
function M.register(name, description, arguments, handler)
  M.registry[name] = {
    name = name,
    description = description,
    arguments = arguments,
    handler = handler,
  }
  log.debug('Registered prompt:', name)
end

-- Export module early to prevent circular dependency
package.loaded['mcp.prompts'] = M

--- List all registered prompts
--- @return table[] List of prompt definitions
function M.list()
  local prompts = {}
  for _, prompt in pairs(M.registry) do
    table.insert(prompts, {
      name = prompt.name,
      description = prompt.description,
      arguments = prompt.arguments,
    })
  end
  return prompts
end

--- Get a prompt
--- @param name string Prompt name
--- @param arguments table Prompt arguments
--- @param connection Connection Neovim connection
--- @return table? result Prompt messages
--- @return table? error Error object
function M.get(name, arguments, connection)
  local prompt = M.registry[name]
  if not prompt then
    return nil, protocol.method_not_found('Prompt: ' .. name)
  end

  -- Call prompt handler with pcall for error handling
  -- Handler returns (result, nil) on success or (nil, McpError) on failure
  local ok, result, handler_err = pcall(prompt.handler, arguments, connection)
  if not ok then
    log.error('Prompt handler error:', name, result)
    return nil, protocol.internal_error('Prompt get failed: ' .. tostring(result))
  end

  return result, handler_err
end

-- Load all prompt modules
require('mcp.prompts.workflow')

return M
