--- MCP (Model Context Protocol) protocol constants and schemas
---@module 'mcp.protocol'

local M = {}

--- MCP Protocol version
M.PROTOCOL_VERSION = '2025-11-25'

--- Supported protocol versions, newest first
M.SUPPORTED_VERSIONS = { '2025-11-25', '2024-11-05' }
--- @type table<string,boolean>
M.SUPPORTED_VERSIONS_SET = { ['2025-11-25'] = true, ['2024-11-05'] = true }

--- MCP Message types
M.MessageType = {
  Initialize = 'initialize',
  --- Notification sent by the client after a successful initialize exchange
  Initialized = 'notifications/initialized',
  Ping = 'ping',
  ListTools = 'tools/list',
  CallTool = 'tools/call',
  ListResources = 'resources/list',
  ReadResource = 'resources/read',
  SubscribeResource = 'resources/subscribe',
  UnsubscribeResource = 'resources/unsubscribe',
  ListPrompts = 'prompts/list',
  GetPrompt = 'prompts/get',
}

--- JSON-RPC 2.0 Error codes
M.ErrorCodes = {
  ParseError = -32700,
  InvalidRequest = -32600,
  MethodNotFound = -32601,
  InvalidParams = -32602,
  InternalError = -32603,
}

--- MCP Error class
--- @class McpError
--- @field code number Error code
--- @field message string Error message
--- @field data? any Additional error data
M.McpError = {}
M.McpError.__index = M.McpError

--- Create a new MCP error
--- @param code number Error code
--- @param message string Error message
--- @param data? any Additional error data
--- @return McpError
function M.McpError.new(code, message, data)
  return setmetatable({
    code = code,
    message = message,
    data = data,
  }, M.McpError)
end

function M.McpError:__tostring()
  return string.format('MCP Error [%d]: %s', self.code, self.message)
end

--- Create invalid params error
--- @param message string Error message
--- @param data? any Additional error data
--- @return McpError
function M.invalid_params(message, data)
  return M.McpError.new(M.ErrorCodes.InvalidParams, message, data)
end

--- Create method not found error
--- @param method string Method name
--- @return McpError
function M.method_not_found(method)
  return M.McpError.new(M.ErrorCodes.MethodNotFound, 'Method not found: ' .. method)
end

--- Create internal error
--- @param message string Error message
--- @param data? any Additional error data
--- @return McpError
function M.internal_error(message, data)
  return M.McpError.new(M.ErrorCodes.InternalError, message, data)
end

