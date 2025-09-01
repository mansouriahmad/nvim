-- lua/utils/performance.lua
local M = {}

-- Startup time monitoring
local start_time = vim.loop.hrtime()

-- Performance tracking
local performance_data = {
  startup_time = nil,
  lsp_attach_times = {},
  plugin_load_times = {},
  large_file_threshold = 1024 * 1024, -- 1MB
}

-- Measure startup time
function M.measure_startup()
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      local end_time = vim.loop.hrtime()
      performance_data.startup_time = (end_time - start_time) / 1000000 -- Convert to ms
      
      -- Only show if startup is slow
      if performance_data.startup_time > 100 then
        vim.notify(string.format("⏱️ Startup time: %.2fms", performance_data.startup_time), vim.log.levels.WARN)
      end
    end,
  })
end

-- Monitor LSP attach performance
function M.monitor_lsp_attach()
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then
        local attach_time = vim.loop.hrtime()
        performance_data.lsp_attach_times[client.name] = attach_time
        
        -- Show notification for slow LSP servers
        vim.defer_fn(function()
          local current_time = vim.loop.hrtime()
          local duration = (current_time - attach_time) / 1000000
          if duration > 1000 then -- More than 1 second
            vim.notify(string.format("🐌 %s took %.2fms to attach", client.name, duration), vim.log.levels.WARN)
          end
        end, 1000)
      end
    end,
  })
end

-- Disable features for large files
function M.optimize_large_files()
  vim.api.nvim_create_autocmd("BufReadPre", {
    callback = function(args)
      local file = args.file
      local ok, stats = pcall(vim.loop.fs_stat, file)
      
      if ok and stats and stats.size > performance_data.large_file_threshold then
        vim.notify(string.format("📄 Large file detected (%.2f MB) - optimizing...", stats.size / 1024 / 1024), vim.log.levels.INFO)
        
        -- Disable expensive features for large files
        vim.opt_local.foldmethod = "manual"
        vim.opt_local.undofile = false
        vim.opt_local.swapfile = false
        vim.opt_local.syntax = "off"
        
        -- Disable treesitter for this buffer
        vim.defer_fn(function()
          if vim.treesitter.highlighter.active[args.buf] then
            vim.treesitter.stop(args.buf)
          end
        end, 100)
        
        -- Disable LSP for extremely large files (>10MB)
        if stats.size > (10 * 1024 * 1024) then
          vim.defer_fn(function()
            vim.lsp.stop_client(vim.lsp.get_active_clients({ bufnr = args.buf }))
          end, 100)
        end
      end
    end,
  })
end

-- Memory usage monitoring
function M.monitor_memory()
  local function check_memory()
    local mem = vim.loop.resident_set_memory() / 1024 / 1024 -- Convert to MB
    if mem > 500 then -- More than 500MB
      vim.notify(string.format("🧠 High memory usage: %.2f MB", mem), vim.log.levels.WARN)
    end
  end
  
  -- Check memory every 5 minutes
  local timer = vim.loop.new_timer()
  timer:start(300000, 300000, vim.schedule_wrap(check_memory))
end

-- Performance report
function M.show_performance_report()
  local report = {
    "🚀 Neovim Performance Report",
    "================================",
    "",
  }
  
  if performance_data.startup_time then
    table.insert(report, string.format("⏱️ Startup time: %.2fms", performance_data.startup_time))
  end
  
  local mem = vim.loop.resident_set_memory() / 1024 / 1024
  table.insert(report, string.format("🧠 Memory usage: %.2f MB", mem))
  
  table.insert(report, "")
  table.insert(report, "🔌 LSP Servers:")
  for client_name, _ in pairs(performance_data.lsp_attach_times) do
    table.insert(report, "  • " .. client_name)
  end
  
  -- Show in a floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, report)
  
  local width = math.max(40, math.min(80, vim.o.columns - 10))
  local height = math.min(#report + 2, vim.o.lines - 10)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    style = "minimal",
    border = "rounded",
    title = " Performance Report ",
    title_pos = "center",
  })
  
  -- Close on escape or q
  vim.keymap.set("n", "<Esc>", function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
  vim.keymap.set("n", "q", function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
end

-- Initialize all performance monitoring
function M.setup()
  M.measure_startup()
  M.monitor_lsp_attach()
  M.optimize_large_files()
  M.monitor_memory()
  
  -- Add command to show performance report
  vim.api.nvim_create_user_command("PerformanceReport", M.show_performance_report, {})
  
  -- Add keymap
  vim.keymap.set("n", "<leader>pp", M.show_performance_report, { desc = "Show performance report" })
end

return M
