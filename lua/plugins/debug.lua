return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "williamboman/mason.nvim",
      "nvim-neotest/nvim-nio",
      "Weissle/persistent-breakpoints.nvim",
      "mfussenegger/nvim-dap-python",
      { "Decodetalkers/csharpls-extended-lsp.nvim", lazy = true },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      local persistent_breakpoints = require("persistent-breakpoints")

      persistent_breakpoints.setup({
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

      -- Helper function to get the correct Python path
      local function get_python_path()
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

        if vim.fn.executable("python3") == 1 then
          return "python3"
        elseif vim.fn.executable("python") == 1 then
          return "python"
        else
          vim.notify("Neither 'python3' nor 'python' found in PATH", vim.log.levels.WARN)
          return "python3"
        end
      end

      -- Function to automatically find Rust executable
      local function get_rust_executable()
        local cwd = vim.fn.getcwd()
        local cargo_toml = cwd .. '/Cargo.toml'

        if vim.fn.filereadable(cargo_toml) == 0 then
          vim.notify('Not a Rust project (no Cargo.toml found)', vim.log.levels.WARN)
          return nil
        end

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

        local binary_path = cwd .. '/target/debug/' .. package_name
        if vim.fn.filereadable(binary_path) == 1 then
          if vim.fn.executable(binary_path) == 1 then
            return binary_path
          else
            vim.notify('Binary exists but is not executable: ' .. binary_path, vim.log.levels.WARN)
          end
        end

        local release_path = cwd .. '/target/release/' .. package_name
        if vim.fn.filereadable(release_path) == 1 then
          if vim.fn.executable(release_path) == 1 then
            return release_path
          end
        end

        vim.notify('No executable found. Try running: cargo build', vim.log.levels.WARN)
        return nil
      end

      -- Helper function to find C# executable and project info
      local function get_csharp_debug_info()
        local cwd = vim.fn.getcwd()

        if vim.fn.executable("dotnet") == 0 then
          vim.notify("dotnet CLI not found in PATH", vim.log.levels.ERROR)
          return nil
        end

        local sln_files = vim.fn.glob(cwd .. "/*.sln", false, true)
        local csproj_files = vim.fn.glob(cwd .. "/**/*.csproj", false, true)

        local project_file = nil
        local project_name = nil
        local project_dir = cwd

        if #sln_files > 0 then
          project_file = sln_files[1]
          project_name = vim.fn.fnamemodify(project_file, ":t:r")

          for _, csproj in ipairs(csproj_files) do
            local content = vim.fn.readfile(csproj)
            for _, line in ipairs(content) do
              if line:match("Exe") or line:match("Microsoft%.AspNetCore%.App") then
                project_file = csproj
                project_name = vim.fn.fnamemodify(csproj, ":t:r")
                project_dir = vim.fn.fnamemodify(csproj, ":h")
                break
              end
            end
          end
        elseif #csproj_files > 0 then
          project_file = csproj_files[1]
          project_name = vim.fn.fnamemodify(project_file, ":t:r")
          project_dir = vim.fn.fnamemodify(project_file, ":h")
        else
          vim.notify("No .sln or .csproj files found", vim.log.levels.WARN)
          return nil
        end

        local debug_dir = project_dir .. "/bin/Debug"
        local possible_dlls = vim.fn.glob(debug_dir .. "/**/" .. project_name .. ".dll", false, true)

        local dll_path = nil
        if #possible_dlls > 0 then
          table.sort(possible_dlls, function(a, b)
            return vim.fn.getftime(a) > vim.fn.getftime(b)
          end)
          dll_path = possible_dlls[1]
        end

        return {
          project_file = project_file,
          project_name = project_name,
          project_dir = project_dir,
          dll_path = dll_path,
          cwd = cwd
        }
      end

      local function build_csharp_project(project_info, callback)
        if not project_info then
          vim.notify("No C# project found", vim.log.levels.ERROR)
          return
        end

        vim.notify("Building C# project: " .. project_info.project_name, vim.log.levels.INFO)

        vim.fn.jobstart({ "dotnet", "build", project_info.project_file, "--configuration", "Debug" }, {
          cwd = project_info.project_dir,
          on_exit = function(_, code)
            if code == 0 then
              vim.notify("Build successful!", vim.log.levels.INFO)
              if callback then
                callback(true)
              end
            else
              vim.notify("Build failed with exit code: " .. code, vim.log.levels.ERROR)
              if callback then
                callback(false)
              end
            end
          end,
          on_stdout = function(_, data)
            if data then
              for _, line in ipairs(data) do
                if line and line ~= "" then
                  vim.notify("Build: " .. line, vim.log.levels.INFO)
                end
              end
            end
          end,
          on_stderr = function(_, data)
            if data then
              for _, line in ipairs(data) do
                if line and line ~= "" then
                  vim.notify("Build Error: " .. line, vim.log.levels.ERROR)
                end
              end
            end
          end
        })
      end

      -- Enhanced cross-platform C# debugger setup function
      local function setup_csharp_debugger()
        -- Platform detection with multiple fallbacks
        local function detect_platform()
          if jit then
            return jit.os
          elseif vim.fn.has("win64") == 1 or vim.fn.has("win32") == 1 then
            return "Windows"
          elseif vim.fn.has("macunix") == 1 then
            return "OSX"
          else
            return "Linux"
          end
        end
        
        -- Enhanced debugger path resolution
        local function find_debugger_executable(debugger_name)
          -- Strategy 1: Check Mason installation first
          local mason_path = vim.fn.stdpath("data") .. "/mason/bin/" .. debugger_name
          local platform = detect_platform()
          if platform == "Windows" then
            mason_path = mason_path .. ".exe"
          end
          
          if vim.fn.executable(mason_path) == 1 then
            return mason_path
          end
          
          -- Strategy 2: Check PATH
          local path_exe = vim.fn.exepath(debugger_name)
          if path_exe ~= '' then
            return path_exe
          end
          
          -- Strategy 3: Common system paths
          local common_paths = {
            "/usr/local/bin/" .. debugger_name,
            "/usr/bin/" .. debugger_name,
            "/opt/homebrew/bin/" .. debugger_name, -- macOS Homebrew
          }
          
          for _, path in ipairs(common_paths) do
            if vim.fn.executable(path) == 1 then
              return path
            end
          end
          
          return nil
        end
        
        -- Cross-platform debugger selection with preferences
        local function select_csharp_debugger()
          local platform = detect_platform()
          local preferences = {}
          
          if platform == "Windows" then
            preferences = { "netcoredbg", "codelldb" }
          else -- macOS and Linux
            preferences = { "netcoredbg" }
          end
          
          -- Try preferred debuggers in order
          for _, debugger in ipairs(preferences) do
            local path = find_debugger_executable(debugger)
            if path then
              return {
                name = debugger,
                path = path,
                args = debugger == "netcoredbg" and { '--interpreter=vscode' } or { "--port", "${port}" },
                type = debugger == "netcoredbg" and "executable" or "server"
              }
            end
          end
          
          return nil
        end
        
        -- Setup the debugger
        local selected_debugger = select_csharp_debugger()
        
        if not selected_debugger then
          vim.notify(
            "No C# debugger found. Install via :MasonInstall netcoredbg",
            vim.log.levels.WARN
          )
          return false
        end
        
        vim.notify(
          string.format("Using C# debugger: %s at %s", selected_debugger.name, selected_debugger.path),
          vim.log.levels.INFO
        )
        
        -- Configure the adapter based on debugger type
        local adapter_config
        if selected_debugger.type == "executable" then
          adapter_config = {
            type = 'executable',
            command = selected_debugger.path,
            args = selected_debugger.args,
          }
        else
          adapter_config = {
            type = "server",
            port = "${port}",
            executable = {
              command = selected_debugger.path,
              args = selected_debugger.args,
            },
          }
        end
        
        -- Configure the adapters
        dap.adapters.coreclr = adapter_config
        dap.adapters.netcoredbg = adapter_config
        dap.adapters.csharp = adapter_config
        
        return true
      end

      -- Set up C# debugger
      setup_csharp_debugger()

      -- Enhanced C# debugging configurations
      dap.configurations.cs = {
        {
          type = "coreclr",
          name = "🚀 Launch C# Application",
          request = "launch",
          program = function()
            local project_info = get_csharp_debug_info()
            if not project_info then
              return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
            end

            -- Smart auto-detection of build outputs
            if project_info.dll_path and vim.fn.filereadable(project_info.dll_path) == 1 then
              vim.notify("Found DLL: " .. project_info.dll_path, vim.log.levels.INFO)
              return project_info.dll_path
            end

            -- Look for any DLL in debug directories
            local patterns = {
              project_info.project_dir .. "/bin/Debug/**/" .. project_info.project_name .. ".dll",
              project_info.project_dir .. "/bin/Debug/**/*.dll"
            }
            
            for _, pattern in ipairs(patterns) do
              local files = vim.fn.glob(pattern, false, true)
              if #files > 0 then
                table.sort(files, function(a, b)
                  return vim.fn.getftime(a) > vim.fn.getftime(b)
                end)
                return files[1]
              end
            end

            return vim.fn.input("Path to dll: ", project_info.project_dir .. "/bin/Debug/", "file")
          end,
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
          args = {},
          stopAtEntry = false,
        },
        {
          type = "coreclr",
          name = "🌐 Launch ASP.NET Core",
          request = "launch",
          program = function()
            local project_info = get_csharp_debug_info()
            if project_info and project_info.dll_path then
              return project_info.dll_path
            end
            return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
          end,
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
          env = {
            ASPNETCORE_ENVIRONMENT = "Development",
            ASPNETCORE_URLS = "https://localhost:5001;http://localhost:5000"
          },
          args = {},
          stopAtEntry = false,
        },
        {
          type = "coreclr",
          name = "🔄 Launch with dotnet run",
          request = "launch",
          program = "dotnet",
          args = function()
            local project_info = get_csharp_debug_info()
            if project_info and project_info.project_file then
              return {"run", "--project", project_info.project_file, "--configuration", "Debug", "--no-build"}
            end
            return {"run", "--configuration", "Debug"}
          end,
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
          stopAtEntry = false,
        },
        {
          type = "coreclr",
          name = "📎 Attach to Process",
          request = "attach",
          processId = function()
            return require('dap.utils').pick_process({
              filter = function(proc)
                return proc.name:find('dotnet') or proc.name:find(vim.fn.fnamemodify(vim.fn.getcwd(), ":t"))
              end
            })
          end,
        },
      }

      -- Also support .csharp extension
      dap.configurations.csharp = dap.configurations.cs

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

      -- Python debugging configurations
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
          dap.run(dap.configurations.python[1])
        elseif filetype == 'cs' or filetype == 'csharp' then
          local project_info = get_csharp_debug_info()
          if not project_info then
            vim.notify('No C# project found in workspace', vim.log.levels.ERROR)
            return
          end

          vim.notify('Building and launching C# debugger...', vim.log.levels.INFO)
          build_csharp_project(project_info, function(success)
            if success then
              vim.schedule(function()
                -- Use the first C# configuration (Launch C# Application)
                dap.run(dap.configurations.cs[1])
              end)
            end
          end)
        else
          vim.notify('No automatic debug configuration for ' .. filetype, vim.log.levels.INFO)
          dap.continue()
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

      -- Optional: Build and debug function
      local function build_and_debug()
        local function on_build_complete(obj)
          if obj.code == 0 then
            vim.notify("✅ Build successful, starting debugger", vim.log.levels.INFO)
            vim.schedule(function()
              dap.continue()
            end)
          else
            vim.notify("❌ Build failed (exit code: " .. obj.code .. ")", vim.log.levels.ERROR)
          end
        end
        
        vim.notify("🔨 Building project...", vim.log.levels.INFO)
        vim.system({'dotnet', 'build'}, {
          cwd = vim.fn.getcwd(),
        }, on_build_complete)
      end

      -- Debug keymaps
      vim.keymap.set("n", "<F5>", launch_debugger, { desc = "Start/Continue Debugging (Auto-Build & Auto-Detect)" })
      vim.keymap.set("n", "<F7>", dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })
      vim.keymap.set("n", "<F8>", dap.continue, { desc = "Continue Debugging" })
      vim.keymap.set("n", "<F9>", dap.step_into, { desc = "Step Into" })
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Step Over" })
      vim.keymap.set("n", "<S-F9>", dap.step_out, { desc = "Step Out" })
      vim.keymap.set("n", "<F6>", terminate_dap, { desc = "Stop Debugging" })

      -- Leader key alternatives
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })
      vim.keymap.set("n", "<leader>dc", launch_debugger, { desc = "Continue/Start Debugging" })
      vim.keymap.set("n", "<leader>dt", terminate_dap, { desc = "Terminate Debug Session" })
      vim.keymap.set("n", "<leader>dj", dap.step_over, { desc = "Step Over" })
      vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Step Into" })
      vim.keymap.set("n", "<leader>do", dap.step_out, { desc = "Step Out" })
      vim.keymap.set("n", "<leader>dr", dap.repl.toggle, { desc = "Toggle REPL" })
      vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Toggle DAP UI" })

      -- Additional debug keymaps
      vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Run Last Debug Configuration" })
      vim.keymap.set("n", "<leader>dp", dap.pause, { desc = "Pause Execution" })
      vim.keymap.set("n", "<leader>dB", function()
        dap.set_breakpoint(vim.fn.input('Breakpoint condition: '))
      end, { desc = "Set Conditional Breakpoint" })
      vim.keymap.set("n", "<leader>dC", dap.clear_breakpoints, { desc = "Clear All Breakpoints" })

      -- Build and debug keymap
      vim.keymap.set('n', '<leader>dbb', build_and_debug, { desc = 'Build and Debug' })

      -- Manual debugger selection keymap
      vim.keymap.set("n", "<leader>dD", function()
        setup_csharp_debugger()
      end, { desc = "Reinitialize C# Debugger" })

      -- Enhanced DAP listeners for better C# debugging experience
      dap.listeners.before.event_terminated["csharp-enhanced"] = function()
        vim.notify("C# debug session ended", vim.log.levels.INFO)
      end

      dap.listeners.before.event_exited["csharp-enhanced"] = function()
        vim.notify("C# process exited", vim.log.levels.INFO)
      end

      -- Custom breakpoint signs
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

      -- Auto-install debuggers when opening relevant files
      vim.api.nvim_create_autocmd("BufReadPost", {
        group = vim.api.nvim_create_augroup("DapSetup", { clear = true }),
        pattern = { "*.rs", "*.py", "*.cs" },
        callback = function()
          local filetype = vim.bo.filetype
          if filetype == "rust" then
            local codelldb_path = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
            if vim.fn.executable(codelldb_path) == 0 then
              vim.notify("codelldb not found. Installing via Mason...", vim.log.levels.WARN)
              vim.cmd("MasonInstall codelldb")
            end
          elseif filetype == "python" then
            local debugpy_path = vim.fn.stdpath("data") .. "/mason/bin/debugpy-adapter"
            if vim.fn.executable(debugpy_path) == 0 then
              vim.notify("debugpy not found. Installing via Mason...", vim.log.levels.WARN)
              vim.cmd("MasonInstall debugpy")
            end
          elseif filetype == "cs" or filetype == "csharp" then
            local netcoredbg_path = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg"
            if vim.fn.executable(netcoredbg_path) == 0 then
              vim.notify("netcoredbg not found. Installing via Mason...", vim.log.levels.WARN)
              vim.cmd("MasonInstall netcoredbg")
            end
          end
        end,
      })
    end,
  },
}
