--- MCP tools registry
---@module 'mcp.tools'

local protocol = require('mcp.protocol')
local log = require('mcp.log')

--- @class Tool
--- @field name string Tool name
--- @field description string Tool description
--- @field inputSchema table JSON Schema for tool input
--- @field handler function Tool handler function

local M = {}

--- Registry of all tools
--- @type table<string, Tool>
M.registry = {}

--- Register a tool
--- @param name string Tool name
--- @param handler function Handler function: function(args, connection) -> result, error
--- @param schema table JSON Schema for input validation
function M.register(name, handler, schema)
  M.registry[name] = {
    name = name,
    description = schema.description or '',
    inputSchema = schema,
    handler = handler,
  }
  log.debug('Registered tool:', name)
end

-- Export module early to prevent circular dependency
package.loaded['mcp.tools'] = M

--- List all registered tools
--- @return table[] List of tool definitions
function M.list()
  local tools = {}
  for _, tool in pairs(M.registry) do
    table.insert(tools, {
      name = tool.name,
      description = tool.description,
      inputSchema = tool.inputSchema,
    })
  end
  return tools
end

--- Call a tool
--- @param name string Tool name
--- @param arguments table Tool arguments
--- @param connection Connection Neovim connection
--- @return table? result Tool result
--- @return table? error Error object
function M.call(name, arguments, connection)
  local tool = M.registry[name]
  if not tool then
    return nil, protocol.method_not_found('Tool: ' .. name)
  end

  -- Validate required fields
  if tool.inputSchema.required then
    for _, field in ipairs(tool.inputSchema.required) do
      if arguments[field] == nil then
        return nil,
          protocol.invalid_params('Missing required field: ' .. field)
      end
    end
  end

  -- Call tool handler with pcall for error handling
  -- Handler returns (result, nil) on success or (nil, McpError) on failure
  local ok, result, handler_err = pcall(tool.handler, arguments, connection)
  if not ok then
    log.error('Tool handler error:', name, result)
    return nil, protocol.internal_error('Tool execution failed: ' .. tostring(result))
  end

  return result, handler_err
end

-- Load all tool modules
require('mcp.tools.buffer')
require('mcp.tools.command')
require('mcp.tools.status')
require('mcp.tools.edit')
require('mcp.tools.window')
require('mcp.tools.file')
require('mcp.tools.mark')
require('mcp.tools.register')
require('mcp.tools.visual')
require('mcp.tools.jump')
require('mcp.tools.search')
require('mcp.tools.grep')
require('mcp.tools.macro')
require('mcp.tools.tab')
require('mcp.tools.fold')
require('mcp.tools.health')
require('mcp.tools.lsp')
require('mcp.tools.quickfix')
require('mcp.tools.undo')
require('mcp.tools.option')

return M
