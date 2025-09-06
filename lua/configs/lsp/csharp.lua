-- lua/configs/lsp/csharp.lua
-- Simplified C# LSP configuration using platform_config

local M = {}
local platform_config = require('configs.lsp.platform_config')

-- Setup C# LSP
function M.setup_lsp(capabilities)
  local lspconfig = require("lspconfig")
  
  -- Use the platform-specific setup
  local success = platform_config.setup_csharp_lsp(lspconfig, capabilities)
  
  if success then
    -- Additional C#-specific setup if needed
    vim.api.nvim_create_autocmd("BufReadPost", {
      pattern = { "*.cs", "*.csx", "*.cake" },
      callback = function()
        -- Set C#-specific options
        vim.opt_local.commentstring = '// %s'
        vim.opt_local.shiftwidth = 4
        vim.opt_local.tabstop = 4
        vim.opt_local.expandtab = true
      end,
    })
  end
  
  return success
end

-- Get C# project information
function M.get_project_info()
  local cwd = vim.fn.getcwd()
  
  -- Find solution files
  local sln_files = vim.fn.glob(cwd .. "/*.sln", false, true)
  
  -- Find project files
  local csproj_files = vim.fn.glob(cwd .. "/**/*.csproj", false, true)
  
  local project_file = nil
  local project_name = nil
  local project_dir = cwd
  local project_type = nil
  
  -- Prioritize solution files
  if #sln_files > 0 then
    project_file = sln_files[1]
    project_name = vim.fn.fnamemodify(project_file, ":t:r")
    project_type = "solution"
    
    -- Find executable project within solution
    for _, csproj in ipairs(csproj_files) do
      local content = vim.fn.readfile(csproj)
      for _, line in ipairs(content) do
        if line:match("<OutputType>Exe</OutputType>") then
          project_file = csproj
          project_name = vim.fn.fnamemodify(csproj, ":t:r")
          project_dir = vim.fn.fnamemodify(csproj, ":h")
          project_type = "console"
          break
        elseif line:match("Microsoft%.AspNetCore%.App") then
          project_file = csproj
          project_name = vim.fn.fnamemodify(csproj, ":t:r")
          project_dir = vim.fn.fnamemodify(csproj, ":h")
          project_type = "web"
          break
        end
      end
    end
  elseif #csproj_files > 0 then
    project_file = csproj_files[1]
    project_name = vim.fn.fnamemodify(project_file, ":t:r")
    project_dir = vim.fn.fnamemodify(project_file, ":h")
    
    -- Determine project type
    local content = vim.fn.readfile(project_file)
    for _, line in ipairs(content) do
      if line:match("<OutputType>Exe</OutputType>") then
        project_type = "console"
        break
      elseif line:match("Microsoft%.AspNetCore%.App") then
        project_type = "web"
        break
      elseif line:match("<OutputType>Library</OutputType>") then
        project_type = "library"
        break
      end
    end
    
    if not project_type then
      project_type = "unknown"
    end
  else
    return nil
  end
  
  return {
    file = project_file,
    name = project_name,
    directory = project_dir,
    type = project_type,
    platform = platform_config.platform
  }
end

-- Build project helper
function M.build_project(project_info, callback)
  if not project_info then
    project_info = M.get_project_info()
  end
  
  if not project_info then
    vim.notify(string.format(
      "[%s] No C# project found",
      platform_config.platform
    ), vim.log.levels.ERROR)
    return
  end
  
  vim.notify(string.format(
    "[%s] Building C# project: %s (%s)",
    platform_config.platform,
    project_info.name,
    project_info.type
  ), vim.log.levels.INFO)
  
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

-- Run project
function M.run_project()
  local project_info = M.get_project_info()
  
  if not project_info then
    vim.notify(string.format(
      "[%s] No C# project found",
      platform_config.platform
    ), vim.log.levels.ERROR)
    return
  end
  
  vim.notify(string.format(
    "[%s] Running C# project: %s",
    platform_config.platform,
    project_info.name
  ), vim.log.levels.INFO)
  
  local run_cmd = { "dotnet", "run", "--project", project_info.file }
  
  vim.fn.jobstart(run_cmd, {
    cwd = project_info.directory,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ Execution completed successfully", vim.log.levels.INFO)
      else
        vim.notify("❌ Execution failed with exit code: " .. code, vim.log.levels.ERROR)
      end
    end,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            print("Run: " .. line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            vim.notify("Run Error: " .. line, vim.log.levels.ERROR)
          end
        end
      end
    end
  })
end

-- Test project
function M.test_project()
  local project_info = M.get_project_info()
  
  if not project_info then
    vim.notify(string.format(
      "[%s] No C# project found",
      platform_config.platform
    ), vim.log.levels.ERROR)
    return
  end
  
  vim.notify(string.format(
    "[%s] Testing C# project: %s",
    platform_config.platform,
    project_info.name
  ), vim.log.levels.INFO)
  
  local test_cmd = { "dotnet", "test", project_info.file }
  
  vim.fn.jobstart(test_cmd, {
    cwd = project_info.directory,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ All tests passed!", vim.log.levels.INFO)
      else
        vim.notify("❌ Tests failed with exit code: " .. code, vim.log.levels.ERROR)
      end
    end,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            print("Test: " .. line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            vim.notify("Test Error: " .. line, vim.log.levels.ERROR)
          end
        end
      end
    end
  })
end

-- Check .NET environment
function M.check_environment()
  vim.notify(string.format("=== C#/.NET Environment Check [%s] ===", platform_config.platform), vim.log.levels.INFO)
  
  -- Check dotnet CLI
  if vim.fn.executable("dotnet") == 1 then
    vim.notify("✅ dotnet CLI found", vim.log.levels.INFO)
    
    -- Get dotnet version
    vim.fn.jobstart({ "dotnet", "--version" }, {
      on_stdout = function(_, data)
        if data and data[1] then
          vim.notify("  .NET SDK Version: " .. data[1], vim.log.levels.INFO)
        end
      end,
      on_stderr = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line and line ~= "" then
              vim.notify("dotnet Error: " .. line, vim.log.levels.ERROR)
            end
          end
        end
      end
    })
  else
    vim.notify("❌ dotnet CLI not found", vim.log.levels.ERROR)
  end
  
  -- Check Omnisharp (if applicable)
  if platform_config.is_omnisharp then
    local omnisharp_path = platform_config.omnisharp_server_path()
    if vim.fn.filereadable(omnisharp_path) == 1 then
      vim.notify("✅ Omnisharp executable found: " .. omnisharp_path, vim.log.levels.INFO)
    else
      vim.notify("❌ Omnisharp executable not found at: " .. omnisharp_path, vim.log.levels.ERROR)
      vim.notify("       Please ensure Omnisharp is installed and configured correctly.", vim.log.levels.WARN)
    end
  end
end

return M
