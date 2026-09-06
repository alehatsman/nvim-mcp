-- MCP Server entry point for headless Neovim
--
-- IMPORTANT: Must be loaded via --cmd, NOT via -l.  The -l flag exits
-- immediately after the script returns, before the event loop can process
-- any messages.  Use --cmd instead:
--
--   NVIM=/path/to/nvim.sock \
--   nvim --headless -u NONE -U NONE -i NONE -n \
--        --cmd "luafile /path/to/mcp_server_headless.lua"
--
-- Socket discovery priority (first match wins):
--   $MCP_SOCKET_PATH  explicit override (env var, since --cmd has no positional argv)
--   $NVIM             set automatically when running inside a Neovim :terminal
--   $NVIM_SOCKET_PATH conventional variable users set in .zshrc / .bashrc
--   serverlist()      Neovim's own server list; useful when loaded as a plugin
local socket_path = vim.env.MCP_SOCKET_PATH
local log_level = vim.env.MCP_LOG_LEVEL
local log_file = vim.env.MCP_LOG_FILE

-- Load and start MCP server
local mcp = require('mcp')

local opts = {
  socket_path = socket_path,
  log_level = log_level,
  log_file = log_file,
}

-- Start server
local ok, err = pcall(mcp.start, opts)
if not ok then
  vim.api.nvim_err_writeln('Failed to start MCP server: ' .. tostring(err))
  vim.cmd('qa!')
end

-- Event loop keeps pumping (--cmd mode).  Server exits via vim.cmd('qa!')
-- inside the transport on_exit callback once stdin closes and all
-- in-flight requests are answered.
