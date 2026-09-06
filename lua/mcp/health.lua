--- MCP health check for :checkhealth
---@module 'mcp.health'

local M = {}

--- Run health checks
function M.check()
  vim.health.start('mcp: MCP Server Status')

  -- Check if module loads
  local ok, mcp = pcall(require, 'mcp')
  if not ok then
    vim.health.error('Failed to load mcp module', mcp)
    return
  end

  vim.health.ok('mcp module loaded successfully')

  -- Get server status
  local status_ok, status = pcall(mcp.status)
  if not status_ok then
    vim.health.error('Failed to get server status', status)
    return
  end

  if status.running then
    vim.health.ok('MCP server is running')

    if status.connection_alive then
      vim.health.ok(
        string.format(
          'Connected to Neovim at: %s',
          status.socket_path or 'unknown'
        )
      )
    else
      vim.health.warn('Connection to Neovim is not alive')
    end

    vim.health.info(string.format('Registered tools: %d', status.tools_count))
    vim.health.info(string.format('Registered resources: %d', status.resources_count))
    vim.health.info(string.format('Registered prompts: %d', status.prompts_count))
  else
    vim.health.info('MCP server is not currently running')
  end

  -- Check for Neovim socket configuration
  vim.health.start('mcp: Neovim Connection')

  local socket_env = vim.env.NVIM
  if socket_env then
    vim.health.ok('Socket path configured: ' .. socket_env)

    -- Try to connect
    local conn_ok, conn = pcall(require('mcp.connection').new, socket_env)
    if conn_ok and conn then
      vim.health.ok('Successfully connected to Neovim instance')
      conn:close()
    else
      vim.health.error('Cannot connect to Neovim instance', conn)
    end
  else
    vim.health.warn('No socket path configured ($NVIM not set)')
    vim.health.info('Start Neovim with --listen and set $NVIM, or pass socket_path explicitly')
  end

  -- Check for tools
  vim.health.start('mcp: Tools')

  local tools_ok, tools = pcall(require, 'mcp.tools')
  if not tools_ok then
    vim.health.error('Failed to load tools module', tools)
    return
  end

  local tool_count = #tools.list()
  if tool_count > 0 then
    vim.health.ok(string.format('%d tools registered', tool_count))

    -- List some example tools
    local examples = { 'vim_buffer', 'vim_command', 'vim_status', 'vim_edit' }
    for _, name in ipairs(examples) do
      if tools.registry[name] then
        vim.health.info('  ✓ ' .. name)
      else
        vim.health.warn('  ✗ ' .. name .. ' not registered')
      end
    end
  else
    vim.health.error('No tools registered')
  end

  -- Check for resources
  vim.health.start('mcp: Resources')

  local resources_ok, resources = pcall(require, 'mcp.resources')
  if not resources_ok then
    vim.health.error('Failed to load resources module', resources)
    return
  end

  local resource_count = #resources.list()
  if resource_count > 0 then
    vim.health.ok(string.format('%d resources registered', resource_count))

    -- List resources
    local examples = { 'nvim://session', 'nvim://buffers' }
    for _, uri in ipairs(examples) do
      if resources.registry[uri] then
        vim.health.info('  ✓ ' .. uri)
      else
        vim.health.warn('  ✗ ' .. uri .. ' not registered')
      end
    end
  else
    vim.health.error('No resources registered')
  end

  -- Check for prompts
  vim.health.start('mcp: Prompts')

  local prompts_ok, prompts = pcall(require, 'mcp.prompts')
  if not prompts_ok then
    vim.health.error('Failed to load prompts module', prompts)
    return
  end

  local prompt_count = #prompts.list()
  if prompt_count > 0 then
    vim.health.ok(string.format('%d prompts registered', prompt_count))

    -- List prompts
    if prompts.registry['neovim_workflow'] then
      vim.health.info('  ✓ neovim_workflow')
    else
      vim.health.warn('  ✗ neovim_workflow not registered')
    end
  else
    vim.health.error('No prompts registered')
  end

  -- Provide usage information
  vim.health.start('mcp: Usage')
  vim.health.info('To start the MCP server, run:')
  vim.health.info('  nvim -l scripts/mcp_server.lua [socket_path]')
  vim.health.info('')
  vim.health.info('First, start Neovim with a socket:')
  vim.health.info('  nvim --listen /tmp/nvim')
  vim.health.info('')
  vim.health.info('Then in another terminal:')
  vim.health.info('  nvim -l scripts/mcp_server.lua /tmp/nvim')
end

return M
