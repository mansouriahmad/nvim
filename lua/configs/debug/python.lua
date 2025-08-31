-- lua/configs/debug/python.lua
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

-- Find debugpy executable with robust path detection
local function find_debugpy()
  local mason_path = vim.fn.stdpath("data") .. "/mason"
  local platform = get_platform()
  
  local debugpy_paths = {
    mason_path .. "/bin/debugpy-adapter",
    mason_path .. "/packages/debugpy/venv/bin/python",
  }
  
  if platform == "windows" then
    table.insert(debugpy_paths, mason_path .. "/bin/debugpy-adapter.exe")
    table.insert(debugpy_paths, mason_path .. "/packages/debugpy/venv/Scripts/python.exe")
    table.insert(debugpy_paths, "C:/Program Files/debugpy/debugpy-adapter.exe")
  else
    table.insert(debugpy_paths, "/usr/local/bin/debugpy-adapter")
    table.insert(debugpy_paths, "/opt/homebrew/bin/debugpy-adapter")
    table.insert(debugpy_paths, os.getenv("HOME") .. "/.local/bin/debugpy-adapter")
  end
  
  -- Check all paths
  for _, path in ipairs(debugpy_paths) do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end
  
  -- Check PATH
  local path_exe = vim.fn.exepath("debugpy-adapter")
  if path_exe ~= "" then
    return path_exe
  end
  
  return nil
end

-- Find Python executable with virtual environment support
local function get_python_path()
  local cwd = vim.fn.getcwd()
  
  -- Check for virtual environments in order of preference
  local venv_paths = {
    cwd .. "/.venv/bin/python3",
    cwd .. "/.venv/bin/python",
    cwd .. "/venv/bin/python3",
    cwd .. "/venv/bin/python",
    cwd .. "/env/bin/python3",
    cwd .. "/env/bin/python",
    os.getenv("HOME") .. "/.virtualenvs/" .. vim.fn.fnamemodify(cwd, ":t") .. "/bin/python3",
    os.getenv("HOME") .. "/.virtualenvs/" .. vim.fn.fnamemodify(cwd, ":t") .. "/bin/python",
  }
  
  if get_platform() == "windows" then
    -- Windows virtual environment paths
    venv_paths = {
      cwd .. "\\.venv\\Scripts\\python.exe",
      cwd .. "\\venv\\Scripts\\python.exe",
      cwd .. "\\env\\Scripts\\python.exe",
      os.getenv("USERPROFILE") .. "\\Envs\\" .. vim.fn.fnamemodify(cwd, ":t") .. "\\Scripts\\python.exe",
    }
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

-- Detect Python project information
local function get_python_project_info()
  local cwd = vim.fn.getcwd()
  local project_info = {
    directory = cwd,
    python_path = get_python_path(),
    project_type = "generic",
    main_file = nil,
    manage_py = nil,
    requirements_file = nil,
    is_django = false,
    is_flask = false,
    venv_path = nil
  }
  
  -- Detect project files
  if vim.fn.filereadable(cwd .. "/manage.py") == 1 then
    project_info.project_type = "django"
    project_info.is_django = true
    project_info.manage_py = cwd .. "/manage.py"
  elseif vim.fn.filereadable(cwd .. "/app.py") == 1 then
    project_info.project_type = "flask"
    project_info.is_flask = true
    project_info.main_file = cwd .. "/app.py"
  elseif vim.fn.filereadable(cwd .. "/main.py") == 1 then
    project_info.main_file = cwd .. "/main.py"
  end
  
  if vim.fn.filereadable(cwd .. "/requirements.txt") == 1 then
    project_info.requirements_file = cwd .. "/requirements.txt"
  end
  
  -- Check for virtual environment
  local venv_dirs = { ".venv", "venv", "env", ".env" }
  for _, venv_dir in ipairs(venv_dirs) do
    if vim.fn.isdirectory(cwd .. "/" .. venv_dir) == 1 then
      project_info.venv_path = cwd .. "/" .. venv_dir
      break
    end
  end
  
  return project_info
end

-- Setup Python debugger
function M.setup_debugger()
  local dap = require("dap")
  
  -- Try to find debugpy
  local debugpy_path = find_debugpy()
  
  if not debugpy_path then
    vim.notify(
      "debugpy not found. Install via: :MasonInstall debugpy",
      vim.log.levels.WARN
    )
    return false
  end
  
  vim.notify("Using debugpy at: " .. debugpy_path, vim.log.levels.INFO)
  
  -- Configure debugpy adapter
  dap.adapters.python = function(cb, config)
    if config.request == 'attach' then
      ---@diagnostic disable-next-line: undefined-field
      local port = (config.connect or config).port
      ---@diagnostic disable-next-line: undefined-field
      local host = (config.connect or config).host or '127.0.0.1'
      cb({
        type = 'server',
        port = assert(port, '`connect.port` is required for a python `attach` configuration'),
        host = host,
        options = {
          source_filetype = 'python',
        },
      })
    else
      cb({
        type = 'executable',
        command = debugpy_path,
        options = {
          source_filetype = 'python',
        },
      })
    end
  end
  
  return true
