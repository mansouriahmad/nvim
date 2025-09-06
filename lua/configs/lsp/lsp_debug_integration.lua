-- lua/configs/lsp_debug_integration.lua
-- Main integration file using the new platform-aware configuration

local M = {}

-- Import the platform configuration
local platform_config = require('configs.lsp.platform_config')

-- Import language-specific modules (updated versions)
local rust_lsp = require('configs.lsp.rust')
local rust_debug = require('configs.debug.rust')

-- Setup function for LSP servers
function M.setup_lsp(capabilities)
  vim.notify(string.format(
    "Setting up LSP servers for platform: %s",
    platform_config.platform
  ), vim.log.levels.INFO)

  -- Setup each language LSP
  local results = {
    rust = rust_lsp.setup_lsp(capabilities),
  }

  -- Report results
  for lang, success in pairs(results) do
    if success then
      vim.notify(string.format("✅ %s LSP configured", lang), vim.log.levels.INFO)
    else
      vim.notify(string.format("❌ %s LSP failed", lang), vim.log.levels.WARN)
    end
  end
end

-- Setup function for debuggers using platform configuration
function M.setup_debuggers()
  local dap = require("dap")
  local dapui = require("dapui")

  vim.notify(string.format(
    "Setting up debuggers for platform: %s",
    platform_config.platform
  ), vim.log.levels.INFO)

  -- Setup debuggers using platform configuration
  local results = {
    rust = platform_config.setup_rust_debugger(dap),
  }

  -- Report results
  for lang, success in pairs(results) do
    if success then
      vim.notify(string.format("✅ %s debugger configured", lang), vim.log.levels.INFO)
    else
      vim.notify(string.format("❌ %s debugger failed", lang), vim.log.levels.WARN)
    end
  end

  -- Setup debug configurations (these use the platform-aware finders internally)
  rust_debug.setup_configurations()

  -- Setup language-specific keymaps
  rust_debug.setup_keymaps()

  -- Enhanced DAP UI setup
  dapui.setup({
    icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
    layouts = {
      {
        elements = {
          { id = "scopes",      size = 0.33 },
          { id = "breakpoints", size = 0.17 },
          { id = "stacks",      size = 0.25 },
          { id = "watches",     size = 0.25 },
        },
        size = 0.33,
        position = "right",
      },
      {
        elements = {
          { id = "repl",    size = 0.45 },
          { id = "console", size = 0.55 },
        },
        size = 0.27,
        position = "bottom",
      },
    },
  })

  -- Auto open/close DAP UI
  dap.listeners.before.attach.dapui_config = function()
    dapui.open()
  end
  dap.listeners.before.launch.dapui_config = function()
    dapui.open()
  end
  dap.listeners.before.event_terminated.dapui_config = function()
    dapui.close()
  end
  dap.listeners.before.event_exited.dapui_config = function()
    dapui.close()
  end
end

-- Universal F5 launcher that detects filetype and launches appropriate debugger
function M.universal_debug_launcher()
  local filetype = vim.bo.filetype
  local dap = require('dap')

  vim.notify(string.format(
    "[%s] Launching debugger for: %s",
    platform_config.platform,
    filetype
  ), vim.log.levels.INFO)

  if filetype == 'rust' then
    vim.notify('🦀 Launching Rust debugger...', vim.log.levels.INFO)
    rust_debug.build_and_debug()
  else
    vim.notify('No automatic debug configuration for ' .. filetype, vim.log.levels.INFO)
    dap.continue()
  end
end

-- Better terminate function that ensures proper cleanup
local function terminate_dap()
  local dap = require('dap')
  local dapui = require('dapui')

  dap.terminate({}, { terminateDebuggee = true }, function()
    dap.repl.close()
    dapui.close()
    vim.notify("Debug session terminated", vim.log.levels.INFO)
  end)
end

