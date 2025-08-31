-- lua/configs/debug/rust.lua
local M = {}

-- Helper function to detect platform
local function get_platform()
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    return "windows"
  elseif vim.fn.has("macunix") == 1 then
    return "macos"
  else
    return "linux"
  end
end

-- Find codelldb executable with robust path detection
local function find_codelldb()
  local platform = get_platform()
  local mason_path = vim.fn.stdpath("data") .. "/mason"
  
  local codelldb_paths = {}
  
  if platform == "windows" then
    table.insert(codelldb_paths, mason_path .. "/packages/codelldb/extension/adapter/codelldb.exe")
    table.insert(codelldb_paths, mason_path .. "/bin/codelldb.exe")
    table.insert(codelldb_paths, "C:/Users/" .. os.getenv("USERNAME") .. "/AppData/Local/nvim-data/mason/packages/codelldb/extension/adapter/codelldb.exe")
    table.insert(codelldb_paths, "C:/Program Files/codelldb/codelldb.exe")
  else
    table.insert(codelldb_paths, mason_path .. "/bin/codelldb")
    table.insert(codelldb_paths, mason_path .. "/packages/codelldb/extension/adapter/codelldb")
    table.insert(codelldb_paths, "/usr/local/bin/codelldb")
    table.insert(codelldb_paths, "/opt/homebrew/bin/codelldb")
    table.insert(codelldb_paths, os.getenv("HOME") .. "/.local/bin/codelldb")
    
    if platform == "macos" then
      table.insert(codelldb_paths, "/Applications/codelldb.app/Contents/MacOS/codelldb")
    end
  end
  
  -- Check all paths
  for _, path in ipairs(codelldb_paths) do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end
  
  -- Check PATH
  local path_exe = vim.fn.exepath("codelldb")
  if path_exe ~= "" then
    return path_exe
  end
  
  return nil
end

-- Get Rust executable path
local function get_rust_executable()
  local cwd = vim.fn.getcwd()
  local cargo_toml = cwd .. '/Cargo.toml'
  
  if vim.fn.filereadable(cargo_toml) == 0 then
    vim.notify('Not a Rust project (no Cargo.toml found)', vim.log.levels.WARN)
    return nil
  end
  
  -- Parse Cargo.toml for package name
  local package_name = nil
  local is_bin = false
  local bin_names = {}
  
  for line in io.lines(cargo_toml) do
    -- Get package name
    if line:match("^name%s*=%s*[\"']([^\"']+)[\"']") then
      package_name = line:match("^name%s*=%s*[\"']([^\"']+)[\"']")
    end
    
    -- Check for [[bin]] sections
    if line:match("^%[%[bin%]%]") then
      is_bin = true
    elseif is_bin and line:match("^name%s*=%s*[\"']([^\"']+)[\"']") then
      local bin_name = line:match("^name%s*=%s*[\"']([^\"']+)[\"']")
      table.insert(bin_names, bin_name)
      is_bin = false
    elseif line:match("^%[") and not line:match("^%[%[bin%]%]") then
      is_bin = false
    end
  end
  
  if not package_name then
    vim.notify('Could not find package name in Cargo.toml', vim.log.levels.WARN)
    return nil
  end
  
  -- Determine binary names to check
  local binary_names = #bin_names > 0 and bin_names or { package_name }
  
  local ext = get_platform() == "windows" and ".exe" or ""
  
  -- Check for built binaries
  for _, bin_name in ipairs(binary_names) do
    local debug_path = cwd .. '/target/debug/' .. bin_name .. ext
    if vim.fn.filereadable(debug_path) == 1 and vim.fn.executable(debug_path) == 1 then
      return debug_path
    end
    
    local release_path = cwd .. '/target/release/' .. bin_name .. ext
    if vim.fn.filereadable(release_path) == 1 and vim.fn.executable(release_path) == 1 then
      return release_path
    end
  end
  
  vim.notify('No executable found. Try running: cargo build', vim.log.levels.WARN)
  return nil
