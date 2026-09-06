--- MCP subprocess end-to-end test
--- Spawns a real headless Neovim MCP server and communicates over stdio.
local t = require('test.testutil')
local describe, it, before_each = t.describe, t.it, t.before_each
local n = require('test.functional.testnvim')()
local t_mcp = require('test.functional.plugin.mcp.testutil')

local eq = t.eq
local exec_lua = n.exec_lua

describe('MCP e2e (subprocess)', function()
  before_each(t_mcp.clear_mcp)

  it('completes initialize + tools/list session', function()
    local nvim_prog = n.nvim_prog
    local vimruntime = os.getenv('VIMRUNTIME') or ''

    local result = exec_lua(function(nvim_bin, vimrt)
      local sock_path = '/tmp/nvim_mcp_e2e_' .. vim.fn.getpid() .. '.sock'

      -- Clean up any leftover socket from a previous run
      pcall(os.remove, sock_path)

      -- 1. Start the target Neovim that the MCP server will connect to
      local server_job = vim.fn.jobstart({
        nvim_bin, '--clean', '--headless', '--listen', sock_path,
      }, { rpc = false })

      local sock_ok = vim.wait(5000, function()
        return vim.uv.fs_stat(sock_path) ~= nil
      end, 50)

      if not sock_ok then
        vim.fn.jobstop(server_job)
        error('Target Neovim socket never appeared: ' .. sock_path)
      end

      -- 2. Spawn the MCP headless server with stdin = pipe
      local script = vim.fn.fnamemodify(vimrt, ':h') .. '/scripts/mcp_server_headless.lua'
      local responses = {}
      local mcp_exited = false
      local mcp_exit_code = -1

      local mcp_job = vim.fn.jobstart({
        nvim_bin,
        '--headless', '-u', 'NONE', '-U', 'NONE', '-i', 'NONE', '-n',
        '--cmd', 'luafile ' .. script,
      }, {
        env = {
          MCP_SOCKET_PATH = sock_path,
          MCP_LOG_LEVEL = 'error',
          VIMRUNTIME = vimrt,
          MCP_ALLOW_COMMANDS = '1',
          NVIM_LUA_NOTRACK = '1',
        },
        stdin = 'pipe',
        on_stdout = function(_, data, _)
          for _, line in ipairs(data) do
            if line ~= '' then
              local ok, msg = pcall(vim.json.decode, line)
              if ok then
                table.insert(responses, msg)
              end
            end
          end
        end,
        on_stderr = function(_, _, _) end,
        on_exit = function(_, code, _)
          mcp_exited = true
          mcp_exit_code = code
        end,
      })

      if mcp_job <= 0 then
        vim.fn.jobstop(server_job)
        pcall(os.remove, sock_path)
        error('Failed to start MCP server job')
      end

      local function send(msg)
        vim.fn.chansend(mcp_job, vim.json.encode(msg) .. '\n')
      end

      local function wait_for(id)
        local found
        local ok = vim.wait(10000, function()
          for i, r in ipairs(responses) do
            if r.id == id then
              found = table.remove(responses, i)
              return true
            end
          end
          return false
        end, 50)
        if not ok then
          error('Timeout waiting for response id=' .. tostring(id))
        end
        return found
      end

      -- 3. MCP handshake: initialize
      send({
        jsonrpc = '2.0',
        id = 1,
        method = 'initialize',
        params = {
          protocolVersion = '2025-11-25',
          capabilities = {},
          clientInfo = { name = 'e2e-test', version = '0.1' },
        },
      })
      local init_resp = wait_for(1)

      -- 4. Notification: initialized (no response expected)
      send({ jsonrpc = '2.0', method = 'notifications/initialized', params = {} })

      -- 5. tools/list
      send({ jsonrpc = '2.0', id = 2, method = 'tools/list', params = {} })
      local list_resp = wait_for(2)

      -- 6. Close stdin → server should drain in-flight requests and exit cleanly
      vim.fn.chanclose(mcp_job, 'stdin')
      vim.wait(5000, function()
        return mcp_exited
      end, 50)

      -- Cleanup
      vim.fn.jobstop(server_job)
      pcall(os.remove, sock_path)

      return {
        protocol_version = init_resp.result and init_resp.result.protocolVersion or '',
        tools_count = list_resp.result and #list_resp.result.tools or 0,
        tools_ok = list_resp.result ~= nil and type(list_resp.result.tools) == 'table',
        exit_code = mcp_exit_code,
      }
    end, nvim_prog, vimruntime)

    local supported = { ['2025-11-25'] = true, ['2024-11-05'] = true }
    assert(
      supported[result.protocol_version],
      'Unexpected protocol version: ' .. tostring(result.protocol_version)
    )
    eq(true, result.tools_ok)
    assert(result.tools_count > 0, 'Expected non-empty tools list, got ' .. tostring(result.tools_count))
    eq(0, result.exit_code)
  end)
end)