end

-- Setup Python debug configurations
function M.setup_configurations()
  local dap = require("dap")
  
  dap.configurations.python = {
    {
      type = 'python',
      request = 'launch',
      name = "🚀 Launch Current File",
      program = "${file}",
      pythonPath = get_python_path,
      console = "integratedTerminal",
      args = {},
      cwd = "${workspaceFolder}",
    },
    {
      type = 'python',
      request = 'launch',
      name = "📋 Launch with Arguments",
      program = "${file}",
      pythonPath = get_python_path,
      console = "integratedTerminal",
      args = function()
        local args_str = vim.fn.input("Arguments: ")
        return vim.split(args_str, " ", true)
      end,
      cwd = "${workspaceFolder}",
    },
    {
      type = 'python',
      request = 'launch',
      name = "📦 Launch Python Module",
      module = function()
        return vim.fn.input("Module name: ")
      end,
      pythonPath = get_python_path,
      console = "integratedTerminal",
      args = {},
      cwd = "${workspaceFolder}",
    },
    {
      type = 'python',
      request = 'launch',
      name = "🧪 Debug pytest",
      module = "pytest",
      args = function()
        local test_file = vim.fn.input("Test file (or leave empty for all): ", "${file}")
        if test_file == "${file}" then
          return { "${file}" }
        elseif test_file == "" then
          return {}
        else
          return { test_file }
        end
      end,
      pythonPath = get_python_path,
      console = "integratedTerminal",
      cwd = "${workspaceFolder}",
    },
    {
      type = 'python',
      request = 'launch',
      name = "🧪 Debug unittest",
      module = "unittest",
      args = function()
        local test_module = vim.fn.input("Test module (e.g., tests.test_module): ")
        return test_module ~= "" and { test_module } or {}
      end,
      pythonPath = get_python_path,
      console = "integratedTerminal",
      cwd = "${workspaceFolder}",
    },
    {
      type = 'python',
      request = 'launch',
      name = "🌐 Debug Django",
      program = function()
        local project_info = get_python_project_info()
        return project_info.manage_py or vim.fn.getcwd() .. "/manage.py"
      end,
      args = { "runserver", "--noreload", "127.0.0.1:8000" },
      pythonPath = get_python_path,
      console = "integratedTerminal",
      env = {
        DJANGO_SETTINGS_MODULE = function()
          local settings_module = vim.fn.input("Django settings module (default: myproject.settings): ", "myproject.settings")
          return settings_module
        end,
        DEBUG = "True",
      },
      cwd = "${workspaceFolder}",
    },
    {
      type = 'python',
      request = 'launch',
      name = "🌶️ Debug Flask",
      program = function()
        local project_info = get_python_project_info()
        if project_info.main_file then
          return project_info.main_file
        else
          return vim.fn.input("Flask app file: ", vim.fn.getcwd() .. "/app.py", "file")
        end
      end,
      args = {},
      pythonPath = get_python_path,
      console = "integratedTerminal",
      env = {
        FLASK_ENV = "development",
        FLASK_DEBUG = "1",
        FLASK_APP = function()
          local flask_app = vim.fn.input("Flask app (default: app.py): ", "app.py")
          return flask_app
        end,
      },
      cwd = "${workspaceFolder}",
    },
    {
      type = 'python',
      request = 'launch',
      name = "⚡ Debug FastAPI",
      module = "uvicorn",
      args = function()
        local app_module = vim.fn.input("App module (e.g., main:app): ", "main:app")
        return { app_module, "--reload", "--port", "8000" }
      end,
      pythonPath = get_python_path,
      console = "integratedTerminal",
      cwd = "${workspaceFolder}",
    },
    {
      type = 'python',
      request = 'attach',
      name = "📎 Attach to Remote",
      connect = function()
        local host = vim.fn.input("Host: ", "localhost")
        local port = tonumber(vim.fn.input("Port: ", "5678"))
        return { host = host, port = port }
      end,
      pathMappings = {
        {
          localRoot = "${workspaceFolder}",
          remoteRoot = function()
            return vim.fn.input("Remote root: ", "/app")
          end,
        },
      },
    },
    {
      type = 'python',
      request = 'launch',
      name = "📓 Debug Jupyter Notebook",
      module = "jupyter",
      args = { "notebook", "--no-browser", "--allow-root" },
      pythonPath = get_python_path,
      console = "integratedTerminal",
      cwd = "${workspaceFolder}",
    },
  }
