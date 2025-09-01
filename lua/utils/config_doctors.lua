-- lua/utils/config_doctor.lua
-- Run this to diagnose common configuration issues

local M = {}

function M.diagnose()
  local issues = {}
  local warnings = {}
  local info = {}
  
  -- Check LSP setup
  local active_clients = vim.lsp.get_active_clients()
  if #active_clients == 0 then
    table.insert(warnings, "No LSP clients are currently active")
  else
    local client_names = {}
    for _, client in ipairs(active_clients) do
      table.insert(client_names, client.name)
    end
    table.insert(info, "Active LSP clients: " .. table.concat(client_names, ", "))
  end
  
  -- Check for C# conflicts
  local csharp_clients = {}
  for _, client in ipairs(active_clients) do
    if client.name == "omnisharp" or client.name == "csharp_ls" then
      table.insert(csharp_clients, client.name)
    end
  end
  if #csharp_clients > 1 then
    table.insert(issues, "Multiple C# LSP servers detected: " .. table.concat(csharp_clients, ", "))
    table.insert(issues, "This can cause conflicts. Consider using only one.")
  end
  
  -- Check Mason installations
  local mason_registry = require('mason-registry')
  local important_tools = {
    'rust-analyzer',
    'codelldb',
    'pyright',
    'debugpy',
    'omnisharp',
    'netcoredbg',
  }
  
  local missing_tools = {}
  for _, tool in ipairs(important_tools) do
    if not mason_registry.is_installed(tool) then
      table.insert(missing_tools, tool)
    end
  end
  
  if #missing_tools > 0 then
    table.insert(warnings, "Missing Mason tools: " .. table.concat(missing_tools, ", "))
    table.insert(info, "Install with: :MasonInstall " .. table.concat(missing_tools, " "))
  end
  
  -- Check treesitter parsers
  local ts_available = pcall(require, 'nvim-treesitter.parsers')
  if ts_available then
    local parsers = require('nvim-treesitter.parsers').get_parser_configs()
    local important_parsers = { 'lua', 'rust', 'python', 'c_sharp', 'javascript', 'typescript' }
    local missing_parsers = {}
    
    for _, parser in ipairs(important_parsers) do
      if not parsers[parser] or not parsers[parser].install_info then
        table.insert(missing_parsers, parser)
      end
    end
    
    if #missing_parsers > 0 then
      table.insert(warnings, "Missing Treesitter parsers: " .. table.concat(missing_parsers, ", "))
      table.insert(info, "Install with: :TSInstall " .. table.concat(missing_parsers, " "))
    end
  end
  
  -- Check plugin health
  local plugin_checks = {
    { name = 'telescope', module = 'telescope' },
    { name = 'nvim-dap', module = 'dap' },
    { name = 'nvim-cmp', module = 'cmp' },
    { name = 'nvim-lspconfig', module = 'lspconfig' },
  }
  
  local missing_plugins = {}
  for _, plugin in ipairs(plugin_checks) do
    local ok = pcall(require, plugin.module)
    if not ok then
      table.insert(missing_plugins, plugin.name)
    end
  end
  
  if #missing_plugins > 0 then
    table.insert(issues, "Missing core plugins: " .. table.concat(missing_plugins, ", "))
  end
  
  -- Check system dependencies
  local system_deps = {
    { name = 'git', cmd = 'git --version' },
    { name = 'rg (ripgrep)', cmd = 'rg --version' },
    { name = 'fd', cmd = 'fd --version' },
  }
  
  local missing_deps = {}
  for _, dep in ipairs(system_deps) do
    if vim.fn.executable(dep.cmd:match('^(%S+)')) == 0 then
      table.insert(missing_deps, dep.name)
    end
  end
  
  if #missing_deps > 0 then
    table.insert(warnings, "Missing system dependencies: " .. table.concat(missing_deps, ", "))
    table.insert(info, "These are recommended for optimal functionality")
  end
  
  -- Generate report
  local report = {
    "🏥 Configuration Diagnosis",
    "==========================",
    "",
  }
  
  if #issues > 0 then
    table.insert(report, "🚨 Issues Found:")
    for _, issue in ipairs(issues) do
      table.insert(report, "  ❌ " .. issue)
    end
    table.insert(report, "")
  end
  
  if #warnings > 0 then
    table.insert(report, "⚠️ Warnings:")
    for _, warning in ipairs(warnings) do
      table.insert(report, "  🟡 " .. warning)
    end
    table.insert(report, "")
  end
  
  if #info > 0 then
    table.insert(report, "ℹ️ Information:")
    for _, item in ipairs(info) do
      table.insert(report, "  🔵 " .. item)
    end
    table.insert(report, "")
  end
  
  if #issues == 0 and #warnings == 0 then
    table.insert(report, "✅ Configuration looks healthy!")
    table.insert(report, "")
  end
  
  table.insert(report, "Press 'q' or <Esc> to close")
  
  -- Show in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, report)
  vim.bo[buf].filetype = "markdown"
  
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#report + 2, vim.o.lines - 4)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    style = "minimal",
    border = "rounded",
    title = " Configuration Doctor ",
    title_pos = "center",
  })
  
  local close_win = function() vim.api.nvim_win_close(win, true) end
  vim.keymap.set("n", "<Esc>", close_win, { buffer = buf })
  vim.keymap.set("n", "q", close_win, { buffer = buf })
end

return M