-- Setup global debug keymaps
function M.setup_global_keymaps()
  -- Primary debug keymaps (F-keys)
  vim.keymap.set("n", "<F5>", M.universal_debug_launcher, { desc = "Start/Continue Debugging (Auto-detect)" })
  vim.keymap.set("n", "<F6>", terminate_dap, { desc = "Stop Debugging" })
  vim.keymap.set("n", "<F7>", require('dap').toggle_breakpoint, { desc = "Toggle Breakpoint" })
  vim.keymap.set("n", "<F8>", require('dap').continue, { desc = "Continue" })
  vim.keymap.set("n", "<F9>", require('dap').step_into, { desc = "Step Into" })
  vim.keymap.set("n", "<F10>", require('dap').step_over, { desc = "Step Over" })
  vim.keymap.set("n", "<S-F9>", require('dap').step_out, { desc = "Step Out" })

  -- Leader key alternatives
  vim.keymap.set("n", "<leader>db", require('dap').toggle_breakpoint, { desc = "Toggle Breakpoint" })
  vim.keymap.set("n", "<leader>dc", M.universal_debug_launcher, { desc = "Continue/Start Debugging" })
  vim.keymap.set("n", "<leader>dt", terminate_dap, { desc = "Terminate Debug Session" })
  vim.keymap.set("n", "<leader>di", require('dap').step_into, { desc = "Step Into" })
  vim.keymap.set("n", "<leader>do", require('dap').step_over, { desc = "Step Over" })
  vim.keymap.set("n", "<leader>dO", require('dap').step_out, { desc = "Step Out" })
  vim.keymap.set("n", "<leader>dr", require('dap').repl.toggle, { desc = "Toggle REPL" })
  vim.keymap.set("n", "<leader>du", require('dapui').toggle, { desc = "Toggle DAP UI" })

  -- Advanced debug keymaps
  vim.keymap.set("n", "<leader>dl", require('dap').run_last, { desc = "Run Last Debug Configuration" })
  vim.keymap.set("n", "<leader>dp", require('dap').pause, { desc = "Pause Execution" })
  vim.keymap.set("n", "<leader>dB", function()
    require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))
  end, { desc = "Set Conditional Breakpoint" })
  vim.keymap.set("n", "<leader>dC", require('dap').clear_breakpoints, { desc = "Clear All Breakpoints" })

  -- Platform diagnostic keymaps
  vim.keymap.set("n", "<leader>dpc", platform_config.check_installations,
    { desc = "Check platform installations" })
  vim.keymap.set("n", "<leader>dpi", platform_config.install_missing_tools,
    { desc = "Install missing tools" })

  -- Language-specific debug shortcuts
  vim.keymap.set("n", "<leader>drs", rust_debug.build_and_debug, { desc = "Build & Debug Rust" })

  -- Language environment checks
  vim.keymap.set("n", "<leader>lrc", rust_lsp.check_toolchain, { desc = "Check Rust toolchain" })
end

-- Setup DAP signs for better visual feedback
function M.setup_dap_signs()
  vim.fn.sign_define('DapBreakpoint', {
    text = '🔴',
    texthl = 'DapBreakpoint',
    linehl = '',
    numhl = 'DapBreakpoint'
  })

  vim.fn.sign_define('DapBreakpointCondition', {
    text = '🟡',
    texthl = 'DapBreakpointCondition',
    linehl = '',
    numhl = 'DapBreakpointCondition'
  })

  vim.fn.sign_define('DapBreakpointRejected', {
    text = '❌',
    texthl = 'DapBreakpointRejected',
    linehl = '',
    numhl = 'DapBreakpointRejected'
  })

  vim.fn.sign_define('DapStopped', {
    text = '▶️',
    texthl = 'DapStopped',
    linehl = 'DapStoppedLine',
    numhl = 'DapStopped'
  })

  vim.fn.sign_define('DapLogPoint', {
    text = '📝',
    texthl = 'DapLogPoint',
    linehl = '',
    numhl = 'DapLogPoint'
  })
end

-- Setup autocmds for language-specific configurations
function M.setup_autocmds()
  local augroup = vim.api.nvim_create_augroup("LSPDebugIntegration", { clear = true })

  -- Platform notification on startup
  vim.api.nvim_create_autocmd('VimEnter', {
    group = augroup,
    once = true,
    callback = function()
      vim.notify(string.format(
        "🖥️ Platform detected: %s",
        platform_config.platform
      ), vim.log.levels.INFO)
    end,
  })

  -- Rust file detection and setup
  vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
    group = augroup,
    pattern = '*.rs',
    callback = function()
      rust_debug.ensure_debugger_installed()
    end,
  })

  -- Project detection and notification
  vim.api.nvim_create_autocmd('VimEnter', {
    group = augroup,
    callback = function()
      local cwd = vim.fn.getcwd()
      local notifications = {}

      -- Check for Rust projects
      if vim.fn.filereadable('Cargo.toml') == 1 then
        table.insert(notifications, 'Rust project detected')
      end

      if #notifications > 0 then
        local msg = string.format(
          "[%s] %s. Press F5 to debug!",
          platform_config.platform,
          table.concat(notifications, ', ')
        )
        vim.notify(msg, vim.log.levels.INFO)
      end
    end,
  })
end

-- Main setup function
function M.setup(capabilities)
  -- Setup LSP servers
  M.setup_lsp(capabilities)

  -- Setup debuggers
  M.setup_debuggers()

  -- Setup keymaps
  M.setup_global_keymaps()

  -- Setup DAP signs
  M.setup_dap_signs()

  -- Setup autocmds
  M.setup_autocmds()

  vim.notify(string.format(
    "🚀 Multi-language LSP and Debug setup complete for %s!",
    platform_config.platform
  ), vim.log.levels.INFO)
end

-- Utility function to check all installations
function M.check_all_installations()
  platform_config.check_installations()
end

-- Helper to install missing tools via Mason
function M.install_missing_tools()
  platform_config.install_missing_tools()
end

return M
