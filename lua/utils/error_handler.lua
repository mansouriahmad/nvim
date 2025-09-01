-- lua/utils/error_handler.lua
local M = {}

-- Error categories
local ERROR_CATEGORIES = {
  LSP = "🔧 LSP",
  DEBUG = "🐛 Debug",
  BUILD = "🔨 Build",
  GIT = "🌿 Git", 
  FILE = "📁 File",
  PLUGIN = "🔌 Plugin",
  SYSTEM = "⚙️ System",
}

-- Store recent errors for debugging
local recent_errors = {}
local max_stored_errors = 50

-- Enhanced notification with better formatting
local function notify_with_category(message, level, category)
  local icon = ERROR_CATEGORIES[category] or "ℹ️"
  local formatted_message = string.format("%s %s", icon, message)
  
  -- Store error for later review
  table.insert(recent_errors, {
    timestamp = os.date("%H:%M:%S"),
    category = category,
    message = message,
    level = level,
  })
  
  -- Keep only recent errors
  if #recent_errors > max_stored_errors then
    table.remove(recent_errors, 1)
  end
  
  vim.notify(formatted_message, level)
end

-- Enhanced LSP error handling
function M.setup_lsp_error_handling()
  -- Override LSP error handler
  local original_handler = vim.lsp.handlers["window/showMessage"]
  vim.lsp.handlers["window/showMessage"] = function(err, method, params, client_id)
    local client = vim.lsp.get_client_by_id(client_id)
    local client_name = client and client.name or "Unknown LSP"
    
    local level_map = {
      [1] = vim.log.levels.ERROR,
      [2] = vim.log.levels.WARN,
      [3] = vim.log.levels.INFO,
      [4] = vim.log.levels.DEBUG,
    }
    
    local level = level_map[params.type] or vim.log.levels.INFO
    local message = string.format("[%s] %s", client_name, params.message)
    
    notify_with_category(message, level, "LSP")
    
    -- Call original handler if it exists
    if original_handler then
      return original_handler(err, method, params, client_id)
    end
  end
  
  -- Better LSP diagnostic display
  vim.diagnostic.config({
    virtual_text = {
      prefix = "●",
      source = "if_many",
      format = function(diagnostic)
        local source = diagnostic.source and string.format("[%s] ", diagnostic.source) or ""
        return string.format("%s%s", source, diagnostic.message)
      end,
    },
    float = {
      source = "always",
      border = "rounded",
      header = "",
      prefix = function(diagnostic, i, total)
        local icon = "●"
        if diagnostic.severity == vim.diagnostic.severity.ERROR then
          icon = " "
        elseif diagnostic.severity == vim.diagnostic.severity.WARN then
          icon = " "
        elseif diagnostic.severity == vim.diagnostic.severity.INFO then
          icon = " "
        elseif diagnostic.severity == vim.diagnostic.severity.HINT then
          icon = "󰠠 "
        end
        return string.format("%s ", icon)
      end,
    },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = " ",
        [vim.diagnostic.severity.WARN] = " ",
        [vim.diagnostic.severity.INFO] = " ",
        [vim.diagnostic.severity.HINT] = "󰠠 ",
      },
    },
  })
end

-- Debug session error handling
function M.setup_debug_error_handling()
  local dap = require("dap")
  
  -- Enhanced DAP error messages
  dap.listeners.after.event_output["error_handler"] = function(session, body)
    if body.category == "stderr" then
      notify_with_category(body.output, vim.log.levels.ERROR, "DEBUG")
    end
  end
  
  -- Better breakpoint error handling
  dap.listeners.after.event_breakpoint["error_handler"] = function(session, body)
    if body.reason == "changed" and body.breakpoint then
      local bp = body.breakpoint
      if not bp.verified then
        notify_with_category(
          string.format("Breakpoint not verified: %s:%d", bp.source and bp.source.name or "unknown", bp.line),
          vim.log.levels.WARN,
          "DEBUG"
        )
      end
    end
  end

  -- Notify when a debug session ends
  dap.listeners.after.event_terminated["session_ended_notifier"] = function()
    notify_with_category("Debug session ended.", vim.log.levels.INFO, "DEBUG")
  end
end

-- Build process error handling with better parsing
function M.handle_build_output(data, project_type)
  if not data then return end
  
  for _, line in ipairs(data) do
    if line and line ~= "" then
      -- Parse different build error formats
      local error_patterns = {
        -- C# errors
        { pattern = "([^%(]+)%((%d+),(%d+)%):%s*error%s*([^:]+):%s*(.+)", lang = "csharp" },
        -- Rust errors
        -- { pattern = "error%[E%d+%]:%s*(.+)", lang = "rust" }, -- rust-analyzer handles this
        -- { pattern = "%-%->", lang = "rust" }, -- rust-analyzer handles this
        -- Python errors
        { pattern = "Traceback", lang = "python" },
        -- General patterns
        { pattern = "error:", lang = "general" },
        { pattern = "Error:", lang = "general" },
        { pattern = "ERROR:", lang = "general" },
      }
      local is_error = false
      for _, pattern_info in ipairs(error_patterns) do
        if line:match(pattern_info.pattern) then
          notify_with_category(line, vim.log.levels.ERROR, "BUILD")
          is_error = true
          break
        end
      end
      
      -- Check for warnings
      if not is_error then
        local warning_patterns = {
          "warning:",
          "Warning:",
          "WARN:",
        }
        
        for _, pattern in ipairs(warning_patterns) do
          if line:match(pattern) then
            notify_with_category(line, vim.log.levels.WARN, "BUILD")
            break
          end
        end
      end
    end
  end
