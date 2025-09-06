return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "williamboman/mason.nvim",
      "nvim-neotest/nvim-nio",
      "Weissle/persistent-breakpoints.nvim",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      local persistent_breakpoints = require("persistent-breakpoints")
      local debug_rust = require("configs.debug.rust")
      -- local debug_python = require("configs.debug.python")
      -- local debug_csharp = require("configs.debug.csharp")

      persistent_breakpoints.setup({
        -- You can customize the directory where breakpoints are saved.
        -- By default, it uses vim.fn.stdpath("data") .. "/persistent_breakpoints/"
        -- To save per project, it will automatically use the current working directory as part of the path.
        save_dir = vim.fn.stdpath("data") .. "/persistent_breakpoints/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t"),
        load_breakpoints_event = { "BufReadPost" },
      })

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

      -- Custom breakpoint signs for better clarity (moved from lsp.lua)
      vim.fn.sign_define('DapBreakpoint', {
        text = '🔴', -- Red circle for breakpoint
        texthl = 'DapBreakpoint',
        linehl = '',
        numhl = 'DapBreakpoint'
      })

      vim.fn.sign_define('DapBreakpointCondition', {
        text = '🟡', -- Yellow circle for conditional breakpoint
        texthl = 'DapBreakpointCondition',
        linehl = '',
        numhl = 'DapBreakpointCondition'
      })

      vim.fn.sign_define('DapBreakpointRejected', {
        text = '❌', -- X for rejected/invalid breakpoint
        texthl = 'DapBreakpointRejected',
        linehl = '',
        numhl = 'DapBreakpointRejected'
      })

      vim.fn.sign_define('DapStopped', {
        text = '▶️', -- Play button for current execution point
        texthl = 'DapStopped',
        linehl = 'DapStoppedLine',
        numhl = 'DapStopped'
      })

      vim.fn.sign_define('DapLogPoint', {
        text = '📝', -- Note for log points
        texthl = 'DapLogPoint',
        linehl = '',
        numhl = 'DapLogPoint'
      })

      -- Automatically open DAP UI when debugging starts
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
        vim.notify("Debug session completed", vim.log.levels.INFO)
      end
      -- dap.listeners.before.event_exited.dapui_config = function()
      --   dapui.close()
      --   vim.notify("Debug session completed", vim.log.levels.INFO)
      -- end

      -- codelldb adapter for Rust
      debug_rust.setup_adapter(dap)

      -- Python debugger adapter (debugpy)
      -- debug_python.setup_adapter(dap)

      -- C# debugger adapter (netcoredbg)
      -- debug_csharp.setup_adapter(dap)

      -- Function to automatically find Rust executable
      local get_rust_executable = debug_rust.get_rust_executable

      -- FIXED: Helper function to get the correct Python path (moved up)
      -- local get_python_path = debug_python.get_python_path

      -- Helper function to find C# executable and project info
      -- local get_csharp_debug_info = debug_csharp.get_csharp_debug_info

      -- local build_csharp_project = debug_csharp.build_csharp_project

      -- C# debugging configurations
      -- debug_csharp.setup_configurations(dap, get_csharp_debug_info)

      -- Rust debugging configurations
      debug_rust.setup_configurations(dap, get_rust_executable)

      -- FIXED: Python debugging configurations (get_python_path now defined above)
      -- debug_python.setup_configurations(dap, get_python_path)

      -- Function to launch debugger based on filetype (for F5)
      local function launch_debugger()
        local filetype = vim.bo.filetype
        local dap = require('dap')

        if filetype == 'rust' then
          vim.notify('Building Rust project...', vim.log.levels.INFO)
          vim.fn.jobstart({ 'cargo', 'build' }, {
            on_exit = function(_, code)
              if code == 0 then
                vim.notify('Build successful! Launching debugger...', vim.log.levels.INFO)
                vim.schedule(function()
                  local exe = get_rust_executable()
                  if exe then
                    dap.run({
                      name = "Launch Rust Binary",
                      type = "codelldb",
                      request = "launch",
                      program = exe,
                      cwd = '${workspaceFolder}',
                      stopOnEntry = false,
                      args = {},
                      initCommands = (function()
                        local sysroot = vim.fn.system("rustc --print sysroot"):gsub("%s+$", "")
                        local script = sysroot .. "/lib/rustlib/etc/lldb_lookup.py"
                        return { "command script import " .. script }
                      end)(),
                    })
                  else
                    vim.notify('No Rust executable found after build.', vim.log.levels.ERROR)
                  end
                end)
              else
                vim.notify('Build failed! Check errors and try again.', vim.log.levels.ERROR)
              end
            end
          })
        -- elseif filetype == 'python' then
        --   vim.notify('Launching Python debugger...', vim.log.levels.INFO)
        --   -- Use the first Python configuration (Launch Python File)
        --   dap.run(dap.configurations.python[1])
        -- elseif filetype == 'cs' or filetype == 'csharp' then
        --   local project_info = get_csharp_debug_info()
        --   if not project_info then
        --     vim.notify('No C# project found in workspace', vim.log.levels.ERROR)
        --     return
        --   end

        --   vim.notify('Building and launching C# debugger...', vim.log.levels.INFO)
        --   build_csharp_project(project_info, function(success)
        --     if success then
        --       vim.schedule(function()
        --         -- Refresh project info to get updated dll path
        --         local updated_info = get_csharp_debug_info()
        --         if updated_info and updated_info.dll_path and vim.fn.filereadable(updated_info.dll_path) == 1 then
        --           dap.run({
        --             type = "coreclr",
        --             name = "Launch C# Application",
        --             request = "launch",
        --             program = updated_info.dll_path,
        --             cwd = updated_info.project_dir,
        --             console = "integratedTerminal",
        --             args = {},
        --           })
        --         else
        --           vim.notify('Built successfully but could not find executable', vim.log.levels.ERROR)
        --         end
        --       end)
        --     end
        --   end)
        else
          vim.notify('No automatic debug configuration for ' .. filetype, vim.log.levels.INFO)
          dap.continue() -- Fallback to continue if not Rust or Python
        end
      end

      -- Better terminate function that ensures proper cleanup
      local function terminate_dap()
        dap.terminate({}, { terminateDebuggee = true }, function()
          dap.repl.close()
          dapui.close()
          vim.notify("Debug session terminated", vim.log.levels.INFO)
        end)
      end

      -- Mac-friendly F-key mappings for debugging
      vim.keymap.set("n", "<F5>", launch_debugger, { desc = "Start/Continue Debugging (Auto-Build & Auto-Detect)" })
      vim.keymap.set("n", "<F7>", dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })
      vim.keymap.set("n", "<F8>", dap.continue, { desc = "Continue Debugging" })
      vim.keymap.set("n", "<F9>", dap.step_into, { desc = "Step Into" })
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Step Over" })
      vim.keymap.set("n", "<S-F9>", dap.step_out, { desc = "Step Out" })
      vim.keymap.set("n", "<F6>", terminate_dap, { desc = "Stop Debugging" })

      -- Leader key alternatives for debugging
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })
      vim.keymap.set("n", "<leader>dc", launch_debugger, { desc = "Continue/Start Debugging" })
      vim.keymap.set("n", "<leader>dt", terminate_dap, { desc = "Terminate Debug Session" })
      vim.keymap.set("n", "<leader>dj", dap.step_over, { desc = "Step Over" })
      vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Step Into" })
      vim.keymap.set("n", "<leader>do", dap.step_out, { desc = "Step Out" })
      vim.keymap.set("n", "<leader>dr", dap.repl.toggle, { desc = "Toggle REPL" })
      vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Toggle DAP UI" })

      -- Additional useful debug keymaps
      vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Run Last Debug Configuration" })
      vim.keymap.set("n", "<leader>dp", dap.pause, { desc = "Pause Execution" })
      vim.keymap.set("n", "<leader>dB", function()
        dap.set_breakpoint(vim.fn.input('Breakpoint condition: '))
      end, { desc = "Set Conditional Breakpoint" })
      vim.keymap.set("n", "<leader>dC", dap.clear_breakpoints, { desc = "Clear All Breakpoints" })

      -- Auto-install debuggers when opening relevant files
      vim.api.nvim_create_autocmd("BufReadPost", {
        group = vim.api.nvim_create_augroup("DapSetup", { clear = true }),
        pattern = { "*.rs" },
        callback = function()
          local filetype = vim.bo.filetype
          if filetype == "rust" then
            debug_rust.check_and_install_debugger()
          -- elseif filetype == "python" then
          --   debug_python.check_and_install_debugger()
          -- elseif filetype == "cs" or filetype == "csharp" then
          --   debug_csharp.check_and_install_debugger()
          end
        end,
      })
    end,
  },
}
