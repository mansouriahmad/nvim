return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'rcarriga/nvim-dap-ui',
      'leoluz/nvim-dap-go',
      'nvim-neotest/nvim-nio',
    },
    config = function()
      local dap = require('dap')
      local dapui = require('dapui')

      -- Setup DAP UI
      dapui.setup({
        icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
        mappings = {
          expand = { "<CR>", "<2-LeftMouse>" },
          open = "o",
          remove = "d",
          edit = "e",
          repl = "r",
          toggle = "t",
        },
        element_mappings = {},
        expand_lines = true,
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
        controls = {
          enabled = true,
          element = "repl",
          icons = {
            pause = "⏸",
            play = "▶",
            step_into = "↓",
            step_over = "→",
            step_out = "↑",
            step_back = "←",
            run_last = "↻",
            terminate = "■",
            disconnect = "⏏",
          },
        },
        floating = {
          max_height = 0.9,
          max_width = 0.5,
          border = "rounded",
          mappings = {
            close = { "q", "<Esc>" },
          },
        },
        windows = { indent = 1 },
        render = {
          max_type_length = nil,
          max_value_lines = 100,
        },
      })

      -- Automatically open DAP UI when debugging starts
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end

      -- Automatically close DAP UI when debugging ends
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end

      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      -- Breakpoint persistence (robust, cross-platform, with pending support)
      local breakpoints_file = vim.fn.stdpath("data") .. "/breakpoints.json"
      local pending_breakpoints = {}

      -- Save all breakpoints to file
      local function save_breakpoints()
        local all_bps = dap.list_breakpoints()
        if type(all_bps) ~= 'table' then
          print('[DAP] No breakpoints to save.')
          return
        end
        local data = {}
        for buf, bps in pairs(all_bps) do
          local file = vim.api.nvim_buf_get_name(buf)
          if type(bps) == 'table' then
            for _, bp in ipairs(bps) do
              table.insert(data, {
                file = file,
                line = bp.line,
                condition = bp.condition,
                logMessage = bp.logMessage,
                hitCondition = bp.hitCondition,
              })
            end
          end
        end
        local f = io.open(breakpoints_file, "w")
        if f then
          f:write(vim.json.encode(data))
          f:close()
          print("[DAP] Breakpoints saved to " .. breakpoints_file)
        else
          print("[DAP] Failed to save breakpoints!")
        end
      end

      -- Actually set breakpoints for a file if buffer is loaded
      local function set_breakpoints_for_file(file, bps)
        local bufnr = vim.fn.bufnr(file, false)
        if bufnr ~= -1 and type(bps) == 'table' then
          for _, bp in ipairs(bps) do
            dap.set_breakpoint(file, bp.line, bp.condition, bp.logMessage, bp.hitCondition)
          end
          return true
        end
        return false
      end

      -- Load breakpoints from file, defer if buffer not loaded
      local function load_breakpoints()
        local f = io.open(breakpoints_file, "r")
        if not f then print("[DAP] No breakpoints file found.") return end
        local content = f:read("*a")
        f:close()
        local ok, data = pcall(vim.json.decode, content)
        if not ok or type(data) ~= 'table' then print("[DAP] Failed to decode breakpoints file.") return end
        pending_breakpoints = {}
        for _, bp in ipairs(data) do
          if bp.file and bp.line then
            if not set_breakpoints_for_file(bp.file, {bp}) then
              -- Buffer not loaded, store for later
              pending_breakpoints[bp.file] = pending_breakpoints[bp.file] or {}
              table.insert(pending_breakpoints[bp.file], bp)
            end
          end
        end
        print("[DAP] Breakpoints loaded (pending for unopened files)")
      end

      -- On BufReadPost, set any pending breakpoints for that file
      vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function(args)
          local file = vim.api.nvim_buf_get_name(args.buf)
          if pending_breakpoints[file] then
            set_breakpoints_for_file(file, pending_breakpoints[file])
            pending_breakpoints[file] = nil
            print("[DAP] Restored breakpoints for " .. file)
          end
        end
      })

      -- Clear all breakpoints and save
      local function clear_breakpoints()
        dap.clear_breakpoints()
        save_breakpoints()
      end

      -- List all breakpoints
      local function list_breakpoints()
        local all_bps = dap.list_breakpoints()
        if type(all_bps) ~= 'table' then
          vim.notify("No breakpoints set", vim.log.levels.INFO)
          return
        end
        local msg = {}
        for buf, bps in pairs(all_bps) do
          local file = vim.api.nvim_buf_get_name(buf)
          if type(bps) == 'table' then
            for _, bp in ipairs(bps) do
              table.insert(msg, string.format("%s:%d", file, bp.line))
            end
          end
        end
        if #msg == 0 then
          vim.notify("No breakpoints set", vim.log.levels.INFO)
        else
          vim.notify("Breakpoints:\n" .. table.concat(msg, "\n"), vim.log.levels.INFO)
        end
      end

      -- Save breakpoints on set/clear
      dap.listeners.after.set_breakpoints["persist"] = save_breakpoints
      dap.listeners.after.clear_breakpoints["persist"] = save_breakpoints

      -- Save breakpoints on exit
      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = save_breakpoints
      })

      -- Load breakpoints on startup (with delay)
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          vim.defer_fn(load_breakpoints, 1000)
        end
      })

      -- Keymaps for manual control
      vim.keymap.set('n', '<leader>dbs', save_breakpoints, { desc = 'Save Breakpoints' })
      vim.keymap.set('n', '<leader>dbr', load_breakpoints, { desc = 'Restore Breakpoints' })
      vim.keymap.set('n', '<leader>dbc', clear_breakpoints, { desc = 'Clear All Breakpoints' })
      vim.keymap.set('n', '<leader>dbl', list_breakpoints, { desc = 'List Breakpoints' })

      -- Watches: open panel and add watch expression
      --
      -- Usage:
      --   <leader>duw   -- Open DAP UI and focus Watches panel
      --   <leader>daw   -- Add a watch expression (prompts for input)
      --
      -- In the UI, use 'a' to add, 'e' to edit, 'd' to delete watches.
      vim.keymap.set('n', '<leader>duw', function()
        require('dapui').open()
        vim.notify("Use Tab or mouse to focus the Watches panel.", vim.log.levels.INFO)
      end, { desc = 'Open Watches Panel (DAP UI)' })

      vim.keymap.set('n', '<leader>daw', function()
        local expr = vim.fn.input('Watch expression: ')
        if expr and expr ~= '' then
          require('dap').add_watch(expr)
        end
      end, { desc = 'Add DAP Watch Expression' })

      -- Rust debugging configuration (cross-platform)
      -- Use codelldb for better Rust support
      dap.adapters.codelldb = {
        type = 'server',
        port = '${port}',
        executable = {
          command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
          args = {"--port", "${port}"},
        },
      }
      
      -- Alternative: Use system debuggers (cross-platform fallback)
      if vim.fn.has('mac') == 1 then
        -- macOS system LLDB
        dap.adapters.lldb = {
          type = 'executable',
          command = '/usr/bin/lldb',
          name = "lldb"
        }
      elseif vim.fn.has('unix') == 1 then
        -- Linux GDB (Ubuntu/Debian)
        dap.adapters.gdb = {
          type = 'executable',
          command = 'gdb',
          args = { '--interpreter=mi' }
        }
      end

      -- Python debugging adapter (cross-platform, FIXED: command must be string)
      local python_exe = vim.fn.executable('python3') == 1 and 'python3' or 'python'
      dap.adapters.python = {
        type = 'executable',
        command = python_exe,
        args = { '-m', 'debugpy.adapter' },
      }

      -- Function to get the best available debug adapter (cross-platform)
      local function get_debug_adapter()
        local codelldb_path = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
        if vim.fn.executable(codelldb_path) == 1 then
          return "codelldb"
        elseif vim.fn.has('mac') == 1 and vim.fn.executable('/usr/bin/lldb') == 1 then
          return "lldb"
        elseif vim.fn.has('unix') == 1 and vim.fn.executable('gdb') == 1 then
          return "gdb"
        else
          return "codelldb" -- default fallback
        end
      end

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
        
        -- Check for binary executable (macOS compatible)
        local binary_path = cwd .. '/target/debug/' .. package_name
        if vim.fn.filereadable(binary_path) == 1 then
          if vim.fn.executable(binary_path) == 1 then
            return binary_path
          else
            vim.notify('Binary exists but is not executable: ' .. binary_path, vim.log.levels.WARN)
          end
        end
        
        -- Check for test executable (macOS compatible)
        local test_path = cwd .. '/target/debug/deps/' .. package_name .. '-*'
        local test_files = vim.fn.glob(test_path, false, true)
        if #test_files > 0 then
          for _, test_file in ipairs(test_files) do
            if vim.fn.executable(test_file) == 1 then
              return test_file
            end
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

      -- Function to get all test executables
      local function get_rust_test_executables()
        local cwd = vim.fn.getcwd()
        local test_files = vim.fn.glob(cwd .. '/target/debug/deps/*-*', false, true)
        return test_files
      end

      -- Rust debugging configurations (cross-platform)
      dap.configurations.rust = {
        {
          name = "Debug Binary (Auto)",
          type = "codelldb",
          request = "launch",
          program = function()
            local exe = get_rust_executable()
            if exe then
              return exe
            else
              -- Fallback to manual input if auto-detection fails
              return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/target/debug/', 'file')
            end
          end,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
          args = {},
          console = 'integratedTerminal',
        },
        {
          name = "Debug Binary (GDB - Ubuntu)",
          type = "gdb",
          request = "launch",
          program = function()
            local exe = get_rust_executable()
            if exe then
              return exe
            else
              return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/target/debug/', 'file')
            end
          end,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
          args = {},
          console = 'integratedTerminal',
        },
        {
          name = "Debug Tests (Auto)",
          type = "codelldb",
          request = "launch",
          program = function()
            local test_files = get_rust_test_executables()
            if #test_files > 0 then
              -- If multiple test files, let user choose
              if #test_files == 1 then
                return test_files[1]
              else
                local options = table.concat(test_files, '\n')
                local choice = vim.fn.inputlist({
                  'Choose test executable:',
                  unpack(test_files)
                })
                if choice > 0 and choice <= #test_files then
                  return test_files[choice]
                end
              end
            end
            -- Fallback to manual input
            return vim.fn.input('Path to test executable: ', vim.fn.getcwd() .. '/target/debug/deps/', 'file')
          end,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
          args = {},
          console = 'integratedTerminal',
        },
        {
          name = "Debug Current Test",
          type = "codelldb",
          request = "launch",
          program = function()
            -- Try to find test executable for current file
            local current_file = vim.fn.expand('%:t:r')
            local test_files = get_rust_test_executables()
            for _, test_file in ipairs(test_files) do
              if test_file:match(current_file) then
                return test_file
              end
            end
            -- Fallback to first test file
            if #test_files > 0 then
              return test_files[1]
            end
            return vim.fn.input('Path to test executable: ', vim.fn.getcwd() .. '/target/debug/deps/', 'file')
          end,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
          args = {},
          console = 'integratedTerminal',
        },
        {
          name = "Debug with Custom Args",
          type = "codelldb",
          request = "launch",
          program = function()
            local exe = get_rust_executable()
            if exe then
              return exe
            else
              return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/target/debug/', 'file')
            end
          end,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
          args = function()
            return vim.fn.split(vim.fn.input('Arguments: '), ' ')
          end,
          console = 'integratedTerminal',
        },
      }

      -- Python debugging configurations
      dap.configurations.python = {
        {
          name = "Python: Current File",
          type = "python",
          request = "launch",
          program = "${file}",
          console = "integratedTerminal",
          justMyCode = true,
        },
        {
          name = "Python: Current File (External Terminal)",
          type = "python",
          request = "launch",
          program = "${file}",
          console = "externalTerminal",
          justMyCode = true,
        },
        {
          name = "Python: Module",
          type = "python",
          request = "launch",
          module = "enter-your-module-name",
          console = "integratedTerminal",
          justMyCode = true,
        },
        {
          name = "Python: Attach",
          type = "python",
          request = "attach",
          connect = {
            port = 5678,
            host = "127.0.0.1",
          },
          pathMappings = {
            {
              localRoot = "${workspaceFolder}",
              remoteRoot = ".",
            },
          },
        },
        {
          name = "Python: Django",
          type = "python",
          request = "launch",
          program = "${workspaceFolder}/manage.py",
          args = { "runserver" },
          django = true,
          console = "integratedTerminal",
          justMyCode = true,
        },
        {
          name = "Python: Flask",
          type = "python",
          request = "launch",
          module = "flask",
          env = {
            FLASK_APP = "${workspaceFolder}/app.py",
            FLASK_DEBUG = "1",
          },
          args = { "run", "--no-debugger", "--no-reload" },
          console = "integratedTerminal",
          justMyCode = true,
        },
        {
          name = "Python: FastAPI",
          type = "python",
          request = "launch",
          module = "uvicorn",
          args = { "main:app", "--reload", "--port", "8000" },
          console = "integratedTerminal",
          justMyCode = true,
        },
        {
          name = "Python: pytest",
          type = "python",
          request = "launch",
          module = "pytest",
          args = { "-v" },
          console = "integratedTerminal",
          justMyCode = false,
        },
      }

      -- Function to check if codelldb is available
      local function check_codelldb()
        local codelldb_path = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
        if vim.fn.executable(codelldb_path) == 0 then
          vim.notify('codelldb not found. Installing via Mason...', vim.log.levels.WARN)
          vim.cmd('MasonInstall codelldb')
          return false
        end
        return true
      end

      -- Function to build and debug Rust project
      local function build_and_debug()
        local cwd = vim.fn.getcwd()
        local cargo_toml = cwd .. '/Cargo.toml'
        
        if vim.fn.filereadable(cargo_toml) == 0 then
          vim.notify('Not a Rust project (no Cargo.toml found)', vim.log.levels.ERROR)
          return
        end
        
        local adapter = get_debug_adapter()
        if not adapter then
          vim.notify('No debug adapter found. Installing codelldb...', vim.log.levels.WARN)
          vim.cmd('MasonInstall codelldb')
          return
        end
        
        -- Build the project
        vim.notify('Building Rust project...', vim.log.levels.INFO)
        local job = vim.fn.jobstart({'cargo', 'build'}, {
          on_exit = function(_, code)
            if code == 0 then
              vim.notify('Build successful! Starting debugger...', vim.log.levels.INFO)
              -- Start debugging after successful build
              vim.schedule(function()
                dap.continue()
              end)
            else
              vim.notify('Build failed! Check errors and try again.', vim.log.levels.ERROR)
            end
          end
        })
      end

      -- Function to build and debug tests
      local function build_and_debug_tests()
        local cwd = vim.fn.getcwd()
        local cargo_toml = cwd .. '/Cargo.toml'
        
        if vim.fn.filereadable(cargo_toml) == 0 then
          vim.notify('Not a Rust project (no Cargo.toml found)', vim.log.levels.ERROR)
          return
        end
        
        local adapter = get_debug_adapter()
        if not adapter then
          vim.notify('No debug adapter found. Installing codelldb...', vim.log.levels.WARN)
          vim.cmd('MasonInstall codelldb')
          return
        end
        
        -- Build tests
        vim.notify('Building Rust tests...', vim.log.levels.INFO)
        local job = vim.fn.jobstart({'cargo', 'test', '--no-run'}, {
          on_exit = function(_, code)
            if code == 0 then
              vim.notify('Test build successful! Starting debugger...', vim.log.levels.INFO)
              -- Start debugging tests after successful build
              vim.schedule(function()
                dap.continue()
              end)
            else
              vim.notify('Test build failed! Check errors and try again.', vim.log.levels.ERROR)
            end
          end
        })
      end

      -- Keymaps for debugging (macOS-friendly)
      vim.keymap.set('n', '<leader>db', function()
        dap.toggle_breakpoint()
        vim.cmd('redraw!')  -- Force redraw to show breakpoint sign immediately
        local line = vim.fn.line('.')
        local file = vim.fn.expand('%:p')
        vim.notify(string.format('Breakpoint toggled at %s:%d', vim.fn.fnamemodify(file, ':t'), line), vim.log.levels.INFO)
      end, { desc = 'Toggle Breakpoint' })
      vim.keymap.set('n', '<F5>', dap.continue, { desc = 'Start/Continue Debugging' })
      vim.keymap.set('n', '<F8>', dap.continue, { desc = 'Continue' })
      vim.keymap.set('n', '<F6>', dap.step_into, { desc = 'Step Into' })
      vim.keymap.set('n', '<F7>', dap.step_over, { desc = 'Step Over' })
      vim.keymap.set('n', '<S-F6>', dap.step_out, { desc = 'Step Out' })
      vim.keymap.set('n', '<S-F5>', dap.terminate, { desc = 'Stop Debugging' })
      vim.keymap.set('n', '<leader>dr', dap.repl.toggle, { desc = 'Toggle REPL' })
      vim.keymap.set('n', '<leader>dl', dap.run_last, { desc = 'Run Last' })
      vim.keymap.set('n', '<leader>du', dapui.toggle, { desc = 'Toggle DAP UI' })
      
      -- Auto-build and debug keymaps
      vim.keymap.set('n', '<leader>dd', build_and_debug, { desc = 'Build and Debug Binary' })
      vim.keymap.set('n', '<leader>dT', build_and_debug_tests, { desc = 'Build and Debug Tests' })
      
      -- Function to install Python debugging dependencies (cross-platform)
      local function install_python_debug_deps()
        vim.notify('Installing Python debugging dependencies...', vim.log.levels.INFO)
        
        -- Try different pip commands based on system
        local pip_commands = {'pip3', 'pip', 'python3 -m pip', 'python -m pip'}
        local success = false
        
        for _, cmd in ipairs(pip_commands) do
          if vim.fn.executable(cmd:match('^[%w]+')) == 1 then
            local job = vim.fn.jobstart({cmd:match('^[%w]+'), 'install', 'debugpy'}, {
              on_exit = function(_, code)
                if code == 0 then
                  vim.notify('Python debugging dependencies installed successfully!', vim.log.levels.INFO)
                  success = true
                else
                  if not success then
                    vim.notify('Failed to install with ' .. cmd .. '. Trying next method...', vim.log.levels.WARN)
                  end
                end
              end
            })
            break
          end
        end
        
        if not success then
          vim.notify('Failed to install Python debugging dependencies. Try manually: pip3 install debugpy', vim.log.levels.ERROR)
        end
      end

      -- Manual installation commands (cross-platform)
      vim.keymap.set('n', '<leader>di', function()
        vim.cmd('MasonInstall codelldb')
        vim.notify('Installing codelldb... Please wait and try debugging again.', vim.log.levels.INFO)
      end, { desc = 'Install codelldb' })

      vim.keymap.set('n', '<leader>dip', install_python_debug_deps, { desc = 'Install Python Debug Dependencies' })
      
      -- Ubuntu-specific installation commands
      if vim.fn.has('unix') == 1 and vim.fn.has('mac') == 0 then
        vim.keymap.set('n', '<leader>dig', function()
          vim.notify('Installing GDB...', vim.log.levels.INFO)
          local job = vim.fn.jobstart({'sudo', 'apt-get', 'update'}, {
            on_exit = function(_, code)
              if code == 0 then
                local job2 = vim.fn.jobstart({'sudo', 'apt-get', 'install', '-y', 'gdb'}, {
                  on_exit = function(_, code2)
                    if code2 == 0 then
                      vim.notify('GDB installed successfully!', vim.log.levels.INFO)
                    else
                      vim.notify('Failed to install GDB. Try: sudo apt-get install gdb', vim.log.levels.ERROR)
                    end
                  end
                })
              else
                vim.notify('Failed to update package list. Try: sudo apt-get update', vim.log.levels.ERROR)
              end
            end
          })
        end, { desc = 'Install GDB (Ubuntu)' })
      end

      -- C# debugging adapter (netcoredbg, robust path detection)
      local mason_netcoredbg = vim.fn.stdpath('data') .. '/mason/packages/netcoredbg/netcoredbg/netcoredbg'
      if vim.fn.filereadable(mason_netcoredbg) == 0 then
        mason_netcoredbg = vim.fn.stdpath('data') .. '/mason/bin/netcoredbg'
      end
      dap.adapters.coreclr = {
        type = 'executable',
        command = mason_netcoredbg,
        args = { '--interpreter=vscode' },
      }

      -- C# debug configurations
      dap.configurations.cs = {
        {
          type = 'coreclr',
          name = 'Launch - NetCoreDbg',
          request = 'launch',
          program = function()
            return vim.fn.input('Path to dll: ', vim.fn.getcwd() .. '/bin/Debug/', 'file')
          end,
        },
        {
          type = 'coreclr',
          name = 'Attach - NetCoreDbg',
          request = 'attach',
          processId = function()
            local output = vim.fn.system('ps -A | grep dotnet')
            local lines = vim.split(output, '\n')
            for _, line in ipairs(lines) do
              local pid = line:match('^%s*(%d+)')
              if pid then
                print(line)
              end
            end
            return tonumber(vim.fn.input('Process ID: '))
          end,
        },
      }

      -- Keymap: build and debug C# project
      vim.keymap.set('n', '<leader>ddc', function()
        vim.notify('Building C# project (dotnet build)...', vim.log.levels.INFO)
        local job = vim.fn.jobstart({'dotnet', 'build'}, {
          on_exit = function(_, code)
            if code == 0 then
              vim.notify('Build successful! Starting debugger...', vim.log.levels.INFO)
              vim.schedule(function()
                require('dap').continue()
              end)
            else
              vim.notify('Build failed! Check errors and try again.', vim.log.levels.ERROR)
            end
          end
        })
      end, { desc = 'Build and Debug C# Project' })
    end,
  },
  {
    'rcarriga/nvim-dap-ui',
    dependencies = { 'mfussenegger/nvim-dap' },
  },
  {
    'leoluz/nvim-dap-go',
    dependencies = { 'mfussenegger/nvim-dap' },
    config = function()
      require('dap-go').setup()
    end,
  },
}

 