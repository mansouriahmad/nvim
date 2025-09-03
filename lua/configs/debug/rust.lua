return {
  -- codelldb adapter for Rust
  setup_adapter = function(dap)
    dap.adapters.codelldb = {
      type = "server",
      port = "${port}",
      executable = {
        command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
        args = { "--port", "${port}" },
      },
      -- Add initCommands for better string visualization
      initCommands = {
        "settings set target.prefer-dynamic-values false",
        "settings set expression.debug true",
      },
    }
  end,

  -- Function to automatically find Rust executable
  get_rust_executable = function()
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
  end,

  -- Rust debugging configurations
  setup_configurations = function(dap, get_rust_executable)
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
  end,

  check_and_install_debugger = function()
    local codelldb_path = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
    if vim.fn.executable(codelldb_path) == 0 then
      vim.notify("codelldb not found. Installing via Mason...", vim.log.levels.WARN)
      vim.cmd("MasonInstall codelldb")
    end
  end,
}

