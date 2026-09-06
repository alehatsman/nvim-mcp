--- MCP logging utilities
---@module 'mcp.log'

local M = {}

--- Log levels
M.levels = {
  TRACE = 0,
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

--- Current log level
M.level = M.levels.INFO

--- Log file path (nil = stderr)
M.log_file = nil

--- Format and write log message
--- @param level number Log level
--- @param level_name string Level name
--- @param ... any Log message parts
local function log(level, level_name, ...)
  if level < M.level then
    return
  end

  local msg = table.concat(vim.tbl_map(tostring, { ... }), ' ')
  local timestamp = os.date('%Y-%m-%d %H:%M:%S')
  local formatted = string.format('[%s] [%s] %s\n', timestamp, level_name, msg)

  if M.log_file then
    local f = io.open(M.log_file, 'a')
    if f then
      f:write(formatted)
      f:close()
    end
  else
    io.stderr:write(formatted)
  end
end

--- Log trace message
--- @param ... any Message parts
function M.trace(...)
  log(M.levels.TRACE, 'TRACE', ...)
end

--- Log debug message
--- @param ... any Message parts
function M.debug(...)
  log(M.levels.DEBUG, 'DEBUG', ...)
end

--- Log info message
--- @param ... any Message parts
function M.info(...)
  log(M.levels.INFO, 'INFO', ...)
end

--- Log warning message
--- @param ... any Message parts
function M.warn(...)
  log(M.levels.WARN, 'WARN', ...)
end

--- Log error message
--- @param ... any Message parts
function M.error(...)
  log(M.levels.ERROR, 'ERROR', ...)
end

return M
