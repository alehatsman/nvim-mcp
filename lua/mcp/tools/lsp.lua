--- LSP tools
---@module 'mcp.tools.lsp'

local tools = require('mcp.tools')
local protocol = require('mcp.protocol')

--- Format a list of LSP Locations as file:line:col lines
--- @param locs table List of {uri, range} tables
--- @return string
local function format_locations(locs)
  local lines = {}
  for _, loc in ipairs(locs) do
    local path = loc.uri:gsub('^file://', '')
    local range = loc.range or {}
    local s = range.start or {}
    table.insert(lines, string.format('%s:%d:%d', path, (s.line or 0) + 1, s.character or 0))
  end
  return table.concat(lines, '\n')
end

--- vim_lsp_diagnostics: Get LSP diagnostics for a buffer
tools.register('vim_lsp_diagnostics', function(args, connection)
  local bufnr = args.buffer or 0
  local result, err = connection:exec_lua([[
    local bufnr, severity = ...
    bufnr = (not bufnr or bufnr == 0) and nil or bufnr
    local opts = {}
    if severity then
      opts.severity = vim.diagnostic.severity[severity]
    end
    local diags = vim.diagnostic.get(bufnr, opts)
    local out = {}
    for _, d in ipairs(diags) do
      table.insert(out, {
        severity = vim.diagnostic.severity[d.severity],
        message = d.message,
        lnum = d.lnum + 1,
        col = d.col,
        source = d.source,
        code = d.code,
        bufnr = d.bufnr,
      })
    end
    return out
  ]], { bufnr, args.severity })
  if err then
    return nil, protocol.internal_error('Failed to get diagnostics: ' .. err)
  end

  return {
    content = {
      { type = 'text', text = vim.json.encode(result or {}) },
    },
  }
end, protocol.ToolSchemas.vim_lsp_diagnostics)

--- vim_lsp_hover: Get hover information at a position
tools.register('vim_lsp_hover', function(args, connection)
  local bufnr = args.buffer or 0
  local result, err = connection:exec_lua([[
    local bufnr, line, col = ...
    bufnr = (not bufnr or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
    local params = {
      textDocument = vim.lsp.util.make_text_document_params(bufnr),
      position = { line = line - 1, character = col },
    }
    local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/hover', params, 3000)
    if not responses then return nil end
    for _, res in pairs(responses) do
      if res.result and res.result.contents then
        local lines = vim.lsp.util.convert_input_to_markdown_lines(res.result.contents)
        return table.concat(lines, '\n')
      end
    end
    return nil
  ]], { bufnr, args.line, args.col })
  if err then
    return nil, protocol.internal_error('Failed to get hover: ' .. err)
  end

  return {
    content = {
      { type = 'text', text = result or 'No hover information available' },
    },
  }
end, protocol.ToolSchemas.vim_lsp_hover)

--- vim_lsp_definition: Go to definition of symbol at position
tools.register('vim_lsp_definition', function(args, connection)
  local bufnr = args.buffer or 0
  local locs, err = connection:exec_lua([[
    local bufnr, line, col = ...
    bufnr = (not bufnr or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
    local params = {
      textDocument = vim.lsp.util.make_text_document_params(bufnr),
      position = { line = line - 1, character = col },
    }
    local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/definition', params, 3000)
    if not responses then return {} end
    local locs = {}
    for _, res in pairs(responses) do
      if res.result then
        local r = res.result
        if r.uri then
          table.insert(locs, { uri = r.uri, range = r.range })
        else
          for _, loc in ipairs(r) do
            table.insert(locs, { uri = loc.uri, range = loc.range })
          end
        end
      end
    end
    return locs
  ]], { bufnr, args.line, args.col })
  if err then
    return nil, protocol.internal_error('Failed to get definition: ' .. err)
  end

  if not locs or #locs == 0 then
    return { content = { { type = 'text', text = 'No definition found' } } }
  end

  return {
    content = {
      { type = 'text', text = format_locations(locs) },
    },
  }
end, protocol.ToolSchemas.vim_lsp_definition)

--- vim_lsp_references: Find all references to symbol at position
tools.register('vim_lsp_references', function(args, connection)
  local bufnr = args.buffer or 0
  local locs, err = connection:exec_lua([[
    local bufnr, line, col, include_decl = ...
    bufnr = (not bufnr or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
    local params = {
      textDocument = vim.lsp.util.make_text_document_params(bufnr),
      position = { line = line - 1, character = col },
      context = { includeDeclaration = include_decl or false },
    }
    local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/references', params, 3000)
    if not responses then return {} end
    local locs = {}
    for _, res in pairs(responses) do
      if res.result then
        for _, loc in ipairs(res.result) do
          table.insert(locs, { uri = loc.uri, range = loc.range })
        end
      end
    end
    return locs
  ]], { bufnr, args.line, args.col, args.include_declaration })
  if err then
    return nil, protocol.internal_error('Failed to get references: ' .. err)
  end

  if not locs or #locs == 0 then
    return { content = { { type = 'text', text = 'No references found' } } }
  end

  return {
    content = {
      {
        type = 'text',
        text = string.format('%d reference(s):\n%s', #locs, format_locations(locs)),
      },
    },
  }
end, protocol.ToolSchemas.vim_lsp_references)

--- vim_lsp_rename: Rename symbol at position using LSP
tools.register('vim_lsp_rename', function(args, connection)
  local bufnr = args.buffer or 0
  local result, err = connection:exec_lua([[
    local bufnr, line, col, new_name = ...
    bufnr = (not bufnr or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
    local params = {
      textDocument = vim.lsp.util.make_text_document_params(bufnr),
      position = { line = line - 1, character = col },
      newName = new_name,
    }
    local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/rename', params, 3000)
    if not responses then return nil end
    for _, res in pairs(responses) do
      if res.result then
        vim.lsp.util.apply_workspace_edit(res.result, 'utf-8')
        return 'Rename to ' .. new_name .. ' applied'
      end
    end
    return nil
  ]], { bufnr, args.line, args.col, args.new_name })
  if err then
    return nil, protocol.internal_error('Failed to rename: ' .. err)
  end

  return {
    content = {
      { type = 'text', text = result or 'No LSP client available for rename' },
    },
  }
end, protocol.ToolSchemas.vim_lsp_rename)

return {}
