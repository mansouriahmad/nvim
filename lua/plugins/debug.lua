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
          else
              vim.notify('No automatic debug configuration for ' .. filetype, vim.log.levels.INFO)
              dap.continue() -- Fallback to continue if not Rust
          end
      end

      -- Keymaps
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })
      vim.keymap.set("n", "<F5>", launch_debugger, { desc = "Launch/Continue Debugging (Auto-Build & Auto-Detect Rust)" })
      vim.keymap.set("n", "<F6>", dap.step_into, { desc = "Step Into" })
      vim.keymap.set("n", "<F7>", dap.step_over, { desc = "Step Over" })
      vim.keymap.set("n", "<S-F6>", dap.step_out, { desc = "Step Out" })
      vim.keymap.set("n", "<S-F5>", dap.terminate, { desc = "Stop Debugging" })
      vim.keymap.set("n", "<leader>dr", dap.repl.toggle, { desc = "Toggle REPL" })
      vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Toggle DAP UI" })

      -- Check and install codelldb if not present
      local function check_and_install_codelldb()
        local codelldb_path = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
        if vim.fn.executable(codelldb_path) == 0 then
          vim.notify("codelldb not found. Installing via Mason...", vim.log.levels.WARN)
          vim.cmd("MasonInstall codelldb")
        end
      end

      vim.api.nvim_create_autocmd("BufReadPost", {
        group = vim.api.nvim_create_augroup("DapRustSetup", { clear = true }),
        pattern = { "*.rs" },
        callback = function()
          check_and_install_codelldb()
        end,
      })

    end,
  },
}