--- Tool input schemas (JSON Schema format)
M.ToolSchemas = {
  vim_buffer = {
    type = 'object',
    description = 'Get buffer contents with line numbers',
    properties = {
      buffer = {
        type = 'number',
        description = 'Buffer number (0 for current, omit for current)',
      },
    },
  },
  vim_command = {
    type = 'object',
    required = { 'command' },
    description = 'Execute a Vim command. Requires MCP_ALLOW_COMMANDS=1. Disabled by default.',
    properties = {
      command = {
        type = 'string',
        description = 'Vim command to execute (ex-command without leading colon)',
      },
    },
  },
  vim_status = {
    type = 'object',
    description = 'Get current Neovim session status including cursor position, mode, LSP clients, and plugins',
    properties = {
      buffer = {
        type = 'number',
        description = 'Buffer number (0 or omit for current)',
      },
    },
  },
  vim_edit = {
    type = 'object',
    required = { 'operation', 'text' },
    description = 'Edit buffer content with insert, replace, or replaceAll operations',
    properties = {
      buffer = {
        type = 'number',
        description = 'Buffer number (0 or omit for current)',
      },
      operation = {
        type = 'string',
        enum = { 'insert', 'replace', 'replaceAll' },
        description = 'Edit operation: insert (at line), replace (range), or replaceAll (entire buffer)',
      },
      line = {
        type = 'number',
        description = 'Line number for insert operation (1-indexed)',
      },
      start_line = {
        type = 'number',
        description = 'Start line for replace operation (1-indexed, inclusive)',
      },
      end_line = {
        type = 'number',
        description = 'End line for replace operation (1-indexed, inclusive)',
      },
      text = {
        type = 'string',
        description = 'Text content to insert or replace',
      },
    },
  },
  vim_window = {
    type = 'object',
    required = { 'action' },
    description = 'Manage windows: split, vsplit, close, or navigate',
    properties = {
      action = {
        type = 'string',
        enum = { 'split', 'vsplit', 'close', 'navigate' },
        description = 'Window action to perform',
      },
      direction = {
        type = 'string',
        enum = { 'h', 'j', 'k', 'l' },
        description = 'Direction for navigate action (h=left, j=down, k=up, l=right)',
      },
    },
  },
  vim_file_open = {
    type = 'object',
    required = { 'filename' },
    description = 'Open a file in a new buffer',
    properties = {
      filename = {
        type = 'string',
        description = 'Path to file to open',
      },
    },
  },
  vim_buffer_switch = {
    type = 'object',
    description = 'Switch to a different buffer by number or filename',
    properties = {
      buffer = {
        type = 'number',
        description = 'Buffer number to switch to',
      },
      filename = {
        type = 'string',
        description = 'Filename pattern to match (if buffer not specified)',
      },
    },
  },
  vim_buffer_save = {
    type = 'object',
    description = 'Save current or specific buffer',
    properties = {
      buffer = {
        type = 'number',
        description = 'Buffer number (0 or omit for current)',
      },
    },
  },
  vim_mark = {
    type = 'object',
    required = { 'mark', 'line', 'col' },
    description = 'Set a named mark at a specific position',
    properties = {
      mark = {
        type = 'string',
        description = 'Mark name (a-z for buffer-local, A-Z for global)',
      },
      line = {
        type = 'number',
        description = 'Line number (1-indexed)',
      },
      col = {
        type = 'number',
        description = 'Column number (0-indexed)',
      },
      buffer = {
        type = 'number',
        description = 'Buffer number (0 or omit for current)',
      },
    },
  },
  vim_register = {
    type = 'object',
    required = { 'register', 'content' },
    description = 'Set register contents',
    properties = {
      register = {
        type = 'string',
        description = 'Register name (a-z, A-Z, 0-9, -, *, +, etc.)',
      },
      content = {
        type = 'string',
        description = 'Content to store in register',
      },
    },
  },
  vim_visual = {
    type = 'object',
    required = { 'mode', 'start_line', 'start_col', 'end_line', 'end_col' },
    description = 'Create a visual selection (character, line, or block mode)',
    properties = {
      mode = {
        type = 'string',
        enum = { 'v', 'V', 'ctrl-v' },
        description = 'Visual mode: v (character), V (line), ctrl-v (block)',
      },
      start_line = {
        type = 'number',
        description = 'Start line (1-indexed)',
      },
      start_col = {
        type = 'number',
        description = 'Start column (1-indexed)',
      },
      end_line = {
        type = 'number',
        description = 'End line (1-indexed)',
      },
      end_col = {
        type = 'number',
        description = 'End column (1-indexed)',
      },
      buffer = {
        type = 'number',
        description = 'Buffer number (0 or omit for current)',
      },
    },
  },
  vim_jump = {
    type = 'object',
    required = { 'action' },
    description = 'Navigate jump list: back, forward, or list jumps',
    properties = {
      action = {
        type = 'string',
        enum = { 'back', 'forward', 'list' },
        description = 'Jump action: back (<C-o>), forward (<C-i>), or list (show jump list)',
      },
    },
  },
  vim_search = {
    type = 'object',
    required = { 'pattern' },
    description = 'Search for a pattern in the buffer',
    properties = {
      pattern = {
        type = 'string',
        description = 'Search pattern (Vim regex)',
      },
      ignoreCase = {
        type = 'boolean',
        description = 'Case-insensitive search',
      },
      wholeWord = {
        type = 'boolean',
        description = 'Match whole words only',
      },
    },
  },
  vim_search_replace = {
    type = 'object',
    required = { 'pattern', 'replacement' },
    description = 'Find and replace text in buffer',
    properties = {
      pattern = {
        type = 'string',
        description = 'Search pattern (Vim regex)',
      },
      replacement = {
        type = 'string',
        description = 'Replacement text',
      },
      global = {
        type = 'boolean',
        description = 'Replace all occurrences on each line (g flag)',
      },
      ignoreCase = {
        type = 'boolean',
        description = 'Case-insensitive search (i flag)',
      },
      confirm = {
        type = 'boolean',
        description = 'Confirm each substitution (c flag)',
      },
    },
  },
  vim_grep = {
    type = 'object',
    required = { 'pattern' },
    description = 'Search for pattern across project files using vimgrep',
    properties = {
      pattern = {
        type = 'string',
        description = 'Search pattern (Vim regex)',
      },
      files = {
        type = 'string',
        description = 'File pattern (default: **/*)',
      },
    },
  },
  vim_macro = {
    type = 'object',
    required = { 'action' },
    description = 'Record, stop, or play macros',
    properties = {
      action = {
        type = 'string',
        enum = { 'record', 'stop', 'play' },
        description = 'Macro action: record (start recording), stop (stop recording), play (execute)',
      },
      register = {
        type = 'string',
        description = 'Register to use for macro (a-z, required for record/play)',
      },
    },
  },
  vim_tab = {
    type = 'object',
    required = { 'action' },
    description = 'Manage tabs: create, close, navigate, or list',
    properties = {
      action = {
        type = 'string',
        enum = { 'new', 'close', 'next', 'prev', 'first', 'last', 'list' },
        description = 'Tab action to perform',
      },
    },
  },
  vim_fold = {
    type = 'object',
    required = { 'action' },
    description = 'Manage code folds',
    properties = {
      action = {
        type = 'string',
        enum = { 'create', 'open', 'close', 'toggle', 'openall', 'closeall', 'delete' },
        description = 'Fold action to perform',
      },
      start_line = {
        type = 'number',
        description = 'Start line for create action (1-indexed)',
      },
      end_line = {
        type = 'number',
        description = 'End line for create action (1-indexed)',
      },
    },
  },
  vim_health = {
    type = 'object',
    description = 'Check MCP server connection health',
    properties = vim.empty_dict(),
  },
  vim_lsp_diagnostics = {
    type = 'object',
    description = 'Get LSP diagnostics for a buffer',
    properties = {
      buffer = {
        type = 'number',
        description = 'Buffer number (0 or omit for current)',
      },
      severity = {
        type = 'string',
        enum = { 'ERROR', 'WARN', 'INFO', 'HINT' },
        description = 'Filter by severity level',
      },
    },
  },
  vim_lsp_hover = {
    type = 'object',
    required = { 'line', 'col' },
    description = 'Get LSP hover information at a position',
    properties = {
      line = { type = 'number', description = 'Line number (1-indexed)' },
      col = { type = 'number', description = 'Column number (0-indexed)' },
      buffer = { type = 'number', description = 'Buffer number (0 or omit for current)' },
    },
  },
  vim_lsp_definition = {
    type = 'object',
    required = { 'line', 'col' },
    description = 'Go to LSP definition of symbol at position',
    properties = {
      line = { type = 'number', description = 'Line number (1-indexed)' },
      col = { type = 'number', description = 'Column number (0-indexed)' },
      buffer = { type = 'number', description = 'Buffer number (0 or omit for current)' },
    },
  },
  vim_lsp_references = {
    type = 'object',
    required = { 'line', 'col' },
    description = 'Find all LSP references for symbol at position',
    properties = {
      line = { type = 'number', description = 'Line number (1-indexed)' },
      col = { type = 'number', description = 'Column number (0-indexed)' },
      buffer = { type = 'number', description = 'Buffer number (0 or omit for current)' },
      include_declaration = {
        type = 'boolean',
        description = 'Include declaration in results (default: false)',
      },
    },
  },
  vim_lsp_rename = {
    type = 'object',
    required = { 'line', 'col', 'new_name' },
    description = 'Rename symbol at position using LSP',
    properties = {
      line = { type = 'number', description = 'Line number (1-indexed)' },
      col = { type = 'number', description = 'Column number (0-indexed)' },
      new_name = { type = 'string', description = 'New name for the symbol' },
      buffer = { type = 'number', description = 'Buffer number (0 or omit for current)' },
    },
  },
  vim_quickfix = {
    type = 'object',
    required = { 'action' },
    description = 'Manage quickfix list: list, navigate, or clear entries',
    properties = {
      action = {
        type = 'string',
        enum = { 'list', 'next', 'prev', 'first', 'last', 'clear' },
        description = 'Quickfix action to perform',
      },
    },
  },
  vim_undo = {
    type = 'object',
    required = { 'action' },
    description = 'Undo or redo changes in the current buffer',
    properties = {
      action = {
        type = 'string',
        enum = { 'undo', 'redo' },
        description = 'Undo or redo',
      },
      count = {
        type = 'number',
        description = 'Number of steps (default: 1)',
      },
    },
  },
  vim_option = {
    type = 'object',
    required = { 'action', 'name' },
    description = 'Get or set Vim options',
    properties = {
      action = {
        type = 'string',
        enum = { 'get', 'set' },
        description = 'Option action: get or set',
      },
      name = {
        type = 'string',
        description = 'Option name (e.g., number, tabstop, expandtab)',
      },
      value = {
        description = 'Value to set (required for set action)',
      },
      scope = {
        type = 'string',
        enum = { 'global', 'local' },
        description = 'Option scope (default: local)',
      },
    },
  },
}

return M