end

-- Git error handling
function M.setup_git_error_handling()
  -- Override git commands to provide better error messages
  local function enhanced_git_command(cmd)
    local handle = io.popen(cmd .. " 2>&1")
    if not handle then
      notify_with_category("Failed to execute git command", vim.log.levels.ERROR, "GIT")
      return nil
    end
    
    local result = handle:read("*a")
    local success = handle:close()
    
    if not success and result then
      -- Parse common git errors
      if result:match("not a git repository") then
        notify_with_category("Not in a git repository", vim.log.levels.WARN, "GIT")
      elseif result:match("nothing to commit") then
        notify_with_category("Nothing to commit, working tree clean", vim.log.levels.INFO, "GIT")
      else
        notify_with_category(result, vim.log.levels.ERROR, "GIT")
      end
    end
    
    return result
  end
  
  -- Add git status checking
  vim.keymap.set("n", "<leader>gs", function()
    enhanced_git_command("git status --porcelain")
  end, { desc = "Git status with error handling" })
end

-- File operation error handling
function M.setup_file_error_handling()
  -- Enhanced file operations
  vim.api.nvim_create_autocmd("BufWritePre", {
    callback = function(args)
      local file = args.file
      
      -- Check if file is writable
      if vim.fn.filewritable(file) == 0 and vim.fn.filereadable(file) == 1 then
        notify_with_category(
          string.format("File is read-only: %s", vim.fn.fnamemodify(file, ":t")),
          vim.log.levels.WARN,
          "FILE"
        )
      end
      
      -- Check disk space (Unix-like systems)
      if vim.fn.has("unix") == 1 then
        local df_output = vim.fn.system("df -h . | tail -1")
        local usage = df_output:match("(%d+)%%")
        if usage and tonumber(usage) > 95 then
          notify_with_category(
            string.format("Disk space critically low: %s%% used", usage),
            vim.log.levels.ERROR,
            "FILE"
          )
        end
      end
    end,
  })
  
  -- Handle file not found errors
  vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function(args)
      if vim.api.nvim_buf_is_loaded(args.buf) and vim.api.nvim_buf_get_name(args.buf) ~= "" and vim.bo[args.buf].buftype == "" and vim.fn.filereadable(args.file) == 0 then
        notify_with_category(
          string.format("File not found: %s", vim.fn.fnamemodify(args.file, ":t")),
          vim.log.levels.ERROR,
          "FILE"
        )
      end
    end,
  })
end

-- Show recent errors in a floating window
function M.show_error_log()
  if #recent_errors == 0 then
    vim.notify("No recent errors to display", vim.log.levels.INFO)
    return
  end
  
  local lines = { "Recent Errors and Messages:", "=" }
  
  for _, error in ipairs(recent_errors) do
    local level_icon = ""
    if error.level == vim.log.levels.ERROR then
      level_icon = " "
    elseif error.level == vim.log.levels.WARN then
      level_icon = " "
    elseif error.level == vim.log.levels.INFO then
      level_icon = " "
    end
    
    table.insert(lines, string.format("[%s] %s%s %s", 
      error.timestamp, 
      level_icon, 
      error.category, 
      error.message
    ))
  end
  
  table.insert(lines, "")
  table.insert(lines, "Press 'c' to clear, 'q' or <Esc> to close")
  
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "log"
  
  local width = math.min(120, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 6)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    style = "minimal",
    border = "rounded",
    title = " Error Log ",
    title_pos = "center",
  })
  
  -- Keymaps for the error log window
  local function close_win() vim.api.nvim_win_close(win, true) end
  local function clear_errors()
    recent_errors = {}
    vim.api.nvim_win_close(win, true)
    vim.notify("Error log cleared", vim.log.levels.INFO)
  end
  
  vim.keymap.set("n", "<Esc>", close_win, { buffer = buf })
  vim.keymap.set("n", "q", close_win, { buffer = buf })
  vim.keymap.set("n", "c", clear_errors, { buffer = buf })
end

-- Setup all error handling
function M.setup()
  M.setup_lsp_error_handling()
  
  -- Only setup debug error handling if DAP is available
  local has_dap = pcall(require, "dap")
  if has_dap then
    M.setup_debug_error_handling()
  end
  
  M.setup_git_error_handling()
  M.setup_file_error_handling()
  
  -- Create commands
  vim.api.nvim_create_user_command("ErrorLog", M.show_error_log, {})
  vim.api.nvim_create_user_command("ClearErrors", function()
    recent_errors = {}
    vim.notify("Error log cleared", vim.log.levels.INFO)
  end, {})
  
  -- Keymaps
  vim.keymap.set("n", "<leader>el", M.show_error_log, { desc = "Show error log" })
  vim.keymap.set("n", "<leader>ec", function()
    recent_errors = {}
    vim.notify("Error log cleared", vim.log.levels.INFO)
  end, { desc = "Clear error log" })
end

-- Export the notify function for use by other modules
M.notify = notify_with_category

return M