end

-- Build and debug helper (for Python it's more like "run and debug")
function M.run_and_debug()
  local project_info = get_python_project_info()
  local dap = require('dap')
  
  vim.notify('Starting Python debugger...', vim.log.levels.INFO)
  
  -- Choose appropriate configuration based on project type
  if project_info.is_django then
    dap.run(dap.configurations.python[5]) -- Django configuration
  elseif project_info.is_flask then
    dap.run(dap.configurations.python[6]) -- Flask configuration
  else
    dap.run(dap.configurations.python[1]) -- Launch current file
  end
end

-- Quick project commands
function M.setup_keymaps()
  vim.keymap.set('n', '<leader>pdb', M.run_and_debug, { desc = 'Run and Debug Python' })
  
  local project_info = get_python_project_info()
  
  vim.keymap.set("n", "<leader>pr", function()
    vim.cmd("!" .. project_info.python_path .. " " .. vim.fn.expand("%"))
  end, { desc = "Run Python file" })
  
  vim.keymap.set("n", "<leader>pt", function()
    vim.cmd("!" .. project_info.python_path .. " -m pytest")
  end, { desc = "Run pytest" })
  
  if project_info.is_django then
    vim.keymap.set("n", "<leader>dm", function()
      vim.cmd("!" .. project_info.python_path .. " manage.py migrate")
    end, { desc = "Django migrate" })
    
    vim.keymap.set("n", "<leader>dr", function()
      vim.cmd("!" .. project_info.python_path .. " manage.py runserver")
    end, { desc = "Django runserver" })
  end
end

-- Install debugger helper
function M.install_debugpy()
  local python_path = get_python_path()
  vim.notify("Installing debugpy...", vim.log.levels.INFO)
  
  vim.fn.jobstart({ python_path, "-m", "pip", "install", "debugpy" }, {
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ debugpy installed successfully!", vim.log.levels.INFO)
      else
        vim.notify("❌ Failed to install debugpy", vim.log.levels.ERROR)
      end
    end
  })
end

-- Auto-install debugger when Python file is opened
function M.ensure_debugger_installed()
  local debugger = find_debugpy()
  if not debugger then
    vim.notify("debugpy not found. Installing via Mason...", vim.log.levels.WARN)
    vim.cmd("MasonInstall debugpy")
  end
end

-- Remote debugging helper
function M.start_remote_debug_server(port)
  port = port or 5678
  local python_path = get_python_path()
  
  vim.notify("Starting debugpy server on port " .. port, vim.log.levels.INFO)
  
  vim.fn.jobstart({
    python_path, "-c",
    string.format([[
import debugpy
debugpy.listen(%d)
print("Waiting for debugger attach on port %d...")
debugpy.wait_for_client()
print("Debugger attached!")
]], port, port)
  }, {
    on_exit = function(_, code)
      vim.notify("Debug server stopped with code: " .. code, vim.log.levels.INFO)
    end
  })
end

-- Check Python environment and debugger setup
function M.check_debug_environment()
  local project_info = get_python_project_info()
  local debugpy_path = find_debugpy()
  
  vim.notify("🐍 Python Debug Environment Check", vim.log.levels.INFO)
  vim.notify("Project type: " .. project_info.project_type, vim.log.levels.INFO)
  vim.notify("Python path: " .. project_info.python_path, vim.log.levels.INFO)
  
  if debugpy_path then
    vim.notify("✅ debugpy found at: " .. debugpy_path, vim.log.levels.INFO)
  else
    vim.notify("❌ debugpy not found", vim.log.levels.ERROR)
  end
  
  if project_info.venv_path then
    vim.notify("Virtual environment: " .. project_info.venv_path, vim.log.levels.INFO)
  else
    vim.notify("No virtual environment detected", vim.log.levels.WARN)
  end
  
  -- Test debugpy installation
  vim.fn.jobstart({ project_info.python_path, "-c", "import debugpy; print('debugpy version:', debugpy.__version__)" }, {
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ debugpy is properly installed", vim.log.levels.INFO)
      else
        vim.notify("❌ debugpy is not installed or not working", vim.log.levels.ERROR)
        vim.notify("Install with: " .. project_info.python_path .. " -m pip install debugpy", vim.log.levels.INFO)
      end
    end,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            vim.notify(line, vim.log.levels.INFO)
          end
        end
      end
    end
  })
end

return M