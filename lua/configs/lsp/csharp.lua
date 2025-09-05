
-- lua/configs/lsp/csharp.lua
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

-- Robust path finder for executables
local function find_executable(name, additional_paths)
  additional_paths = additional_paths or {}

  -- First check if it's in PATH
  local path_exe = vim.fn.exepath(name)
  if path_exe ~= "" then
    return path_exe
  end

  -- Check additional paths
  for _, path in ipairs(additional_paths) do
    local full_path = path .. "/" .. name
    if vim.fn.executable(full_path) == 1 then
      return full_path
    end
  end

  return nil
end

-- Find OmniSharp executable with robust path detection
local function find_omnisharp()
  local platform = get_platform()
  local mason_path = vim.fn.stdpath("data") .. "/mason"

  local omnisharp_paths = {
    mason_path .. "/bin",
    mason_path .. "/packages/omnisharp",
  }

  if platform == "windows" then
    table.insert(omnisharp_paths, mason_path .. "/bin")
    table.insert(omnisharp_paths, mason_path .. "/packages/omnisharp")
    -- Add common Windows paths
    table.insert(omnisharp_paths, "C:/Program Files/OmniSharp")
    table.insert(omnisharp_paths, os.getenv("USERPROFILE") .. "/.local/bin")
  else
    -- Add common Unix paths
    table.insert(omnisharp_paths, "/usr/local/bin")
    table.insert(omnisharp_paths, "/opt/homebrew/bin")
    table.insert(omnisharp_paths, os.getenv("HOME") .. "/.local/bin")
  end

  return find_executable("omnisharp", omnisharp_paths)
end

-- Get C# project information
local function get_csharp_project_info()
  local cwd = vim.fn.getcwd()
  
  -- Find solution files
  local sln_files = vim.fn.glob(cwd .. "/*.sln", false, true)
  
  -- Find project files
  local csproj_files = vim.fn.glob(cwd .. "/**/*.csproj", false, true)
  
  if #sln_files > 0 then
    return {
      type = "solution",
      file = sln_files[1],
      name = vim.fn.fnamemodify(sln_files[1], ":t:r"),
      directory = vim.fn.fnamemodify(sln_files[1], ":h")
    }
  elseif #csproj_files > 0 then
    -- Find the main executable project
    for _, csproj in ipairs(csproj_files) do
      local content = vim.fn.readfile(csproj)
      for _, line in ipairs(content) do
        if line:match("<OutputType>Exe</OutputType>") or 
           line:match("Microsoft%.AspNetCore%.App") then
          return {
            type = "project", 
            file = csproj,
            name = vim.fn.fnamemodify(csproj, ":t:r"),
            directory = vim.fn.fnamemodify(csproj, ":h")
          }
        end
      end
    end
    
    -- Default to first project if no executable found
    return {
      type = "project",
      file = csproj_files[1], 
      name = vim.fn.fnamemodify(csproj_files[1], ":t:r"),
      directory = vim.fn.fnamemodify(csproj_files[1], ":h")
    }
  end
  
  return nil
end

-- Setup C# LSP
function M.setup_lsp(capabilities)
  local lspconfig = require("lspconfig")
  
  -- Try to find OmniSharp first
  local omnisharp_cmd = vim.fn.expand("~/.local/share/nvim/mason/packages/omnisharp/OmniSharp")

  if vim.fn.filereadable(omnisharp_cmd) == 1 then
    vim.notify("Using explicit OmniSharp path: " .. omnisharp_cmd, vim.log.levels.INFO)
    lspconfig.omnisharp.setup({
      capabilities = capabilities,
      cmd = { 
        omnisharp_cmd, 
        "--languageserver", 
        "--hostPID", tostring(vim.fn.getpid()) 
      },
      root_dir = function(fname)
        local primary = lspconfig.util.root_pattern("*.sln")(fname)
        local fallback = lspconfig.util.root_pattern("*.csproj", "omnisharp.json", "function.json")(fname)
        return primary or fallback
      end,
      settings = {
        FormattingOptions = {
          EnableEditorConfigSupport = true,
          OrganizeImports = true,
        },
        MsBuild = {
          LoadProjectsOnDemand = false,
        },
        RoslynExtensionsOptions = {
          EnableAnalyzersSupport = true,
          EnableImportCompletion = true,
          AnalyzeOpenDocumentsOnly = false,
        },
        Sdk = {
          IncludePrereleases = true,
        },
      },
      on_attach = function(client, bufnr)
        -- C# specific keymaps
        local opts = { buffer = bufnr, noremap = true, silent = true }
        
        vim.keymap.set("n", "<leader>cb", function()
          vim.cmd("!dotnet build")
        end, vim.tbl_extend('force', opts, { desc = "dotnet build" }))
        
        vim.keymap.set("n", "<leader>cr", function()
          vim.cmd("!dotnet run")
        end, vim.tbl_extend('force', opts, { desc = "dotnet run" }))
        
        vim.keymap.set("n", "<leader>ct", function()
          vim.cmd("!dotnet test")
        end, vim.tbl_extend('force', opts, { desc = "dotnet test" }))
        
        vim.keymap.set("n", "<leader>cR", function()
          vim.cmd("!dotnet restore")
        end, vim.tbl_extend('force', opts, { desc = "dotnet restore" }))
        
        vim.keymap.set("n", "<leader>cc", function()
          vim.cmd("!dotnet clean")
        end, vim.tbl_extend('force', opts, { desc = "dotnet clean" }))
      end,
    })
  else
    -- REMOVED: No fallback to csharp-ls to avoid conflicts
    vim.notify("OmniSharp not found. Install via :MasonInstall omnisharp", vim.log.levels.ERROR)
    return false
  end
  
  return true
end

-- Get project information helper
function M.get_project_info()
  return get_csharp_project_info()
end

-- Build project helper
function M.build_project(project_info, callback)
  if not project_info then
    vim.notify("No C# project found", vim.log.levels.ERROR)
    return
  end
  
  vim.notify("Building C# project: " .. project_info.name, vim.log.levels.INFO)
  
  local build_cmd = { "dotnet", "build", project_info.file, "--configuration", "Debug" }
  
  vim.fn.jobstart(build_cmd, {
    cwd = project_info.directory,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ Build successful!", vim.log.levels.INFO)
        if callback then callback(true) end
      else
        vim.notify("❌ Build failed with exit code: " .. code, vim.log.levels.ERROR)
        if callback then callback(false) end
      end
    end,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            print("Build: " .. line)
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

return M