end

-- Parse Cargo.toml for project info
local function get_rust_project_info()
  local cwd = vim.fn.getcwd()
  local cargo_toml = cwd .. '/Cargo.toml'
  
  if vim.fn.filereadable(cargo_toml) == 0 then
    return nil
  end
  
  local project_info = {
    name = nil,
    directory = cwd,
    cargo_toml = cargo_toml,
    bins = {},
    examples = {},
    tests = {},
    is_workspace = false
  }
  
  local current_section = nil
  
  for line in io.lines(cargo_toml) do
    -- Detect sections
    if line:match("^%[package%]") then
      current_section = "package"
    elseif line:match("^%[%[bin%]%]") then
      current_section = "bin"
      table.insert(project_info.bins, {})
    elseif line:match("^%[%[example%]%]") then
      current_section = "example"
      table.insert(project_info.examples, {})
    elseif line:match("^%[%[test%]%]") then
      current_section = "test"
      table.insert(project_info.tests, {})
    elseif line:match("^%[workspace%]") then
      current_section = "workspace"
      project_info.is_workspace = true
    elseif line:match("^%[") then
      current_section = nil
    end
    
    -- Parse name fields
    if line:match("^name%s*=%s*[\"']([^\"']+)[\"']") then
      local name = line:match("^name%s*=%s*[\"']([^\"']+)[\"']")
      if current_section == "package" then
        project_info.name = name
      elseif current_section == "bin" and #project_info.bins > 0 then
        project_info.bins[#project_info.bins].name = name
      elseif current_section == "example" and #project_info.examples > 0 then
        project_info.examples[#project_info.examples].name = name
      elseif current_section == "test" and #project_info.tests > 0 then
        project_info.tests[#project_info.tests].name = name
      end
    end
  end
  
  return project_info
end

-- Setup Rust debugger
function M.setup_debugger()
  local dap = require("dap")
  
  -- Find codelldb
  local codelldb_path = find_codelldb()
  if not codelldb_path then
    vim.notify(
      "codelldb not found. Install via: :MasonInstall codelldb",
      vim.log.levels.WARN
    )
    return false
  end
  
  vim.notify("Using codelldb at: " .. codelldb_path, vim.log.levels.INFO)
  
  -- Configure codelldb adapter
  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
      command = codelldb_path,
      args = { "--port", "${port}" },
      -- On Windows, you might need to set the working directory
      cwd = get_platform() == "windows" and vim.fn.fnamemodify(codelldb_path, ":h") or nil,
    },
  }
  
  -- Also set up rt_lldb adapter (used by rust-tools)
  dap.adapters.rt_lldb = dap.adapters.codelldb
  
  return true
end

-- Setup Rust debug configurations
function M.setup_configurations()
  local dap = require("dap")
  
  dap.configurations.rust = {
    {
      name = "🚀 Launch Rust Binary",
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
      runInTerminal = false,
    },
    {
      name = "📋 Launch with Arguments",
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
      args = function()
        local args_str = vim.fn.input("Arguments: ")
        return vim.split(args_str, " ", true)
      end,
      runInTerminal = false,
    },
    {
      name = "🧪 Launch Test",
      type = "codelldb",
      request = "launch",
      program = function()
        -- For tests, we need to build with --tests flag
        vim.fn.system("cargo build --tests")
        
        local project_info = get_rust_project_info()
        if not project_info then
          return vim.fn.input("Path to test executable: ", vim.fn.getcwd() .. "/target/debug/deps/", "file")
        end
        
        -- Find test executables in deps directory
        local deps_dir = vim.fn.getcwd() .. "/target/debug/deps/"
        local test_files = vim.fn.glob(deps_dir .. project_info.name:gsub("-", "_") .. "-*", false, true)
        
        if #test_files > 0 then
          -- Sort by modification time (newest first)
          table.sort(test_files, function(a, b)
            return vim.fn.getftime(a) > vim.fn.getftime(b)
          end)
          
          -- Filter out .d files and other non-executables
          for _, file in ipairs(test_files) do
            if not file:match("%.d$") and vim.fn.executable(file) == 1 then
              return file
            end
          end
        end
        
        return vim.fn.input("Path to test executable: ", deps_dir, "file")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
      runInTerminal = false,
    },
    {
      name = "🎯 Launch Example",
      type = "codelldb",
      request = "launch", 
      program = function()
        local project_info = get_rust_project_info()
        if project_info and #project_info.examples > 0 then
          -- If there are defined examples, let user choose
          local example_names = {}
          for _, example in ipairs(project_info.examples) do
            table.insert(example_names, example.name)
          end
          
          if #example_names == 1 then
            local example_name = example_names[1]
            local ext = get_platform() == "windows" and ".exe" or ""
            return vim.fn.getcwd() .. "/target/debug/examples/" .. example_name .. ext
          else
            local choice = vim.fn.inputlist({"Select example:"} + example_names)
            if choice > 0 and choice <= #example_names then
              local example_name = example_names[choice]
              local ext = get_platform() == "windows" and ".exe" or ""
              return vim.fn.getcwd() .. "/target/debug/examples/" .. example_name .. ext
            end
          end
        end
        
        return vim.fn.input("Path to example: ", vim.fn.getcwd() .. "/target/debug/examples/", "file")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
      runInTerminal = false,
    },
    {
      name = "📎 Attach to Process",
      type = "codelldb",
      request = "attach",
      pid = function()
        return require('dap.utils').pick_process({
          filter = function(proc)
            return proc.name:find(vim.fn.fnamemodify(vim.fn.getcwd(), ":t"))
          end
        })
      end,
    },
  }
end

-- Build and debug helper
function M.build_and_debug()
  local project_info = get_rust_project_info()
  if not project_info then
    vim.notify('Not a Rust project (no Cargo.toml found)', vim.log.levels.ERROR)
    return
  end
  
  vim.notify('Building Rust project: ' .. (project_info.name or "unknown"), vim.log.levels.INFO)
  
  vim.fn.jobstart({ 'cargo', 'build' }, {
    cwd = project_info.directory,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify('✅ Build successful! Launching debugger...', vim.log.levels.INFO)
        vim.schedule(function()
          local exe = get_rust_executable()
          if exe then
            require('dap').run({
              name = "Launch Rust Binary",
              type = "codelldb",
              request = "launch",
              program = exe,
              cwd = "${workspaceFolder}",
              stopOnEntry = false,
              args = {},
              runInTerminal = false,
            })
          else
            vim.notify('No Rust executable found after build.', vim.log.levels.ERROR)
          end
        end)
      else
        vim.notify('❌ Build failed! Check errors and try again.', vim.log.levels.ERROR)
      end
    end
  })
end

-- Quick project commands  
function M.setup_keymaps()
  vim.keymap.set('n', '<leader>rdb', M.build_and_debug, { desc = 'Build and Debug Rust' })
  
  vim.keymap.set("n", "<leader>rb", function()
    vim.cmd("!cargo build")
  end, { desc = "Build Rust project" })
  
  vim.keymap.set("n", "<leader>rr", function()
    vim.cmd("!cargo run")
  end, { desc = "Run Rust project" })
  
  vim.keymap.set("n", "<leader>rt", function()
    vim.cmd("!cargo test")
  end, { desc = "Test Rust project" })
  
  vim.keymap.set("n", "<leader>rc", function()
    vim.cmd("!cargo check")
  end, { desc = "Check Rust project" })
end

-- Auto-install debugger when Rust file is opened
function M.ensure_debugger_installed()
  local debugger = find_codelldb()
  if not debugger then
    vim.notify("codelldb not found. Installing via Mason...", vim.log.levels.WARN)
    vim.cmd("MasonInstall codelldb")
  end
end

return M