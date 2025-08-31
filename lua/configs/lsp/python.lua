-- lua/configs/lsp/python.lua
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

-- Find Python executable with virtual environment support
local function get_python_command()
  local cwd = vim.fn.getcwd()
  
  -- Check for virtual environments in order of preference
  local venv_paths = {
    cwd .. "/.venv/bin/python",
    cwd .. "/.venv/bin/python3",
    cwd .. "/venv/bin/python", 
    cwd .. "/venv/bin/python3",
    cwd .. "/env/bin/python",
    cwd .. "/env/bin/python3",
    os.getenv("HOME") .. "/.virtualenvs/" .. vim.fn.fnamemodify(cwd, ":t") .. "/bin/python",
    os.getenv("HOME") .. "/.virtualenvs/" .. vim.fn.fnamemodify(cwd, ":t") .. "/bin/python3",
  }
  
  if get_platform() == "windows" then
    -- Windows virtual environment paths
    local win_venv_paths = {
      cwd .. "\\.venv\\Scripts\\python.exe",
      cwd .. "\\venv\\Scripts\\python.exe",
      cwd .. "\\env\\Scripts\\python.exe",
      os.getenv("USERPROFILE") .. "\\Envs\\" .. vim.fn.fnamemodify(cwd, ":t") .. "\\Scripts\\python.exe",
    }
    venv_paths = win_venv_paths
  end
  
  -- Check virtual environment paths first
  for _, python_path in ipairs(venv_paths) do
    if vim.fn.executable(python_path) == 1 then
      return python_path
    end
  end
  
  -- Fall back to system Python
  if vim.fn.executable("python3") == 1 then
    return "python3"
  elseif vim.fn.executable("python") == 1 then
    return "python"
  else
    vim.notify("Neither 'python3' nor 'python' found in PATH", vim.log.levels.WARN)
    return "python3"
  end
end

-- Get pip command
local function get_pip_command()
  local python_cmd = get_python_command()
  
  -- If using virtual environment, pip should be available
  if python_cmd:match("/bin/python") or python_cmd:match("Scripts\\python") then
    local pip_path = python_cmd:gsub("python3?", "pip")
    if vim.fn.executable(pip_path) == 1 then
      return pip_path
    end
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

