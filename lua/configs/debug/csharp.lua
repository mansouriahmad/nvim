-- lua/configs/debug/csharp.lua
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

-- Robust debugger finder
local function find_debugger_executable(debugger_name)
  local platform = get_platform()
  local mason_path = vim.fn.stdpath("data") .. "/mason"
  
  -- Strategy 1: Check Mason installation paths
  local mason_paths = {
    mason_path .. "/bin/" .. debugger_name,
    mason_path .. "/packages/" .. debugger_name .. "/" .. debugger_name,
  }
  
  if platform == "windows" then
    -- Add .exe variants for Windows
    for i, path in ipairs(mason_paths) do
      table.insert(mason_paths, path .. ".exe")
    end
    
    -- Windows-specific paths
    table.insert(mason_paths, mason_path .. "/packages/netcoredbg/netcoredbg/netcoredbg.exe")
    table.insert(mason_paths, "C:/Program Files/netcoredbg/netcoredbg.exe")
    table.insert(mason_paths, os.getenv("USERPROFILE") .. "/.local/bin/netcoredbg.exe")
  else
    -- Unix-specific paths
    table.insert(mason_paths, "/usr/local/bin/" .. debugger_name)
    table.insert(mason_paths, "/opt/homebrew/bin/" .. debugger_name)
    table.insert(mason_paths, os.getenv("HOME") .. "/.local/bin/" .. debugger_name)
    
    if platform == "macos" then
      table.insert(mason_paths, "/usr/local/share/dotnet/netcoredbg/" .. debugger_name)
    end
  end
  
  -- Check all paths
  for _, path in ipairs(mason_paths) do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end
  
  -- Strategy 2: Check PATH
  local path_exe = vim.fn.exepath(debugger_name)
  if path_exe ~= "" then
    return path_exe
  end
  
  return nil
end

-- Select best available C# debugger
local function select_csharp_debugger()
  local platform = get_platform()
  local preferences = { "netcoredbg" }
  
  -- Add codelldb as fallback for all platforms
  if platform == "windows" then
    table.insert(preferences, "codelldb")
  else
    table.insert(preferences, "codelldb")
  end
  
  for _, debugger in ipairs(preferences) do
    local path = find_debugger_executable(debugger)
    if path then
      local config = {
        name = debugger,
        path = path,
        type = "executable",
        args = {}
      }
      
      if debugger == "netcoredbg" then
        config.args = { "--interpreter=vscode" }
      elseif debugger == "codelldb" then
        config.type = "server"
        config.args = { "--port", "${port}" }
      end
      
      return config
    end
  end
  
  return nil
end

-- Find C# executable and project info
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
  
  -- Prioritize solution files
  if #sln_files > 0 then
    project_file = sln_files[1]
    project_name = vim.fn.fnamemodify(project_file, ":t:r")
    
    -- Find executable project within solution
    for _, csproj in ipairs(csproj_files) do
      local content = vim.fn.readfile(csproj)
      for _, line in ipairs(content) do
        if line:match("<OutputType>Exe</OutputType>") or 
           line:match("Microsoft%.AspNetCore%.App") then
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
  
  -- Find built DLL
  local debug_dir = project_dir .. "/bin/Debug"
  local possible_dlls = {}
  
  -- Look for DLLs in all framework directories
  local framework_patterns = {
    debug_dir .. "/net*/" .. project_name .. ".dll",
    debug_dir .. "/" .. project_name .. ".dll"
  }
  
  for _, pattern in ipairs(framework_patterns) do
    local files = vim.fn.glob(pattern, false, true)
    for _, file in ipairs(files) do
      table.insert(possible_dlls, file)
    end
  end
  
  local dll_path = nil
  if #possible_dlls > 0 then
    -- Sort by modification time (newest first)
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

-- Setup C# debugger
function M.setup_debugger()
  local dap = require("dap")
  
  -- Find and configure debugger
  local selected_debugger = select_csharp_debugger()
  
  if not selected_debugger then
    vim.notify(
      "No C# debugger found. Install via: :MasonInstall netcoredbg",
      vim.log.levels.WARN
    )
    return false
  end
  
  vim.notify(
    string.format("Using C# debugger: %s at %s", selected_debugger.name, selected_debugger.path),
    vim.log.levels.INFO
  )
  
  -- Configure adapter
  local adapter_config = {
    type = selected_debugger.type,
    command = selected_debugger.path,
    args = selected_debugger.args,
  }
  
  if selected_debugger.type == "server" then
    adapter_config = {
      type = "server",
      port = "${port}",
      executable = {
        command = selected_debugger.path,
        args = selected_debugger.args,
      },
    }
  end
  
  -- Register adapters
  dap.adapters.coreclr = adapter_config
  dap.adapters.netcoredbg = adapter_config
  dap.adapters.csharp = adapter_config
  
  return true
end

-- Setup C# debug configurations
function M.setup_configurations()
  local dap = require("dap")
  
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
        
        if project_info.dll_path and vim.fn.filereadable(project_info.dll_path) == 1 then
          vim.notify("Found DLL: " .. project_info.dll_path, vim.log.levels.INFO)
          return project_info.dll_path
        end
        
        -- Auto-detect DLL patterns
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
      env = {
        DOTNET_ENVIRONMENT = "Development"
      }
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
          return { "run", "--project", project_info.project_file, "--configuration", "Debug", "--no-build" }
        end
        return { "run", "--configuration", "Debug" }
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
            return proc.name:find('dotnet') or 
                   proc.name:find(vim.fn.fnamemodify(vim.fn.getcwd(), ":t"))
          end
        })
      end,
    },
  }
  
  -- Also support .csharp extension
  dap.configurations.csharp = dap.configurations.cs
end

-- Build and debug helper
function M.build_and_debug()
  local project_info = get_csharp_debug_info()
  if not project_info then
    vim.notify('No C# project found in workspace', vim.log.levels.ERROR)
    return
  end
  
  vim.notify('Building C# project: ' .. project_info.project_name, vim.log.levels.INFO)
  
  local build_cmd = { "dotnet", "build", project_info.project_file, "--configuration", "Debug" }
  
  vim.fn.jobstart(build_cmd, {
    cwd = project_info.project_dir,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ Build successful! Starting debugger...", vim.log.levels.INFO)
        vim.schedule(function()
          require('dap').run(require('dap').configurations.cs[1])
        end)
      else
        vim.notify("❌ Build failed with exit code: " .. code, vim.log.levels.ERROR)
      end
    end
  })
end

-- Quick project commands
function M.setup_keymaps()
  vim.keymap.set('n', '<leader>cdb', M.build_and_debug, { desc = 'Build and Debug C#' })
  
  vim.keymap.set("n", "<leader>cb", function()
    local project_info = get_csharp_debug_info()
    if project_info then
      vim.cmd("!dotnet build " .. project_info.project_file)
    else
      vim.cmd("!dotnet build")
    end
  end, { desc = "Build C# project" })
  
  vim.keymap.set("n", "<leader>cr", function()
    local project_info = get_csharp_debug_info()
    if project_info then
      vim.cmd("!dotnet run --project " .. project_info.project_file)
    else
      vim.cmd("!dotnet run")
    end
  end, { desc = "Run C# project" })
end

-- Auto-install debugger when C# file is opened
function M.ensure_debugger_installed()
  local debugger = find_debugger_executable("netcoredbg")
  if not debugger then
    vim.notify("netcoredbg not found. Installing via Mason...", vim.log.levels.WARN)
    vim.cmd("MasonInstall netcoredbg")
  end
end

return M