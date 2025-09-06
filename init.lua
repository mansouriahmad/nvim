-- Enhanced init.lua
-- Performance monitoring start
local start_time = vim.loop.hrtime()

-- Load core configuration
require 'options'
require 'keymaps'
require 'lazy-bootstrap'
require 'lazy-plugins'
require 'selected-theme'

local project = require("utils.project")

-- Load enhanced utilities
-- local performance = require('utils.performance')
-- local project = require('utils.project')
-- local error_handler = require('utils.error_handler')

-- Setup enhanced features
-- performance.setup()
-- project.setup()
-- error_handler.setup()

-- Windows compatibility: Ensure PowerShell is set as the default shell in plugins/toggleterm.lua
-- Some plugins may require additional setup or dependencies on Windows (see plugin configs)
vim.o.background = "dark"

-- Enhanced line number styling with better colors
vim.api.nvim_set_hl(0, "LineNr", { fg = "#6c7086", bold = false })        -- Subtle gray
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#f38ba8", bold = true })   -- Soft pink/red
vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#585b70" })                 -- Darker gray above
vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#585b70" })                 -- Darker gray below

-- Enhanced diagnostic highlights
vim.api.nvim_set_hl(0, "DiagnosticError", { fg = "#f38ba8" })
vim.api.nvim_set_hl(0, "DiagnosticWarn", { fg = "#fab387" })
vim.api.nvim_set_hl(0, "DiagnosticInfo", { fg = "#89b4fa" })
vim.api.nvim_set_hl(0, "DiagnosticHint", { fg = "#a6e3a1" })

-- Better DAP (debugger) highlights
vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#e78284" })
vim.api.nvim_set_hl(0, "DapStopped", { fg = "#a6e3a1" })
vim.api.nvim_set_hl(0, "DapStoppedLine", { bg = "#414559" })

-- Enhanced welcome message with system info
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local end_time = vim.loop.hrtime()
    local startup_time = (end_time - start_time) / 1000000 -- Convert to ms
    
    -- Only show startup time if it's notable (>50ms)
    if startup_time > 50 then
      vim.notify(string.format("🚀 Neovim loaded in %.2fms", startup_time), vim.log.levels.INFO)
    end
    
    -- Show system info on first load of the day
    local today = os.date("%Y-%m-%d")
    local last_shown_file = vim.fn.stdpath("data") .. "/last_system_info_shown.txt"
    local last_shown = ""
    
    if vim.fn.filereadable(last_shown_file) == 1 then
      local file = io.open(last_shown_file, "r")
      if file then
        last_shown = file:read("*a"):gsub("%s+", "")
        file:close()
      end
    end
    
    if last_shown ~= today then
      vim.defer_fn(function()
        -- System info
        local nvim_version = vim.version()
        local system = vim.loop.os_uname()
        
        local info_lines = {
          string.format("🔥 Neovim %d.%d.%d on %s", nvim_version.major, nvim_version.minor, nvim_version.patch, system.sysname),
        }
        
        -- Add LSP info
        local active_clients = vim.lsp.get_clients()
        if #active_clients > 0 then
          local client_names = {}
          for _, client in ipairs(active_clients) do
            table.insert(client_names, client.name)
          end
          table.insert(info_lines, string.format("🔧 Active LSP: %s", table.concat(client_names, ", ")))
        end
        
        -- Show project info if in a project
        local project_info = project.detect_project_type()
        if project_info.type ~= "Unknown" then
          table.insert(info_lines, string.format("%s Project: %s", project_info.icon, project_info.type))
        end
        
        for _, line in ipairs(info_lines) do
          vim.notify(line, vim.log.levels.INFO)
        end
        
        -- Save that we showed info today
        local file = io.open(last_shown_file, "w")
        if file then
          file:write(today)
          file:close()
        end
      end, 2000) -- Show after 2 seconds
    end
  end,
})

-- Enhanced auto-commands for better workflow
local augroup = vim.api.nvim_create_augroup("EnhancedConfig", { clear = true })

-- Auto-save when losing focus (optional - uncomment if desired)
-- vim.api.nvim_create_autocmd({"FocusLost", "WinLeave"}, {
--   group = augroup,
--   callback = function()
--     if vim.bo.modified and vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
--       vim.cmd("silent! write")
--     end
--   end,
-- })