-- Detect Python project type and get info
local function get_python_project_info()
  local cwd = vim.fn.getcwd()
  local project_info = {
    directory = cwd,
    python_path = get_python_command(),
    pip_path = get_pip_command(),
    project_type = "generic",
    main_file = nil,
    requirements_file = nil,
    config_files = {}
  }
  
  -- Detect project type and files
  local project_files = {
    { file = "pyproject.toml", type = "modern_python" },
    { file = "setup.py", type = "setuptools" },
    { file = "requirements.txt", type = "pip" },
    { file = "Pipfile", type = "pipenv" },
    { file = "poetry.lock", type = "poetry" },
    { file = "manage.py", type = "django" },
    { file = "app.py", type = "flask" },
    { file = "main.py", type = "generic" },
    { file = "__init__.py", type = "package" },
    { file = "setup.cfg", type = "setuptools" },
    { file = "pyproject.ini", type = "setuptools" },
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

-- Find language servers
local function find_pyright()
  local mason_path = vim.fn.stdpath("data") .. "/mason/bin"
  local paths = { mason_path }
  
  if get_platform() == "windows" then
    return vim.fn.exepath("pyright-langserver.exe") ~= "" and "pyright-langserver.exe" or nil
  else
    return vim.fn.exepath("pyright-langserver") ~= "" and "pyright-langserver" or nil
  end
end

local function find_ruff()
  local mason_path = vim.fn.stdpath("data") .. "/mason/bin"
  
  if get_platform() == "windows" then
    return vim.fn.exepath("ruff-lsp.exe") ~= "" and "ruff-lsp.exe" or nil
  else
    return vim.fn.exepath("ruff") ~= "" and "ruff" or nil
  end
end

-- Setup Python LSP
function M.setup_lsp(capabilities)
  local lspconfig = require("lspconfig")
  
  -- Setup Pyright (type checking and IntelliSense)
  local pyright_cmd = find_pyright()
  if pyright_cmd then
    lspconfig.pyright.setup({
      capabilities = capabilities,
      cmd = { pyright_cmd, "--stdio" },
      settings = {
        python = {
          pythonPath = get_python_command(),
          analysis = {
            typeCheckingMode = "basic", -- "off", "basic", "strict"
            autoSearchPaths = true,
            diagnosticMode = "workspace", -- "openFilesOnly", "workspace"
            useLibraryCodeForTypes = true,
            autoImportCompletions = true,
            stubPath = vim.fn.stdpath("data") .. "/lazy/python-type-stubs",
          },
          linting = {
            enabled = false, -- Let ruff handle linting
          },
        },
      },
      root_dir = function(fname)
        local root_files = {
          'pyproject.toml',
          'setup.py',
          'setup.cfg',
          'requirements.txt',
          'Pipfile',
          'pyrightconfig.json',
          '.git',
        }
        return lspconfig.util.root_pattern(unpack(root_files))(fname) or lspconfig.util.path.dirname(fname)
      end,
      on_attach = function(client, bufnr)
        -- Disable formatting capabilities (let ruff handle it)
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
        
        -- Python-specific keymaps
        local opts = { buffer = bufnr, noremap = true, silent = true }
        local python_cmd = get_python_command()
        local pip_cmd = get_pip_command()
        
        vim.keymap.set("n", "<leader>pr", function()
          vim.cmd("!" .. python_cmd .. " " .. vim.fn.expand("%"))
        end, vim.tbl_extend('force', opts, { desc = "Run Python file" }))
        
        vim.keymap.set("n", "<leader>pt", function()
          vim.cmd("!" .. python_cmd .. " -m pytest")
        end, vim.tbl_extend('force', opts, { desc = "Run pytest" }))
        
        vim.keymap.set("n", "<leader>pi", function()
          local project_info = get_python_project_info()
          if project_info.requirements_file then
            vim.cmd("!" .. pip_cmd .. " install -r " .. project_info.requirements_file)
          else
            vim.notify("No requirements.txt found", vim.log.levels.WARN)
          end
        end, vim.tbl_extend('force', opts, { desc = "Install requirements" }))
        
        vim.keymap.set("n", "<leader>pv", function()
          vim.cmd("!" .. python_cmd .. " -m venv .venv")
        end, vim.tbl_extend('force', opts, { desc = "Create virtual environment" }))
        
        vim.keymap.set("n", "<leader>po", function()
          vim.cmd("!" .. python_cmd .. " -m py_compile " .. vim.fn.expand("%"))
        end, vim.tbl_extend('force', opts, { desc = "Python syntax check" }))
        
        vim.keymap.set("n", "<leader>pf", function()
          vim.cmd("!" .. python_cmd .. " -m black " .. vim.fn.expand("%"))
        end, vim.tbl_extend('force', opts, { desc = "Format with black" }))
        
        -- Django specific commands
        local project_info = get_python_project_info()
        if project_info.project_type == "django" then
          vim.keymap.set("n", "<leader>dm", function()
            vim.cmd("!" .. python_cmd .. " manage.py migrate")
          end, vim.tbl_extend('force', opts, { desc = "Django migrate" }))
          
          vim.keymap.set("n", "<leader>dr", function()
            vim.cmd("!" .. python_cmd .. " manage.py runserver")
          end, vim.tbl_extend('force', opts, { desc = "Django runserver" }))
          
          vim.keymap.set("n", "<leader>ds", function()
            vim.cmd("!" .. python_cmd .. " manage.py shell")
          end, vim.tbl_extend('force', opts, { desc = "Django shell" }))
        end
      end,
    })
  else
    vim.notify("Pyright not found. Install via :MasonInstall pyright", vim.log.levels.WARN)
  end
  
  -- Setup Ruff LSP (linting and formatting)
  local ruff_cmd = find_ruff()
  if ruff_cmd then
    lspconfig.ruff.setup({
      capabilities = capabilities,
      cmd = { ruff_cmd, "--preview", "--watch" }, -- Add --preview and --watch
      init_options = {
        settings = {
          -- Ruff configuration
          args = {
            "--line-length=88",
            "--select=E,W,F,I,N,UP,YTT,ANN,S,BLE,FBT,B,A,COM,C4,DTZ,T10,EM,EXE,ISC,ICN,G,INP,PIE,T20,PYI,PT,Q,RSE,RET,SLF,SIM,TID,TCH,INT,ARG,PTH,ERA,PD,PGH,PL,TRY,NPY,RUF",
            "--ignore=E501,W503,E203",
          },
        },
      },
      on_attach = function(client, bufnr)
        -- Enable formatting for ruff
        client.server_capabilities.documentFormattingProvider = true
        client.server_capabilities.documentRangeFormattingProvider = true
      end,
    })
  else
    vim.notify("Ruff LSP not found. Install via :MasonInstall ruff-lsp", vim.log.levels.WARN)
  end
end

-- Get project information helper
function M.get_project_info()
  return get_python_project_info()
end

-- Setup virtual environment
function M.setup_venv(venv_name)
  venv_name = venv_name or ".venv"
  local python_cmd = get_python_command()
  local cwd = vim.fn.getcwd()
  
  vim.notify("Creating virtual environment: " .. venv_name, vim.log.levels.INFO)
  
  vim.fn.jobstart({ python_cmd, "-m", "venv", venv_name }, {
    cwd = cwd,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ Virtual environment created successfully!", vim.log.levels.INFO)
        vim.notify("Activate with: source " .. venv_name .. "/bin/activate", vim.log.levels.INFO)
      else
        vim.notify("❌ Failed to create virtual environment", vim.log.levels.ERROR)
      end
    end
  })
end

-- Install requirements
function M.install_requirements()
  local project_info = get_python_project_info()
  
  if not project_info.requirements_file then
    vim.notify("No requirements.txt found", vim.log.levels.WARN)
    return
  end
  
  vim.notify("Installing requirements...", vim.log.levels.INFO)
  
  vim.fn.jobstart({ project_info.pip_path, "install", "-r", project_info.requirements_file }, {
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
  local project_info = get_python_project_info()
  
  vim.notify("Running: " .. file_path, vim.log.levels.INFO)
  
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
  local project_info = get_python_project_info()
  local test_cmd = { project_info.python_path, "-m", "pytest" }
  
  if test_path then
    table.insert(test_cmd, test_path)
  end
  
  vim.notify("Running tests...", vim.log.levels.INFO)
  
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
  local project_info = get_python_project_info()
  
  vim.notify("🐍 Python Environment Check", vim.log.levels.INFO)
  vim.notify("Project type: " .. project_info.project_type, vim.log.levels.INFO)
  vim.notify("Python path: " .. project_info.python_path, vim.log.levels.INFO)
  vim.notify("Pip path: " .. project_info.pip_path, vim.log.levels.INFO)
  
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
  
  -- Check for common Python tools
  local tools = {
    { "black", "Code formatter" },
    { "flake8", "Linter" }, 
    { "mypy", "Type checker" },
    { "pytest", "Testing framework" },
    { "isort", "Import sorter" },
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

return M