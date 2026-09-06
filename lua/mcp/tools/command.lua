--- Command execution MCP tool
---@module 'mcp.tools.command'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- Allowlist of permitted ex-command names (lowercase).
--- Shell execution, file sourcing, and arbitrary Lua evaluation are excluded.
--- :normal is excluded because it allows !!cmd shell execution in normal mode.
--- :set/:setlocal/:setglobal are excluded to prevent overriding shell/shellcmdflag/makeprg.
local ALLOWED_COMMANDS = {
  -- display
  echo = true, echom = true, echomsg = true, echon = true,
  -- buffer navigation
  buffer = true, bnext = true, bprev = true, bfirst = true, blast = true, bdelete = true,
  -- file write
  write = true, update = true,
  -- open file
  edit = true,
  -- window management
  split = true, vsplit = true, close = true, only = true, wincmd = true,
  -- tab management
  tabnew = true, tabclose = true, tabnext = true, tabprev = true,
  tabfirst = true, tablast = true,
  -- folds
  fold = true, foldopen = true, foldclose = true,
  -- search / replace
  vimgrep = true, lvimgrep = true, substitute = true,
  -- sorting / formatting
  sort = true, retab = true, center = true, left = true, right = true,
  -- informational
  marks = true, registers = true, jumps = true, changes = true, undolist = true,
  -- undo / redo
  undo = true, redo = true,
  -- text manipulation
  delete = true, yank = true, put = true, copy = true, move = true, join = true,
  -- filetype
  filetype = true,
}

--- Extract the base ex-command name from a full command string.
--- Strips optional range prefix (%, numbers, marks, etc.) then reads the alpha name.
--- @param cmd string
--- @return string lowercase command name, or '' if unparseable
local function extract_cmd_name(cmd)
  local s = cmd:match('^%s*(.-)%s*$') or ''
  -- Strip range prefix: %, ., $, digits, commas, +, -, ^, backtick, quote, <, >
  s = s:gsub("^[%%%d%.%$,+%-%^`'<>%*]+", '')
  s = s:match('^%s*(.-)%s*$') or ''
  local name = s:match('^([a-zA-Z]+)')
  return name and name:lower() or ''
end

--- vim_command: Execute an allowlisted Vim ex-command
--- Only registered when MCP_ALLOW_COMMANDS=1 is set in the environment.
if vim.env.MCP_ALLOW_COMMANDS == '1' then
  tools.register('vim_command', function(args, connection)
    local command = args.command

    if type(command) ~= 'string' or command == '' then
      return nil, protocol.invalid_params('command must be a non-empty string')
    end

    local cmd_name = extract_cmd_name(command)
    if not ALLOWED_COMMANDS[cmd_name] then
      return nil,
        protocol.invalid_params(
          'Command not allowed: ' .. (cmd_name ~= '' and cmd_name or command)
        )
    end

    local result, err = connection:call('nvim_exec2', command, { output = true })
    if err then
      return nil, protocol.internal_error('Command execution failed: ' .. err)
    end

    local output = result.output or ''
    if output == '' then
      output = 'Command executed successfully'
    end

    return {
      content = {
        { type = 'text', text = output },
      },
    }
  end, protocol.ToolSchemas.vim_command)
end

return {}
