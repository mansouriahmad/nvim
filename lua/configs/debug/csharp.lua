return {
  -- C# debugger adapter (netcoredbg)
  setup_adapter = function(dap)
    dap.adapters.coreclr = {
      type = "executable",
      command = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg",
      args = { "--interpreter=vscode" },
    }

    -- Alternative adapter for newer setups (if netcoredbg doesn't work)
    dap.adapters.dotnet = {
      type = "executable",
      command = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg",
      args = { "--interpreter=vscode" },
    }
  end,

  -- Helper function to find C# executable and project info
  get_csharp_debug_info = function()
    local cwd = vim.fn.getcwd()

    -- Check if dotnet is available
    if vim.fn.executable("dotnet") == 0 then
      vim.notify("dotnet CLI not found in PATH", vim.log.levels.ERROR)
      return nil
    end

    -- Find .csproj or .sln files
    local sln_files = vim.fn.glob(cwd .. "/*.sln", false, true)
    local csproj_files = vim.fn.glob(cwd .. "/**/*.csproj", false, true)

    local project_file = nil
    local project_name = nil
    local project_dir = cwd

    if #sln_files > 0 then
      -- For solution files, we need to find the startup project
      project_file = sln_files[1]
      project_name = vim.fn.fnamemodify(project_file, ":t:r")

      -- Try to find a console app or web app in the solution
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

    -- Determine the output directory and executable
    local debug_dir = project_dir .. "/bin/Debug"
    local possible_dlls = vim.fn.glob(debug_dir .. "/**/" .. project_name .. ".dll", false, true)

    local dll_path = nil
    if #possible_dlls > 0 then
      -- Use the most recent one (likely the correct target framework)
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
  end,

  build_csharp_project = function(project_info, callback)
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
  end,

  -- C# debugging configurations
  setup_configurations = function(dap, get_csharp_debug_info)
    dap.configurations.cs = {
      {
        type = "coreclr",
        name = "Launch C# Application",
        request = "launch",
        program = function()
          local project_info = get_csharp_debug_info()
          if not project_info then
            return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
          end

          -- If we have a dll path from build output, use it
          if project_info.dll_path and vim.fn.filereadable(project_info.dll_path) == 1 then
            return project_info.dll_path
          end

          -- Otherwise, try to find it in common locations
          local debug_dir = project_info.project_dir .. "/bin/Debug"
          local possible_dlls = vim.fn.glob(debug_dir .. "/**/" .. project_info.project_name .. ".dll", false, true)

          if #possible_dlls > 0 then
            return possible_dlls[1]
          end

          -- Fallback to user input
          return vim.fn.input("Path to dll: ", debug_dir .. "/", "file")
        end,
        cwd = "${workspaceFolder}",
        console = "integratedTerminal",
        args = {},
      },
      {
        type = "coreclr",
        name = "Attach to Process",
        request = "attach",
        processId = function()
          return require('dap.utils').pick_process({
            filter = function(proc)
              return proc.name:find('dotnet') or proc.name:find('.exe')
            end
          })
        end,
      },
      {
        type = "coreclr",
        name = "Launch ASP.NET Core",
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
      },
    }

    -- Also support .csharp extension (some projects use this)
    dap.configurations.csharp = dap.configurations.cs
  end,

  check_and_install_debugger = function()
    local netcoredbg_path = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg"
    if vim.fn.executable(netcoredbg_path) == 0 then
      vim.notify("netcoredbg not found. Installing via Mason...", vim.log.levels.WARN)
      vim.cmd("MasonInstall netcoredbg")
    end
  end,
}

