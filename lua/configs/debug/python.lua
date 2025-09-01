return {
  -- FIXED: Helper function to get the correct Python path (moved up)
  get_python_path = function()
    -- Try to detect virtual environment first
    local venv_paths = {
      vim.fn.getcwd() .. "/.venv/bin/python3",
      vim.fn.getcwd() .. "/.venv/bin/python",
      vim.fn.getcwd() .. "/venv/bin/python3",
      vim.fn.getcwd() .. "/venv/bin/python",
      vim.fn.getcwd() .. "/env/bin/python3",
      vim.fn.getcwd() .. "/env/bin/python",
      vim.fn.expand("~/.virtualenvs/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t") .. "/bin/python3"),
      vim.fn.expand("~/.virtualenvs/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t") .. "/bin/python"),
    }

    for _, python_path in ipairs(venv_paths) do
      if vim.fn.executable(python_path) == 1 then
        return python_path
      end
    end

    -- Default to system python3, then python
    if vim.fn.executable("python3") == 1 then
      return "python3"
    elseif vim.fn.executable("python") == 1 then
      return "python"
    else
      vim.notify("Neither 'python3' nor 'python' found in PATH", vim.log.levels.WARN)
      return "python3" -- fallback
    end
  end,

  -- Python debugger adapter (debugpy)
  setup_adapter = function(dap)
    dap.adapters.python = {
      type = "executable",
      command = vim.fn.stdpath("data") .. "/mason/bin/debugpy-adapter",
    }
  end,

  -- Python debugging configurations
  setup_configurations = function(dap, get_python_path)
    dap.configurations.python = {
      {
        type = "python",
        request = "launch",
        name = "Launch Python File",
        program = "${file}",
        pythonPath = get_python_path,
        console = "integratedTerminal",
        args = {},
      },
      {
        type = "python",
        request = "launch",
        name = "Launch Python Module",
        module = function()
          return vim.fn.input("Module name: ")
        end,
        pythonPath = get_python_path,
        console = "integratedTerminal",
      },
      {
        type = "python",
        request = "launch",
        name = "Debug Django",
        program = vim.fn.getcwd() .. "/manage.py",
        args = { "runserver", "--noreload" },
        pythonPath = get_python_path,
        console = "integratedTerminal",
      },
      {
        type = "python",
        request = "launch",
        name = "Debug Flask",
        program = "${file}",
        env = {
          FLASK_ENV = "development",
          FLASK_DEBUG = "1",
        },
        pythonPath = get_python_path,
        console = "integratedTerminal",
      },
      {
        type = "python",
        request = "launch",
        name = "Debug pytest",
        module = "pytest",
        args = { "${file}" },
        pythonPath = get_python_path,
        console = "integratedTerminal",
      },
    }
  end,

  check_and_install_debugger = function()
    local debugpy_path = vim.fn.stdpath("data") .. "/mason/bin/debugpy-adapter"
    if vim.fn.executable(debugpy_path) == 0 then
      vim.notify("debugpy not found. Installing via Mason...", vim.log.levels.WARN)
      vim.cmd("MasonInstall debugpy")
    end
  end,
}