-- Better session management
vim.api.nvim_create_autocmd("VimLeave", {
  group = augroup,
  callback = function()
    -- Save session for project directories
    local cwd = vim.fn.getcwd()
    local is_project = project.detect_project_type().type ~= "Unknown"
    
    if is_project then
      local session_dir = vim.fn.stdpath("data") .. "/sessions"
      vim.fn.mkdir(session_dir, "p")
      
      local session_name = cwd:gsub("[/\\]", "_"):gsub(":", "")
      local session_file = session_dir .. "/" .. session_name .. ".vim"
      
      vim.cmd("mksession! " .. session_file)
    end
  end,
})

-- Smart session restoration
vim.keymap.set("n", "<leader>Sr", function()
  local cwd = vim.fn.getcwd()
  local session_dir = vim.fn.stdpath("data") .. "/sessions"
  local session_name = cwd:gsub("[/\\]", "_"):gsub(":", "")
  local session_file = session_dir .. "/" .. session_name .. ".vim"
  
  if vim.fn.filereadable(session_file) == 1 then
    vim.cmd("source " .. session_file)
    vim.notify("📂 Session restored for " .. vim.fn.fnamemodify(cwd, ":t"), vim.log.levels.INFO)
  else
    vim.notify("No session found for this project", vim.log.levels.WARN)
  end
end, { desc = "Restore session for current project" })

-- Enhanced keymap documentation
vim.keymap.set("n", "<leader>?", function()
  local keymaps = {
    "🔥 Enhanced Neovim Keymaps",
    "===========================",
    "",
    "📁 Project Management:",
    "  <leader>pi - Show project info",
    "  <leader>pc - Create new project", 
    "  <leader>ps - Switch project",
    "",
    "🚀 Debug & Run:",
    "  <F5> - Start/Continue debugging (auto-detect)",
    "  <F6> - Stop debugging",
    "  <F7> - Toggle breakpoint",
    "  <F8> - Continue",
    "  <F9> - Step into",
    "  <F10> - Step over",
    "",
    "🔧 Development:",
    "  <leader>rb - Build Rust project",
    "  <leader>rr - Run Rust project",
    "",
    "📊 Utilities:",
    "  <leader>pp - Performance report",
    "  <leader>el - Error log",
    "  <leader>th - Theme selector",
    "  <leader>Sr - Restore session",
    "",
    "Press 'q' or <Esc> to close"
  }
  
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, keymaps)
  vim.bo[buf].filetype = "markdown"
  
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#keymaps + 2, vim.o.lines - 4)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    style = "minimal",
    border = "rounded",
    title = " Keymaps Reference ",
    title_pos = "center",
  })
  
  local close_win = function() vim.api.nvim_win_close(win, true) end
  vim.keymap.set("n", "<Esc>", close_win, { buffer = buf })
  vim.keymap.set("n", "q", close_win, { buffer = buf })
end, { desc = "Show enhanced keymaps reference" })

-- Health check command
vim.api.nvim_create_user_command("HealthCheck", function()
  local health_items = {
    "🏥 Neovim Health Check",
    "====================",
    "",
  }
  
  -- Check core components
  local checks = {
    { name = "Git", cmd = "git --version", required = true },
    { name = "Rust", cmd = "rustc --version", lang = "Rust" },
    { name = "Node.js", cmd = "node --version", lang = "JavaScript" },
  }
  
  for _, check in ipairs(checks) do
    local result = vim.fn.system(check.cmd .. " 2>/dev/null")
    if vim.v.shell_error == 0 then
      local version = result:gsub("%s+", "")
      table.insert(health_items, string.format("✅ %s: %s", check.name, version))
    else
      local status = check.required and "❌" or "⚠️"
      local suffix = check.lang and string.format(" (for %s development)", check.lang) or ""
      table.insert(health_items, string.format("%s %s: Not found%s", status, check.name, suffix))
    end
  end
  
  table.insert(health_items, "")
  table.insert(health_items, "Press 'q' or <Esc> to close")
  
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, health_items)
  vim.bo[buf].filetype = "markdown"
  
  local width = math.min(60, vim.o.columns - 4)
  local height = math.min(#health_items + 2, vim.o.lines - 4)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    style = "minimal",
    border = "rounded",
    title = " System Health ",
    title_pos = "center",
  })
  
  local close_win = function() vim.api.nvim_win_close(win, true) end
  vim.keymap.set("n", "<Esc>", close_win, { buffer = buf })
  vim.keymap.set("n", "q", close_win, { buffer = buf })
end, { desc = "Check system health for development tools" })

-- Add health check keymap
vim.keymap.set("n", "<leader>hc", "<cmd>HealthCheck<cr>", { desc = "System health check" })

vim.notify("🎉 Enhanced Neovim configuration loaded!", vim.log.levels.INFO)
