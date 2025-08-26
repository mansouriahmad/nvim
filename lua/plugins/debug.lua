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
      local dapui = require("dapui")
      local persistent_breakpoints = require("persistent-breakpoints")

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
              { id = "scopes", size = 0.33 },
              { id = "breakpoints", size = 0.17 },
              { id = "stacks", size = 0.25 },
              { id = "watches", size = 0.25 },
            },
            size = 0.33,
            position = "right",
          },
          {
            elements = {
              { id = "repl", size = 0.45 },
              { id = "console", size = 0.55 },
            },
            size = 0.27,
            position = "bottom",
          },
        },
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
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      -- codelldb adapter for Rust
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
          args = { "--port", "${port}" },
        },
      }

      -- Python debugger adapter (debugpy)
      dap.adapters.python = {
        type = "executable",
        command = vim.fn.stdpath("data") .. "/mason/bin/debugpy-adapter",
      }

      -- Function to automatically find Rust executable
      local function get_rust_executable()
        local cwd = vim.fn.getcwd()
        local cargo_toml = cwd .. '/Cargo.toml'
        
        -- Check if this is a Rust project
        if vim.fn.filereadable(cargo_toml) == 0 then
          vim.notify('Not a Rust project (no Cargo.toml found)', vim.log.levels.WARN)
          return nil
        end
        
        -- Read Cargo.toml to get package name
        local package_name = nil
        for line in io.lines(cargo_toml) do
          if line:match("^name%s*=%s*[\"']([^\"']+)[\"']") then
            package_name = line:match("^name%s*=%s*[\"']([^\"']+)[\"']")
            break
          end
        end
        
        if not package_name then
          vim.notify('Could not find package name in Cargo.toml', vim.log.levels.WARN)
          return nil
        end
        
        -- Check for binary executable
        local binary_path = cwd .. '/target/debug/' .. package_name
        if vim.fn.filereadable(binary_path) == 1 then
          if vim.fn.executable(binary_path) == 1 then
            return binary_path
          else
            vim.notify('Binary exists but is not executable: ' .. binary_path, vim.log.levels.WARN)
          end
        end
        
        -- Check for release build (macOS common)
        local release_path = cwd .. '/target/release/' .. package_name
        if vim.fn.filereadable(release_path) == 1 then
          if vim.fn.executable(release_path) == 1 then
            return release_path
          end
        end
        
        vim.notify('No executable found. Try running: cargo build', vim.log.levels.WARN)
        return nil
      end

      -- FIXED: Helper function to get the correct Python path (moved up)
      local function get_python_path()
        -- Try to detect virtual environment first
        local venv_paths = {
          vim.fn.getcwd() .. "/.venv/bin/python3",
          vim.fn.getcwd() .. "/.venv/bin/python",
          vim.fn.getcwd() .. "/venv/bin/python3", 
          vim.fn.getcwd() .. "/venv/bin/python",
          vim.fn.getcwd() .. "/env/bin/python3",
          vim.fn.getcwd() .. "/env/bin/python",
          vim.fn.expand("~/.virtualenvs/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t") .. "/bin/python3"),
          vim.fn.expand("~/.virtualenvs/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t") .. "/bin/python"),
        }
        
        for _, python_path in ipairs(venv_paths) do
          if vim.fn.executable(python_path) == 1 then
            return python_path
          end
        end
        
        -- Default to system python3, then python
        if vim.fn.executable("python3") == 1 then
          return "python3"
        elseif vim.fn.executable("python") == 1 then
          return "python"
        else
          vim.notify("Neither 'python3' nor 'python' found in PATH", vim.log.levels.WARN)
          return "python3"  -- fallback
        end
      end

      -- Rust debugging configurations
      dap.configurations.rust = {
        {
          name = "Launch Rust Binary",
          type = "codelldb",
          request = "launch",
          program = function()
            local exe = get_rust_executable()
            if exe then
              return exe
            else
              return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
            end
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          args = {},
        },
      }

      -- FIXED: Python debugging configurations (get_python_path now defined above)
      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch Python File",
          program = "${file}",
          pythonPath = get_python_path,
          console = "integratedTerminal",
          args = {},
        },
        {
          type = "python",
          request = "launch", 
          name = "Launch Python Module",
          module = function()
            return vim.fn.input("Module name: ")
          end,
          pythonPath = get_python_path,
          console = "integratedTerminal",
        },
        {
          type = "python",
          request = "launch",
          name = "Debug Django",
          program = vim.fn.getcwd() .. "/manage.py",
          args = { "runserver", "--noreload" },
          pythonPath = get_python_path,
          console = "integratedTerminal",
        },
        {
          type = "python",
          request = "launch",
          name = "Debug Flask",
          program = "${file}",
          env = {
            FLASK_ENV = "development",
            FLASK_DEBUG = "1",
          },
          pythonPath = get_python_path,
          console = "integratedTerminal",
        },
        {
          type = "python",
          request = "launch",
          name = "Debug pytest",
          module = "pytest",
          args = { "${file}" },
          pythonPath = get_python_path,
          console = "integratedTerminal",
        },
      }

      -- Function to launch debugger based on filetype (for F5)
      local function launch_debugger()
        local filetype = vim.bo.filetype
        local dap = require('dap')
        
        if filetype == 'rust' then
            vim.notify('Building Rust project...', vim.log.levels.INFO)
            vim.fn.jobstart({'cargo', 'build'}, {
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
        elseif filetype == 'python' then
            vim.notify('Launching Python debugger...', vim.log.levels.INFO)
            -- Use the first Python configuration (Launch Python File)
            dap.run(dap.configurations.python[1])
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
      vim.keymap.set("n", "<F7>", dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })
      vim.keymap.set("n", "<F5>", launch_debugger, { desc = "Start/Continue Debugging (Auto-Build & Auto-Detect)" })
      vim.keymap.set("n", "<F1>", dap.step_into, { desc = "Step Into" })
      vim.keymap.set("n", "<F8>", dap.step_over, { desc = "Step Over" })
      vim.keymap.set("n", "<F2>", dap.step_out, { desc = "Step Out" })
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

      -- Check and install codelldb if not present
      local function check_and_install_codelldb()
        local codelldb_path = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
        if vim.fn.executable(codelldb_path) == 0 then
          vim.notify("codelldb not found. Installing via Mason...", vim.log.levels.WARN)
          vim.cmd("MasonInstall codelldb")
        end
      end

      -- Check and install Python debugger if not present
      local function check_and_install_python_debug()
        local debugpy_path = vim.fn.stdpath("data") .. "/mason/bin/debugpy-adapter"
        if vim.fn.executable(debugpy_path) == 0 then
          vim.notify("debugpy not found. Installing via Mason...", vim.log.levels.WARN)
          vim.cmd("MasonInstall debugpy")
        end
      end

      -- Auto-install debuggers when opening relevant files
      vim.api.nvim_create_autocmd("BufReadPost", {
        group = vim.api.nvim_create_augroup("DapSetup", { clear = true }),
        pattern = { "*.rs", "*.py" },
        callback = function()
          local filetype = vim.bo.filetype
          if filetype == "rust" then
            check_and_install_codelldb()
          elseif filetype == "python" then
            check_and_install_python_debug()
          end
        end,
      })

    end,
  },
}