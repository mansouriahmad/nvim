return {
  get_python_command = function()
    if vim.fn.executable("python3") == 1 then
      return "python3"
    elseif vim.fn.executable("python") == 1 then
      return "python"
    else
      vim.notify("Neither 'python3' nor 'python' found in PATH", vim.log.levels.ERROR)
      return "python3"
    end
  end,

  get_pip_command = function()
    if vim.fn.executable("pip3") == 1 then
      return "pip3"
    elseif vim.fn.executable("pip") == 1 then
      return "pip"
    else
      return "pip3"
    end
  end,

  setup_pyright = function(lspconfig, capabilities)
    lspconfig.pyright.setup({
      capabilities = capabilities,
      settings = {
        python = {
          analysis = {
            typeCheckingMode = "basic",   -- "off", "basic", "strict"
            autoSearchPaths = true,
            diagnosticMode = "off", -- "openFilesOnly" or "workspace"
            useLibraryCodeForTypes = true,
            autoImportCompletions = true,
          },
        },
      },
      -- Python-specific on_attach
      on_attach = function(client, bufnr)
        -- Disable Pyright's formatting in favor of Ruff
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
      end,
    })
  end,

  setup_ruff = function(lspconfig, capabilities)
    lspconfig.ruff.setup({
      capabilities = capabilities,
      init_options = {
        settings = {
          -- Ruff settings
          args = {
            "--line-length=88", -- Black-compatible line length
            "--select=E,W,F,I", -- Error, Warning, pyFlakes, Import sorting
          },
        },
      },
    })
  end,

  -- Python-specific keymaps to be called in LspAttach
  setup_keymaps = function(client, bufnr, desc_opts)
    if client.name == "pyright" or client.name == "ruff" then
      local python_cmd = require("configs.lsp.python").get_python_command()
      local pip_cmd = require("configs.lsp.python").get_pip_command()

      vim.keymap.set("n", "<leader>po", function()
        vim.cmd("!" .. python_cmd .. " -m py_compile " .. vim.fn.expand("%"))
      end, desc_opts("Python syntax check"))

      vim.keymap.set("n", "<leader>pr", function()
        vim.cmd("!" .. python_cmd .. " " .. vim.fn.expand("%"))
      end, desc_opts("Run Python file"))

      vim.keymap.set("n", "<leader>pt", function()
        vim.cmd("!" .. python_cmd .. " -m pytest")
      end, desc_opts("Run pytest"))

      vim.keymap.set("n", "<leader>pi", function()
        vim.cmd("!" .. pip_cmd .. " install -r requirements.txt")
      end, desc_opts("Install requirements"))

      vim.keymap.set("n", "<leader>pv", function()
        vim.cmd("!" .. python_cmd .. " -m venv .venv")
      end, desc_opts("Create virtual environment"))
    end
  end,
}

