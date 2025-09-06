-- lua/configs/lsp/python.lua
-- Simplified Python LSP configuration using platform_config

local M = {}
local platform_config = require('configs.lsp.platform_config')

-- Setup Python LSP
function M.setup_lsp(capabilities)
  local lspconfig = require("lspconfig")

  -- Use the platform-specific setup
  local success = platform_config.setup_python_lsp(lspconfig, capabilities)

  if success then
    -- Additional Python-specific setup if needed
    vim.api.nvim_create_autocmd("BufReadPost", {
      pattern = { "*.py", "*.pyw", "*.pyi" },
      callback = function()
        -- Set Python-specific options
        vim.opt_local.commentstring = '# %s'
        vim.opt_local.shiftwidth = 4
        vim.opt_local.tabstop = 4
        vim.opt_local.expandtab = true
      end,
    })
  end

  return success
end

-- Get Python project information
function M.get_project_info()
  local cwd = vim.fn.getcwd()
  local project_info = {
    directory = cwd,
    python_path = platform_config.python.find_python(),
    project_type = "generic",
    main_file = nil,
    requirements_file = nil,
    config_files = {},
    venv_path = nil,
    platform = platform_config.platform
  }

  -- Detect project type and files
  local project_files = {
    { file = "pyproject.toml",   type = "modern_python" },
    { file = "setup.py",         type = "setuptools" },
    { file = "requirements.txt", type = "pip" },
    { file = "Pipfile",          type = "pipenv" },
    { file = "poetry.lock",      type = "poetry" },
    { file = "manage.py",        type = "django" },
    { file = "app.py",           type = "flask" },
    { file = "main.py",          type = "generic" },
  }

  for _, pf in ipairs(project_files) do
    if vim.fn.filereadable(cwd .. "/" .. pf.file) == 1 then
      project_info.project_type = pf.type
      if pf.file == "requirements.txt" then
        project_info.requirements_file = cwd .. "/" .. pf.file
      elseif pf.file == "main.py" or pf.file == "app.py" or pf.file == "manage.py" then
        project_info.main_file = cwd .. "/" .. pf.file
      end
      table.insert(project_info.config_files, pf.file)
    end
  end

  -- Look for virtual environment
  local venv_indicators = {
    ".venv", "venv", "env", ".env"
  }

  for _, venv_name in ipairs(venv_indicators) do
    if vim.fn.isdirectory(cwd .. "/" .. venv_name) == 1 then
      project_info.venv_path = cwd .. "/" .. venv_name
      break
    end
  end

  return project_info
end

-- Get pip command
function M.get_pip_command()
  local python_cmd = platform_config.python.find_python()

  if not python_cmd then
    return "pip3"
  end

  -- Try to use pip from the same location as python
  local pip_path = python_cmd:gsub("python[3]?", "pip")
  if platform_config.executable_exists(pip_path) then
    return pip_path
  end

  -- Fall back to system pip
  if vim.fn.executable("pip3") == 1 then
    return "pip3"
  elseif vim.fn.executable("pip") == 1 then
    return "pip"
  else
    return "pip3"
  end
end

-- Setup virtual environment
function M.setup_venv(venv_name)
  venv_name = venv_name or ".venv"
  local python_cmd = platform_config.python.find_python()
  local cwd = vim.fn.getcwd()

  if not python_cmd then
    vim.notify(string.format(
      "[%s] Python not found. Cannot create virtual environment",
      platform_config.platform
    ), vim.log.levels.ERROR)
    return
  end

  vim.notify(string.format(
    "[%s] Creating virtual environment: %s",
    platform_config.platform,
    venv_name
  ), vim.log.levels.INFO)

  vim.fn.jobstart({ python_cmd, "-m", "venv", venv_name }, {
    cwd = cwd,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ Virtual environment created successfully!", vim.log.levels.INFO)
        if platform_config.is_windows then
          vim.notify("Activate with: " .. venv_name .. "\\Scripts\\activate", vim.log.levels.INFO)
        else
          vim.notify("Activate with: source " .. venv_name .. "/bin/activate", vim.log.levels.INFO)
        end
      else
        vim.notify("❌ Failed to create virtual environment", vim.log.levels.ERROR)
      end
    end
  })
end

-- Install requirements
function M.install_requirements()
  local project_info = M.get_project_info()

  if not project_info.requirements_file then
    vim.notify(string.format(
      "[%s] No requirements.txt found",
      platform_config.platform
    ), vim.log.levels.WARN)
    return
  end

  local pip_cmd = M.get_pip_command()

  vim.notify(string.format(
    "[%s] Installing requirements...",
    platform_config.platform
  ), vim.log.levels.INFO)

  vim.fn.jobstart({ pip_cmd, "install", "-r", project_info.requirements_file }, {
    cwd = project_info.directory,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ Requirements installed successfully!", vim.log.levels.INFO)
      else
        vim.notify("❌ Failed to install requirements", vim.log.levels.ERROR)
      end
    end
  })
