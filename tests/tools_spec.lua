--- Tests for MCP tools
local t = require('test.testutil')
local describe, it, before_each = t.describe, t.it, t.before_each
local n = require('test.functional.testnvim')()
local t_mcp = require('test.functional.plugin.mcp.testutil')

local clear_mcp = t_mcp.clear_mcp
local exec_lua = n.exec_lua
local eq = t.eq
local matches = t.matches
local insert = n.insert
local command = n.command

describe('MCP tools', function()
  before_each(clear_mcp)

  describe('tool registry', function()
    it('registers 27 tools', function()
      local count = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return #tools.list()
      end)
      eq(27, count)
    end)

    it('lists all tool definitions', function()
      local tools = exec_lua(function()
        return require('vim.mcp.tools').list()
      end)
      for _, tool in ipairs(tools) do
        assert(tool.name ~= nil, 'Tool should have name')
        assert(tool.description ~= nil, 'Tool should have description')
        assert(tool.inputSchema ~= nil, 'Tool should have inputSchema')
      end
    end)

    it('includes expected tools', function()
      local tool_names = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local names = {}
        for name, _ in pairs(tools.registry) do
          table.insert(names, name)
        end
        return names
      end)
      assert(vim.tbl_contains(tool_names, 'vim_buffer'))
      assert(vim.tbl_contains(tool_names, 'vim_command'))
      assert(vim.tbl_contains(tool_names, 'vim_status'))
      assert(vim.tbl_contains(tool_names, 'vim_edit'))
    end)
  end)

  describe('vim_buffer', function()
    it('returns buffer contents with line numbers', function()
      insert('line 1\nline 2\nline 3')
      command('1')

      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_buf_get_var' then
              return nil, 'Key not found'
            elseif method == 'nvim_buf_get_lines' then
              return { 'line 1', 'line 2', 'line 3' }
            elseif method == 'nvim_buf_get_name' then
              return ''
            end
          end,
        }
        return tools.call('vim_buffer', { buffer = 0 }, connection)
      end)

      assert(result.content ~= nil)
      assert(result.content[1].type == 'text')
      matches('line 1', result.content[1].text)
      matches('line 2', result.content[1].text)
      matches('line 3', result.content[1].text)
    end)

    it('redacts content for sensitive buffer', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_buf_get_var' then
              return true, nil -- mcp_sensitive = true
            elseif method == 'nvim_buf_get_name' then
              return 'secret.txt'
            elseif method == 'nvim_buf_line_count' then
              return 42
            end
          end,
        }
        return tools.call('vim_buffer', { buffer = 0 }, connection)
      end)

      assert(result ~= nil)
      assert(result.content ~= nil)
      matches('redacted', result.content[1].text)
      matches('secret.txt', result.content[1].text)
      -- must not contain actual lines
      assert(not result.content[1].text:find('secret content'))
    end)

    it('returns content for non-sensitive buffer', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_buf_get_name' then return 'normal.txt'
            elseif method == 'nvim_buf_get_var' then return nil, 'Key not found'
            elseif method == 'nvim_buf_get_lines' then return { 'normal content' }
            end
          end,
        }
        return tools.call('vim_buffer', { buffer = 0 }, connection)
      end)
      assert(result ~= nil)
      matches('normal content', result.content[1].text)
    end)
  end)

  describe('vim_command', function()
    it('executes allowlisted Vim commands', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, cmd, opts)
            if method == 'nvim_exec2' then
              return { output = 'Command executed' }
            end
          end,
        }
        return tools.call('vim_command', { command = 'echo "test"' }, connection)
      end)

      assert(result.content ~= nil)
      assert(result.content[1].type == 'text')
      matches('Command executed', result.content[1].text)
    end)

    it('rejects shell commands (!cmd)', function()
      local result, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_command', { command = '!ls' }, {})
      end)
      assert(err ~= nil)
      assert(err.code == -32602) -- InvalidParams
      matches('Command not allowed', err.message)
    end)

    it('rejects non-allowlisted commands', function()
      local result, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {}
        return tools.call('vim_command', { command = 'source /etc/hosts' }, connection)
      end)

      assert(err ~= nil)
      assert(err.code == -32602)
      matches('Command not allowed', err.message)
    end)

    it('rejects luafile execution', function()
      local result, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {}
        return tools.call('vim_command', { command = 'luafile /tmp/evil.lua' }, connection)
      end)

      assert(err ~= nil)
      assert(err.code == -32602)
    end)

    it('rejects :terminal', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_command', { command = 'terminal' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)

    it('rejects :term abbreviation', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_command', { command = 'term' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)

    it('rejects :lua', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_command', { command = 'lua print(1)' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)

    it('rejects :python', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_command', { command = 'python print(1)' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)

    it('allows range-prefixed allowlisted commands', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, cmd, opts)
            if method == 'nvim_exec2' then
              return { output = '' }
            end
          end,
        }
        return tools.call('vim_command', { command = '%substitute/foo/bar/g' }, connection)
      end)

      assert(result ~= nil)
    end)

    it('requires command parameter', function()
      local result, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {}
        return tools.call('vim_command', {}, connection)
      end)

      assert(err ~= nil)
      assert(err.code == -32602) -- InvalidParams
    end)
  end)

  describe('vim_edit', function()
    it('inserts text at specified line', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, bufnr, start_line, end_line, strict, lines)
            if method == 'nvim_buf_set_lines' then
              return nil
            end
          end,
        }
        return tools.call('vim_edit', {
          operation = 'insert',
          line = 5,
          text = 'new line',
        }, connection)
      end)

      assert(result.content ~= nil)
      matches('Inserted', result.content[1].text)
    end)

    it('rejects non-integer line', function()
      local result, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {}
        return tools.call('vim_edit', {
          operation = 'insert',
          line = 1.5,
          text = 'new line',
        }, connection)
      end)

      assert(err ~= nil)
      assert(err.code == -32602)
    end)

    it('rejects line < 1', function()
      local result, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {}
        return tools.call('vim_edit', {
          operation = 'insert',
          line = 0,
          text = 'new line',
        }, connection)
      end)

      assert(err ~= nil)
      assert(err.code == -32602)
    end)

    it('rejects invalid operation', function()
      local result, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {}
        return tools.call('vim_edit', {
          operation = 'deleteAll',
          text = 'x',
        }, connection)
      end)

      assert(err ~= nil)
      assert(err.code == -32602)
      matches('operation must be one of', err.message)
    end)

    it('rejects end_line < start_line in replace', function()
      local result, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {}
        return tools.call('vim_edit', {
          operation = 'replace',
          start_line = 10,
          end_line = 5,
          text = 'x',
        }, connection)
      end)

      assert(err ~= nil)
      assert(err.code == -32602)
      matches('end_line must be >= start_line', err.message)
    end)

    it('replaces lines in range', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, bufnr, start_line, end_line, strict, lines)
            if method == 'nvim_buf_set_lines' then
              return nil
            end
          end,
        }
        return tools.call('vim_edit', {
          operation = 'replace',
          start_line = 1,
          end_line = 3,
          text = 'replaced',
        }, connection)
      end)

      assert(result.content ~= nil)
      matches('Replaced lines', result.content[1].text)
    end)

    it('replaces entire buffer', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, bufnr, start_line, end_line, strict, lines)
            if method == 'nvim_buf_set_lines' then
              return nil
            end
          end,
        }
        return tools.call('vim_edit', {
          operation = 'replaceAll',
          text = 'new content',
        }, connection)
      end)

      assert(result.content ~= nil)
      matches('Replaced entire buffer', result.content[1].text)
    end)

    it('requires operation and text', function()
      local result, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {}
        return tools.call('vim_edit', { operation = 'insert' }, connection)
      end)

      assert(err ~= nil)
      matches('Missing required field', err.message)
    end)
  end)

  describe('vim_status', function()
    it('returns session status', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_win_get_cursor' then
              return { 1, 0 }
            elseif method == 'nvim_get_mode' then
              return { mode = 'n' }
            elseif method == 'nvim_buf_get_name' then
              return 'test.lua'
            elseif method == 'nvim_buf_line_count' then
              return 10
            elseif method == 'nvim_call_function' then
              return '/home/user/project'
            end
          end,
          exec_lua = function(_, code, args)
            return {}
          end,
        }
        return tools.call('vim_status', { buffer = 0 }, connection)
      end)

      assert(result.content ~= nil)
      local status = vim.json.decode(result.content[1].text)
      assert(status.cursor ~= nil)
      assert(status.mode ~= nil)
      assert(status.buffer ~= nil)
    end)
  end)

  describe('vim_window', function()
    it('creates horizontal split', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, cmd)
            if method == 'nvim_command' then
              return nil
            end
          end,
        }
        return tools.call('vim_window', { action = 'split' }, connection)
      end)

      assert(result.content ~= nil)
      matches('horizontal split', result.content[1].text)
    end)

    it('navigates between windows', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, cmd)
            if method == 'nvim_command' then
              return nil
            end
          end,
        }
        return tools.call('vim_window', { action = 'navigate', direction = 'l' }, connection)
      end)

      assert(result.content ~= nil)
      matches('right', result.content[1].text)
    end)
  end)

  describe('vim_file_open', function()
    it('opens a file', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_command' then return nil
            elseif method == 'nvim_get_current_buf' then return 3
            end
          end,
        }
        return tools.call('vim_file_open', { filename = 'test.lua' }, connection)
      end)
      assert(result ~= nil)
      matches('test.lua', result.content[1].text)
    end)

    it('rejects empty filename', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_file_open', { filename = '' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
      matches('filename cannot be empty', err.message)
    end)

    it('rejects path traversal', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_file_open', { filename = '../../etc/passwd' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
      matches('traversal', err.message)
    end)
  end)

  describe('vim_buffer_switch', function()
    it('switches buffer by number', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_set_current_buf' then return nil end
          end,
        }
        return tools.call('vim_buffer_switch', { buffer = 2 }, connection)
      end)
      assert(result ~= nil)
      matches('2', result.content[1].text)
    end)

    it('switches buffer by filename', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_list_bufs' then return { 1, 2 }
            elseif method == 'nvim_buf_is_loaded' then return true
            elseif method == 'nvim_buf_get_name' then
              local bufnr = select(1, ...)
              if bufnr == 2 then return '/home/user/foo.lua' end
              return ''
            elseif method == 'nvim_set_current_buf' then return nil
            end
          end,
        }
        return tools.call('vim_buffer_switch', { filename = 'foo.lua' }, connection)
      end)
      assert(result ~= nil)
      matches('foo.lua', result.content[1].text)
    end)

    it('errors on unknown filename', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_list_bufs' then return { 1 }
            elseif method == 'nvim_buf_is_loaded' then return true
            elseif method == 'nvim_buf_get_name' then return 'other.lua'
            end
          end,
        }
        return tools.call('vim_buffer_switch', { filename = 'missing.lua' }, connection)
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
      matches('No buffer found', err.message)
    end)
  end)

  describe('vim_buffer_save', function()
    it('saves named buffer', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_buf_get_name' then return 'myfile.lua'
            elseif method == 'nvim_exec_lua' then return nil
            end
          end,
        }
        return tools.call('vim_buffer_save', { buffer = 0 }, connection)
      end)
      assert(result ~= nil)
      matches('myfile.lua', result.content[1].text)
    end)

    it('errors on unnamed buffer', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_buf_get_name' then return ''
            end
          end,
        }
        return tools.call('vim_buffer_save', { buffer = 0 }, connection)
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
      matches('no filename', err.message)
    end)
  end)

  describe('vim_mark', function()
    it('sets a valid mark', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_buf_set_mark' then return true end
          end,
        }
        return tools.call('vim_mark', { mark = 'a', line = 5, col = 0 }, connection)
      end)
      assert(result ~= nil)
      matches('mark a', result.content[1].text)
    end)

    it('rejects multi-char mark', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_mark', { mark = 'ab', line = 1, col = 0 }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)

    it('rejects non-letter mark', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_mark', { mark = '1', line = 1, col = 0 }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('vim_register', function()
    it('sets register content', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args) return nil end,
        }
        return tools.call('vim_register', { register = 'a', content = 'hello' }, connection)
      end)
      assert(result ~= nil)
      matches('"a"', result.content[1].text)
    end)

    it('rejects multi-char register name', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_register', { register = 'ab', content = 'x' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('vim_visual', function()
    it('creates character visual selection', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args) return nil end,
        }
        return tools.call('vim_visual', {
          mode = 'v',
          start_line = 1, start_col = 1,
          end_line = 2, end_col = 5,
        }, connection)
      end)
      assert(result ~= nil)
      matches('character', result.content[1].text)
    end)

    it('rejects invalid mode', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_visual', {
          mode = 'x',
          start_line = 1, start_col = 1,
          end_line = 1, end_col = 1,
        }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('vim_jump', function()
    it('jumps backward', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_jump', { action = 'back' }, connection)
      end)
      assert(result ~= nil)
      matches('back', result.content[1].text)
    end)

    it('jumps forward', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_jump', { action = 'forward' }, connection)
      end)
      assert(result ~= nil)
      matches('forward', result.content[1].text)
    end)

    it('rejects invalid action', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_jump', { action = 'sideways' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('vim_search', function()
    it('searches with a basic pattern', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_search', { pattern = 'foo' }, connection)
      end)
      assert(result ~= nil)
      matches('foo', result.content[1].text)
    end)

    it('applies wholeWord flag', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_search', { pattern = 'foo', wholeWord = true }, connection)
      end)
      assert(result ~= nil)
      -- wholeWord wraps in \<...\>
      matches('foo', result.content[1].text)
    end)
  end)

  describe('vim_search_replace', function()
    it('replaces text', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, cmd, opts)
            if method == 'nvim_exec2' then
              return { output = '3 substitutions' }
            end
          end,
        }
        return tools.call('vim_search_replace', {
          pattern = 'foo',
          replacement = 'bar',
        }, connection)
      end)
      assert(result ~= nil)
      matches('substitution', result.content[1].text)
    end)

    it('escapes & and ~ in replacement', function()
      -- Verify that & and ~ are escaped before being sent to nvim_exec2
      local captured_cmd = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local cmd_sent
        local connection = {
          call = function(_, method, cmd, opts)
            if method == 'nvim_exec2' then
              cmd_sent = cmd
              return { output = 'done' }
            end
          end,
        }
        tools.call('vim_search_replace', {
          pattern = 'foo',
          replacement = 'a&b~c',
        }, connection)
        return cmd_sent
      end)
      assert(captured_cmd ~= nil)
      -- & and ~ must be escaped with backslash
      matches('\\&', captured_cmd)
      matches('\\~', captured_cmd)
    end)
  end)

  describe('vim_grep', function()
    it('runs vimgrep and returns quickfix results', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_command' then return nil end
          end,
          exec_lua = function(_, code, args)
            return 'file.lua:1:1: match line'
          end,
        }
        return tools.call('vim_grep', { pattern = 'foo', files = '**/*.lua' }, connection)
      end)
      assert(result ~= nil)
      matches('foo', result.content[1].text)
      matches('match line', result.content[1].text)
    end)

    it('escapes / in grep pattern', function()
      local captured_cmd = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local cmd_sent
        local connection = {
          call = function(_, method, cmd)
            if method == 'nvim_command' then
              cmd_sent = cmd
              return nil
            end
          end,
          exec_lua = function(_, code, args) return 'no matches' end,
        }
        tools.call('vim_grep', { pattern = 'a/b' }, connection)
        return cmd_sent
      end)
      assert(captured_cmd ~= nil)
      -- / must be escaped as \/
      matches('a\\/', captured_cmd)
    end)

    it('redacts text from sensitive buffers', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')

        -- Create a buffer marked sensitive with a quickfix entry
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(bufnr, 'secret.txt')
        vim.fn.setbufvar(bufnr, 'mcp_sensitive', true)
        vim.fn.setqflist({}, 'r')
        vim.fn.setqflist({ { bufnr = bufnr, lnum = 5, col = 1, text = 'top secret line' } }, 'a')

        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_command' then return nil end
          end,
          -- Evaluate the exec_lua code string in this Neovim instance
          exec_lua = function(_, code, _args)
            local chunk = load(code)
            return chunk and chunk() or nil
          end,
        }

        return tools.call('vim_grep', { pattern = 'secret' }, connection)
      end)

      assert(result ~= nil, 'Expected a result')
      assert(result.content ~= nil, 'Expected content')
      matches('[Rr]edacted', result.content[1].text)
      assert(not result.content[1].text:find('top secret'), 'Sensitive text must not appear in output')
    end)
  end)

  describe('vim_macro', function()
    it('starts recording', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_macro', { action = 'record', register = 'a' }, connection)
      end)
      assert(result ~= nil)
      matches('record', result.content[1].text)
    end)

    it('stops recording', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_macro', { action = 'stop' }, connection)
      end)
      assert(result ~= nil)
      matches('[Ss]top', result.content[1].text)
    end)

    it('plays macro', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_macro', { action = 'play', register = 'b' }, connection)
      end)
      assert(result ~= nil)
      matches('[Pp]lay', result.content[1].text)
    end)

    it('requires register for record', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_macro', { action = 'record' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('vim_tab', function()
    it('creates new tab', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_tab', { action = 'new' }, connection)
      end)
      assert(result ~= nil)
      matches('[Nn]ew tab', result.content[1].text)
    end)

    it('closes tab', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_tab', { action = 'close' }, connection)
      end)
      assert(result ~= nil)
      matches('[Cc]lose', result.content[1].text)
    end)

    it('navigates to next tab', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_tab', { action = 'next' }, connection)
      end)
      assert(result ~= nil)
      matches('[Nn]ext', result.content[1].text)
    end)

    it('rejects invalid action', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_tab', { action = 'flip' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('vim_fold', function()
    it('creates a fold', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_fold', {
          action = 'create',
          start_line = 1,
          end_line = 5,
        }, connection)
      end)
      assert(result ~= nil)
      matches('[Cc]reat', result.content[1].text)
    end)

    it('opens a fold', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_fold', { action = 'open' }, connection)
      end)
      assert(result ~= nil)
      matches('[Oo]pen', result.content[1].text)
    end)

    it('rejects invalid action', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_fold', { action = 'explode' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)

    it('requires start_line and end_line for create', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_fold', { action = 'create' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
      matches('start_line', err.message)
    end)
  end)

  describe('vim_health', function()
    it('returns health info when connection succeeds', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          socket_path = '/tmp/test.sock',
          call = function(_, method, ...)
            if method == 'nvim_get_api_info' then
              return { {}, { version = { major = 0, minor = 10, patch = 0 } } }
            end
          end,
        }
        return tools.call('vim_health', {}, connection)
      end)
      assert(result ~= nil)
      assert(result.isError == nil or result.isError == false)
      local info = vim.json.decode(result.content[1].text)
      eq(true, info.connected)
    end)

    it('returns isError on connection failure', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            return nil, 'connection refused'
          end,
        }
        return tools.call('vim_health', {}, connection)
      end)
      assert(result ~= nil)
      eq(true, result.isError)
    end)
  end)

  describe('vim_lsp_diagnostics', function()
    it('returns diagnostics as JSON', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args)
            return {
              { severity = 'ERROR', message = 'undefined variable', lnum = 5, col = 3 },
              { severity = 'WARN', message = 'unused variable', lnum = 10, col = 0 },
            }
          end,
        }
        return tools.call('vim_lsp_diagnostics', { buffer = 0 }, connection)
      end)
      assert(result ~= nil)
      local info = vim.json.decode(result.content[1].text)
      eq(2, #info)
      eq('ERROR', info[1].severity)
    end)

    it('returns empty list when no diagnostics', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args) return {} end,
        }
        return tools.call('vim_lsp_diagnostics', {}, connection)
      end)
      assert(result ~= nil)
      local info = vim.json.decode(result.content[1].text)
      eq(0, #info)
    end)
  end)

  describe('vim_lsp_hover', function()
    it('returns hover text', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args) return 'function foo(): void' end,
        }
        return tools.call('vim_lsp_hover', { line = 5, col = 3 }, connection)
      end)
      assert(result ~= nil)
      matches('function foo', result.content[1].text)
    end)

    it('reports no hover info when LSP returns nil', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args) return nil end,
        }
        return tools.call('vim_lsp_hover', { line = 1, col = 0 }, connection)
      end)
      assert(result ~= nil)
      matches('[Nn]o hover', result.content[1].text)
    end)
  end)

  describe('vim_lsp_definition', function()
    it('returns definition location', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args)
            return {
              { uri = 'file:///src/foo.lua', range = { start = { line = 9, character = 0 } } },
            }
          end,
        }
        return tools.call('vim_lsp_definition', { line = 5, col = 3 }, connection)
      end)
      assert(result ~= nil)
      matches('foo.lua:10:0', result.content[1].text)
    end)

    it('reports no definition found', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args) return {} end,
        }
        return tools.call('vim_lsp_definition', { line = 1, col = 0 }, connection)
      end)
      assert(result ~= nil)
      matches('[Nn]o definition', result.content[1].text)
    end)
  end)

  describe('vim_lsp_references', function()
    it('returns reference locations with count', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args)
            return {
              { uri = 'file:///src/foo.lua', range = { start = { line = 2, character = 0 } } },
              { uri = 'file:///src/bar.lua', range = { start = { line = 9, character = 5 } } },
            }
          end,
        }
        return tools.call('vim_lsp_references', { line = 5, col = 3 }, connection)
      end)
      assert(result ~= nil)
      matches('2 reference', result.content[1].text)
      matches('foo.lua', result.content[1].text)
      matches('bar.lua', result.content[1].text)
    end)

    it('reports no references found', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args) return {} end,
        }
        return tools.call('vim_lsp_references', { line = 1, col = 0 }, connection)
      end)
      assert(result ~= nil)
      matches('[Nn]o references', result.content[1].text)
    end)
  end)

  describe('vim_lsp_rename', function()
    it('applies rename', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args) return 'Rename to newFoo applied' end,
        }
        return tools.call('vim_lsp_rename', { line = 5, col = 3, new_name = 'newFoo' }, connection)
      end)
      assert(result ~= nil)
      matches('newFoo', result.content[1].text)
    end)

    it('reports when LSP unavailable', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args) return nil end,
        }
        return tools.call('vim_lsp_rename', { line = 1, col = 0, new_name = 'bar' }, connection)
      end)
      assert(result ~= nil)
      matches('[Nn]o LSP', result.content[1].text)
    end)
  end)

  describe('vim_quickfix', function()
    it('lists quickfix entries', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_call_function' then
              return {
                { bufnr = 1, lnum = 5, col = 3, text = 'error here' },
                { bufnr = 2, lnum = 10, col = 0, text = 'another error' },
              }
            elseif method == 'nvim_buf_get_name' then
              local bufnr = select(1, ...)
              return bufnr == 1 and 'foo.lua' or 'bar.lua'
            end
          end,
        }
        return tools.call('vim_quickfix', { action = 'list' }, connection)
      end)
      assert(result ~= nil)
      matches('error here', result.content[1].text)
      matches('another error', result.content[1].text)
    end)

    it('shows empty message for empty list', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return {} end,
        }
        return tools.call('vim_quickfix', { action = 'list' }, connection)
      end)
      assert(result ~= nil)
      matches('[Ee]mpty', result.content[1].text)
    end)

    it('clears quickfix list', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_quickfix', { action = 'clear' }, connection)
      end)
      assert(result ~= nil)
      matches('[Cc]lear', result.content[1].text)
    end)

    it('rejects invalid action', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_quickfix', { action = 'explode' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('vim_undo', function()
    it('undoes changes', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args)
            return { seq_cur = 2, seq_last = 5 }
          end,
        }
        return tools.call('vim_undo', { action = 'undo', count = 1 }, connection)
      end)
      assert(result ~= nil)
      matches('[Uu]ndo', result.content[1].text)
    end)

    it('redoes changes', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          exec_lua = function(_, code, args)
            return { seq_cur = 3, seq_last = 5 }
          end,
        }
        return tools.call('vim_undo', { action = 'redo', count = 1 }, connection)
      end)
      assert(result ~= nil)
      matches('[Rr]edo', result.content[1].text)
    end)

    it('rejects invalid action', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_undo', { action = 'replay' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('vim_option', function()
    it('gets option value', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_get_option_value' then return 2 end
          end,
        }
        return tools.call('vim_option', { action = 'get', name = 'tabstop' }, connection)
      end)
      assert(result ~= nil)
      matches('tabstop', result.content[1].text)
      matches('2', result.content[1].text)
    end)

    it('sets option value', function()
      local result = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_option', {
          action = 'set', name = 'number', value = true,
        }, connection)
      end)
      assert(result ~= nil)
      matches('number', result.content[1].text)
    end)

    it('errors when value missing for set', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...) return nil end,
        }
        return tools.call('vim_option', { action = 'set', name = 'number' }, connection)
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)

    it('rejects invalid scope', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_option', {
          action = 'get', name = 'number', scope = 'window',
        }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)

    it('rejects invalid action', function()
      local _, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        return tools.call('vim_option', { action = 'toggle', name = 'number' }, {})
      end)
      assert(err ~= nil)
      eq(-32602, err.code)
    end)
  end)

  describe('error handling', function()
    it('returns error for unknown tool', function()
      local result, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {}
        return tools.call('nonexistent_tool', {}, connection)
      end)

      assert(err ~= nil)
      assert(err.code == -32601) -- MethodNotFound
    end)

    it('handles tool execution errors', function()
      local result, err = exec_lua(function()
        local tools = require('vim.mcp.tools')
        local connection = {
          call = function(_, method, ...)
            if method == 'nvim_buf_get_var' then
              return nil, 'Key not found'
            end
            error('Connection error')
          end,
        }
        return tools.call('vim_buffer', { buffer = 0 }, connection)
      end)

      assert(err ~= nil)
      assert(err.code == -32603) -- InternalError
    end)
  end)
end)
