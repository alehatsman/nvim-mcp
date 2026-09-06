--- Neovim workflow prompt
---@module 'mcp.prompts.workflow'

local prompts = require('mcp.prompts')

--- Workflow help content for different tasks
local workflows = {
  editing = [[
# Editing Files in Neovim

## Basic Commands
- `vim_file_open` - Open a file
- `vim_buffer` - View buffer contents
- `vim_edit` - Edit buffer (insert, replace, replaceAll)
- `vim_buffer_save` - Save changes

## Example Workflow
1. Open file: vim_file_open { filename: "path/to/file" }
2. View contents: vim_buffer { buffer: 0 }
3. Edit text: vim_edit { operation: "replace", start_line: 10, end_line: 15, text: "new content" }
4. Save: vim_buffer_save { buffer: 0 }
]],

  navigation = [[
# Navigation in Neovim

## Moving Around
- `vim_jump` - Navigate jump list (back/forward/list)
- `vim_mark` - Set named marks
- `vim_buffer_switch` - Switch between buffers
- `vim_window` - Navigate windows (h/j/k/l)

## Example Workflow
1. List buffers: nvim://buffers resource
2. Switch buffer: vim_buffer_switch { filename: "example.lua" }
3. Set mark: vim_mark { mark: "a", line: 100, col: 0 }
4. Jump back: vim_jump { action: "back" }
]],

  search = [[
# Searching in Neovim

## Search Commands
- `vim_search` - Find pattern in current buffer
- `vim_search_replace` - Find and replace
- `vim_grep` - Project-wide search with vimgrep

## Example Workflow
1. Simple search: vim_search { pattern: "function", ignoreCase: true }
2. Replace: vim_search_replace { pattern: "old", replacement: "new", global: true }
3. Project search: vim_grep { pattern: "TODO", files: "**/*.lua" }
]],

  buffers = [[
# Buffer Management

## Buffer Commands
- `vim_buffer` - View buffer contents
- `vim_buffer_switch` - Switch to buffer
- `vim_buffer_save` - Save buffer
- `nvim://buffers` - List all buffers (resource)

## Example Workflow
1. List all buffers: Read nvim://buffers resource
2. View buffer: vim_buffer { buffer: 1 }
3. Switch buffer: vim_buffer_switch { buffer: 2 }
4. Save: vim_buffer_save { buffer: 0 }
]],

  windows = [[
# Window Management

## Window Commands
- `vim_window` - Manage windows (split/vsplit/close/navigate)
- `vim_tab` - Manage tabs

## Example Workflow
1. Split window: vim_window { action: "vsplit" }
2. Navigate: vim_window { action: "navigate", direction: "l" }
3. Close: vim_window { action: "close" }
4. List tabs: vim_tab { action: "list" }
]],

  macros = [[
# Macros and Advanced Features

## Commands
- `vim_macro` - Record, stop, and play macros
- `vim_fold` - Manage code folds
- `vim_visual` - Create visual selections

## Example Workflow
1. Record macro: vim_macro { action: "record", register: "q" }
2. (perform actions)
3. Stop: vim_macro { action: "stop" }
4. Play: vim_macro { action: "play", register: "q" }
]],
}

--- neovim_workflow: Get context-aware help for Neovim workflows
prompts.register(
  'neovim_workflow',
  'Get help with common Neovim workflows and tasks',
  {
    {
      name = 'task',
      description = 'The type of task you want help with',
      required = true,
    },
  },
  function(args, _)
    local task = args.task or 'editing'
    local content = workflows[task]
      or workflows.editing .. '\n\nAvailable tasks: editing, navigation, search, buffers, windows, macros'

    return {
      description = string.format('Help for %s workflow', task),
      messages = {
        {
          role = 'user',
          content = {
            type = 'text',
            text = content,
          },
        },
      },
    }
  end
)

return {}