end

-- Run Python file
function M.run_file(file_path)
  file_path = file_path or vim.fn.expand("%")
  local project_info = M.get_project_info()

  if not project_info.python_path then
    vim.notify(string.format(
      "[%s] Python not found",
      platform_config.platform
    ), vim.log.levels.ERROR)
    return
  end

  vim.notify(string.format(
    "[%s] Running: %s",
    platform_config.platform,
    file_path
  ), vim.log.levels.INFO)

  vim.fn.jobstart({ project_info.python_path, file_path }, {
    cwd = project_info.directory,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ Execution completed successfully", vim.log.levels.INFO)
      else
        vim.notify("❌ Execution failed with exit code: " .. code, vim.log.levels.ERROR)
      end
    end
  })
end

-- Run tests
function M.run_tests(test_path)
  local project_info = M.get_project_info()

  if not project_info.python_path then
    vim.notify(string.format(
      "[%s] Python not found",
      platform_config.platform
    ), vim.log.levels.ERROR)
    return
  end

  local test_cmd = { project_info.python_path, "-m", "pytest" }

  if test_path then
    table.insert(test_cmd, test_path)
  end

  vim.notify(string.format(
    "[%s] Running tests...",
    platform_config.platform
  ), vim.log.levels.INFO)

  vim.fn.jobstart(test_cmd, {
    cwd = project_info.directory,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ All tests passed!", vim.log.levels.INFO)
      else
        vim.notify("❌ Tests failed with exit code: " .. code, vim.log.levels.ERROR)
      end
    end
  })
end

-- Check Python environment
function M.check_environment()
  local project_info = M.get_project_info()

  vim.notify(string.format("=== Python Environment Check [%s] ===", platform_config.platform), vim.log.levels.INFO)
  vim.notify("Project type: " .. project_info.project_type, vim.log.levels.INFO)

  if project_info.python_path then
    vim.notify("Python path: " .. project_info.python_path, vim.log.levels.INFO)
  else
    vim.notify("Python path: NOT FOUND", vim.log.levels.ERROR)
  end

  local pip_path = M.get_pip_command()
  vim.notify("Pip path: " .. pip_path, vim.log.levels.INFO)

  if project_info.venv_path then
    vim.notify("Virtual environment: " .. project_info.venv_path, vim.log.levels.INFO)
  else
    vim.notify("No virtual environment detected", vim.log.levels.WARN)
  end

  if project_info.main_file then
    vim.notify("Main file: " .. project_info.main_file, vim.log.levels.INFO)
  end

  if project_info.requirements_file then
    vim.notify("Requirements file: " .. project_info.requirements_file, vim.log.levels.INFO)
  end

  -- Check LSP servers
  local pyright = platform_config.python.find_pyright()
  local ruff = platform_config.python.find_ruff()

  if pyright then
    vim.notify("✅ pyright found at: " .. pyright, vim.log.levels.INFO)
  else
    vim.notify("❌ pyright not found", vim.log.levels.WARN)
  end

  if ruff then
    vim.notify("✅ ruff found at: " .. ruff, vim.log.levels.INFO)
  else
    vim.notify("❌ ruff not found", vim.log.levels.WARN)
  end

  -- Check for common Python tools
  if project_info.python_path then
    local tools = {
      { "black",  "Code formatter" },
      { "flake8", "Linter" },
      { "mypy",   "Type checker" },
      { "pytest", "Testing framework" },
      { "isort",  "Import sorter" },
    }

    for _, tool in ipairs(tools) do
      local cmd = { project_info.python_path, "-m", tool[1], "--version" }
      vim.fn.jobstart(cmd, {
        on_exit = function(_, code)
          if code == 0 then
            vim.notify("✅ " .. tool[2] .. " (" .. tool[1] .. ") available", vim.log.levels.INFO)
          else
            vim.notify("❌ " .. tool[2] .. " (" .. tool[1] .. ") not available", vim.log.levels.WARN)
          end
        end,
        stdout_buffered = true,
        stderr_buffered = true,
      })
    end
  end
end

-- Setup Python-specific keymaps
function M.setup_keymaps(client, bufnr, desc_opts)
  -- No specific keymaps for Python by default in this setup
  -- If you want to add some, uncomment and modify the following lines:
  -- vim.keymap.set("n", "<leader>pyf", function()
  --   vim.lsp.buf.format({ async = true })
  -- end, desc_opts("Format Python file"))
end

return M
