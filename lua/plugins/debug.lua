-- lua/plugins/debug.lua (Updated to use modular language configs)

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "williamboman/mason.nvim",
      "nvim-neotest/nvim-nio",
      "Weissle/persistent-breakpoints.nvim",
      "mfussenegger/nvim-dap-python",
    },
    config = function()
      local dap = require("dap")
      local persistent_breakpoints = require("persistent-breakpoints")

      -- Enable DAP verbose logging for debugging issues
      dap.set_log_level("DEBUG")

      -- Setup persistent breakpoints
      persistent_breakpoints.setup({
        save_dir = vim.fn.stdpath("data") .. "/persistent_breakpoints/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t"),
        load_breakpoints_event = { "BufReadPost" },
      })

      -- Load the integrated language configurations
      -- This replaces all the individual language setup that was previously in this file
      local integration = require('configs.lsp_debug_integration')
      
      -- The integration.setup() call in the LSP plugin already handles debugger setup,
      -- but we can call it here too to ensure debuggers are configured even if LSP isn't loaded yet
      pcall(function()
        integration.setup_debuggers()
      end)

      -- Setup additional keymaps for convenience
      vim.keymap.set("n", "<leader>dcc", function()
        integration.check_all_installations()
      end, { desc = "Check all language installations" })
      
      vim.keymap.set("n", "<leader>dim", function()
        integration.install_missing_tools()
      end, { desc = "Install missing tools via Mason" })

      -- Enhanced DAP listeners for better debugging experience
      dap.listeners.after.event_initialized["debug-session-start"] = function()
        vim.notify("🚀 Debug session started", vim.log.levels.INFO)
      end

      dap.listeners.before.event_terminated["debug-session-end"] = function()
        vim.notify("🛑 Debug session terminated", vim.log.levels.INFO)
      end

      dap.listeners.before.event_exited["debug-session-end"] = function()
        vim.notify("✅ Debug session exited", vim.log.levels.INFO)
      end

      -- Auto-setup breakpoint persistence for each language
      vim.api.nvim_create_autocmd("BufReadPost", {
        group = vim.api.nvim_create_augroup("DapSetup", { clear = true }),
        pattern = { "*.rs", "*.py", "*.cs" },
        callback = function()
          -- Load persistent breakpoints for this file
          persistent_breakpoints.load_breakpoints_for_current_buffer()
        end,
      })

      -- Language-specific debug session notifications
      dap.listeners.after.event_stopped["language-specific-notification"] = function(session)
        local filetype = vim.bo.filetype
        local language_icons = {
          rust = "🦀",
          python = "🐍", 
          cs = "⚡",
          csharp = "⚡"
        }
        
        local icon = language_icons[filetype] or "🔍"
        vim.notify(icon .. " Breakpoint hit in " .. (filetype or "unknown") .. " code", vim.log.levels.INFO)
      end
    end,
  },
}