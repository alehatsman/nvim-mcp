--- MCP resources registry
---@module 'mcp.resources'

local protocol = require('mcp.protocol')
local log = require('mcp.log')

--- @class Resource
--- @field uri string Resource URI
--- @field name string Resource name
--- @field description string Resource description
--- @field mimeType string MIME type
--- @field handler function Resource handler function

local M = {}

--- Registry of all resources
--- @type table<string, Resource>
M.registry = {}

--- Register a resource
--- @param uri string Resource URI
--- @param name string Resource name
--- @param description string Resource description
--- @param mimeType string MIME type
--- @param handler function Handler function: function(connection) -> contents, error
function M.register(uri, name, description, mimeType, handler)
  M.registry[uri] = {
    uri = uri,
    name = name,
    description = description,
    mimeType = mimeType,
    handler = handler,
  }
  log.debug('Registered resource:', uri)
end

-- Export module early to prevent circular dependency
package.loaded['mcp.resources'] = M

--- List all registered resources
--- @return table[] List of resource definitions
function M.list()
  local resources = {}
  for _, resource in pairs(M.registry) do
    table.insert(resources, {
      uri = resource.uri,
      name = resource.name,
      description = resource.description,
      mimeType = resource.mimeType,
    })
  end
  return resources
end

--- Read a resource
--- @param uri string Resource URI
--- @param connection Connection Neovim connection
--- @return table? result Resource contents
--- @return table? error Error object
function M.read(uri, connection)
  local resource = M.registry[uri]
  if not resource then
    return nil, protocol.method_not_found('Resource: ' .. uri)
  end

  -- Call resource handler with pcall for error handling
  -- Handler returns (result, nil) on success or (nil, McpError) on failure
  local ok, result, handler_err = pcall(resource.handler, connection)
  if not ok then
    log.error('Resource handler error:', uri, result)
    return nil, protocol.internal_error('Resource read failed: ' .. tostring(result))
  end

  return result, handler_err
end

-- Load all resource modules
require('mcp.resources.session')
require('mcp.resources.buffers')

return M
