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

      -- Breakpoint persistence
      local breakpoints_file = vim.fn.stdpath("data") .. "/breakpoints.json"
      
      -- Function to save breakpoints to file
      local function save_breakpoints()
        local breakpoints = dap.breakpoints()
        local data = {}
        
        for _, bp in pairs(breakpoints) do
          table.insert(data, {
            line = bp.line,
            condition = bp.condition,
            hitCondition = bp.hitCondition,
            logMessage = bp.logMessage,
            path = bp.path
          })
        end
        
        local file = io.open(breakpoints_file, "w")
        if file then
          file:write(vim.json.encode(data))
          file:close()
        end
      end
      
      -- Function to load breakpoints from file
      local function load_breakpoints()
        local file = io.open(breakpoints_file, "r")
        if file then
          local content = file:read("*all")
          file:close()
          
          local ok, data = pcall(vim.json.decode, content)
          if ok and data then
            for _, bp_data in ipairs(data) do
              -- Only set breakpoint if file exists
              if vim.fn.filereadable(bp_data.path) == 1 then
                dap.set_breakpoint(bp_data.condition, bp_data.hitCondition, bp_data.logMessage, bp_data.path, bp_data.line)
              end
            end
          end
        end
      end
      
      -- Save breakpoints when they change
      dap.listeners.after.set_breakpoints["breakpoint_persistence"] = function()
        save_breakpoints()
      end
      
      -- Load breakpoints on startup
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          -- Small delay to ensure DAP is ready
          vim.defer_fn(load_breakpoints, 1000)
        end
      })

      -- Rust debugging configuration for macOS
      -- Use codelldb for better Rust support
      dap.adapters.codelldb = {
        type = 'server',
        port = '${port}',
        executable = {
          command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
          args = {"--port", "${port}"},
        },
      }
      
      -- Alternative: Use system LLDB on macOS (if codelldb fails)
      dap.adapters.lldb = {
        type = 'executable',
        command = '/usr/bin/lldb', -- macOS system LLDB
        name = "lldb"
      }

      -- Python debugging adapter
      dap.adapters.python = {
        type = 'executable',
        command = 'python3',
        args = { '-m', 'debugpy.adapter' },
      }

      -- Function to get the best available debug adapter
      local function get_debug_adapter()
        local codelldb_path = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
        if vim.fn.executable(codelldb_path) == 1 then
          return "codelldb"
        elseif vim.fn.executable('/usr/bin/lldb') == 1 then
          return "lldb"
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
          return nil
        end
        
        -- Check for binary executable (macOS compatible)
        local binary_path = cwd .. '/target/debug/' .. package_name
        if vim.fn.filereadable(binary_path) == 1 then
          return binary_path
        end
        
        -- Check for test executable (macOS compatible)
        local test_path = cwd .. '/target/debug/deps/' .. package_name .. '-*'
        local test_files = vim.fn.glob(test_path, false, true)
        if #test_files > 0 then
          return test_files[1]
        end
        
        -- Check for release build (macOS common)
        local release_path = cwd .. '/target/release/' .. package_name
        if vim.fn.filereadable(release_path) == 1 then
          return release_path
        end
        
        return nil
      end

      -- Function to get all test executables
      local function get_rust_test_executables()
        local cwd = vim.fn.getcwd()
        local test_files = vim.fn.glob(cwd .. '/target/debug/deps/*-*', false, true)
        return test_files
      end

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
      vim.keymap.set('n', '<leader>db', dap.toggle_breakpoint, { desc = 'Toggle Breakpoint' })
      vim.keymap.set('n', '<F5>', dap.continue, { desc = 'Start/Continue Debugging' })
      vim.keymap.set('n', '<F8>', dap.continue, { desc = 'Continue' })
      vim.keymap.set('n', '<F6>', dap.step_into, { desc = 'Step Into' })
      vim.keymap.set('n', '<F7>', dap.step_over, { desc = 'Step Over' })
      vim.keymap.set('n', '<S-F6>', dap.step_out, { desc = 'Step Out' })
      vim.keymap.set('n', '<S-F5>', dap.terminate, { desc = 'Stop Debugging' })
      vim.keymap.set('n', '<leader>dr', dap.repl.toggle, { desc = 'Toggle REPL' })
      vim.keymap.set('n', '<leader>dl', dap.run_last, { desc = 'Run Last' })
      vim.keymap.set('n', '<leader>du', dapui.toggle, { desc = 'Toggle DAP UI' })
      
      -- Breakpoint management keymaps
      vim.keymap.set('n', '<leader>dbl', function()
        local breakpoints = dap.breakpoints()
        if #breakpoints == 0 then
          vim.notify('No breakpoints set', vim.log.levels.INFO)
        else
          local msg = string.format('Breakpoints (%d):', #breakpoints)
          for i, bp in ipairs(breakpoints) do
            msg = msg .. string.format('\n%d. %s:%d', i, vim.fn.fnamemodify(bp.path, ':t'), bp.line)
          end
          vim.notify(msg, vim.log.levels.INFO)
        end
      end, { desc = 'List Breakpoints' })
      
      vim.keymap.set('n', '<leader>dbc', function()
        dap.clear_breakpoints()
        save_breakpoints()
        vim.notify('All breakpoints cleared', vim.log.levels.INFO)
      end, { desc = 'Clear All Breakpoints' })
      
      vim.keymap.set('n', '<leader>dbr', function()
        load_breakpoints()
        vim.notify('Breakpoints restored from file', vim.log.levels.INFO)
      end, { desc = 'Restore Breakpoints' })
      
      -- Floating debug controls
      vim.keymap.set('n', '<leader>dC', function()
        dapui.float_element("controls", { enter = true })
      end, { desc = 'Show Debug Controls' })
      
      -- Auto-build and debug keymaps
      vim.keymap.set('n', '<leader>dd', build_and_debug, { desc = 'Build and Debug Binary' })
      vim.keymap.set('n', '<leader>dT', build_and_debug_tests, { desc = 'Build and Debug Tests' })
      
      -- Function to install Python debugging dependencies
      local function install_python_debug_deps()
        vim.notify('Installing Python debugging dependencies...', vim.log.levels.INFO)
        local job = vim.fn.jobstart({'pip3', 'install', 'debugpy'}, {
          on_exit = function(_, code)
            if code == 0 then
              vim.notify('Python debugging dependencies installed successfully!', vim.log.levels.INFO)
            else
              vim.notify('Failed to install Python debugging dependencies. Try: pip3 install debugpy', vim.log.levels.ERROR)
            end
          end
        })
      end

      -- Manual installation commands
      vim.keymap.set('n', '<leader>di', function()
        vim.cmd('MasonInstall codelldb')
        vim.notify('Installing codelldb... Please wait and try debugging again.', vim.log.levels.INFO)
      end, { desc = 'Install codelldb' })

      vim.keymap.set('n', '<leader>dip', install_python_debug_deps, { desc = 'Install Python Debug Dependencies' })
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