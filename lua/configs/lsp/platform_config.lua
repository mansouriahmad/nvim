-- lua/configs/lsp/platform_config.lua
-- Centralized platform-specific LSP configuration for Rust, Python, and C#

local M = {}

-- ============================================================================
-- PLATFORM DETECTION
-- ============================================================================
M.platform = (function()
  local uname = vim.loop.os_uname()
  if uname.sysname == "Windows_NT" then
    return "windows"
  elseif uname.sysname == "Darwin" then
    return "macos"
  else
    return "linux"
  end
end)()

M.is_windows = M.platform == "windows"
M.is_macos = M.platform == "macos"
M.is_linux = M.platform == "linux"

-- ============================================================================
-- COMMON PATH UTILITIES
-- ============================================================================
M.paths = {
  mason_root = vim.fn.stdpath("data") .. "/mason",
  home = M.is_windows and os.getenv("USERPROFILE") or os.getenv("HOME"),
  separator = M.is_windows and "\\" or "/"
}

M.paths.mason_bin = M.paths.mason_root .. "/bin"
M.paths.mason_packages = M.paths.mason_root .. "/packages"

-- Helper to build paths correctly for the platform
function M.build_path(...)
  local parts = { ... }
  return table.concat(parts, M.paths.separator)
end

-- Helper to check if executable exists
function M.executable_exists(path)
  return vim.fn.executable(path) == 1
end

-- Helper to find executable in multiple locations
function M.find_executable(name, additional_paths)
  additional_paths = additional_paths or {}

  -- First check if it's in PATH
  local in_path = vim.fn.exepath(name)
  if in_path ~= "" then
    return in_path
  end

  -- Check additional paths
  for _, path in ipairs(additional_paths) do
    if M.executable_exists(path) then
      return path
    end
  end

  return nil
end

-- ============================================================================
-- RUST CONFIGURATION BY PLATFORM
-- ============================================================================
M.rust = {}

-- Windows Rust Configuration
M.rust.windows = {
  rust_analyzer_paths = {
    M.build_path(M.paths.mason_bin, "rust-analyzer.exe"),
    M.build_path(M.paths.mason_packages, "rust-analyzer", "rust-analyzer.exe"),
    M.build_path(M.paths.home, ".cargo", "bin", "rust-analyzer.exe"),
    "C:\\Program Files\\Rust\\bin\\rust-analyzer.exe",
  },

  codelldb_paths = {
    M.build_path(M.paths.mason_packages, "codelldb", "extension", "adapter", "codelldb.exe"),
    M.build_path(M.paths.mason_bin, "codelldb.exe"),
    "C:\\Program Files\\codelldb\\codelldb.exe",
  },

  cargo_home = M.build_path(M.paths.home, ".cargo"),
  rustup_home = M.build_path(M.paths.home, ".rustup"),
}

-- macOS Rust Configuration
M.rust.macos = {
  rust_analyzer_paths = {
    M.build_path(M.paths.mason_bin, "rust-analyzer"),
    M.build_path(M.paths.mason_packages, "rust-analyzer", "rust-analyzer"),
    M.build_path(M.paths.home, ".cargo", "bin", "rust-analyzer"),
    "/opt/homebrew/bin/rust-analyzer",
    "/usr/local/bin/rust-analyzer",
  },

  codelldb_paths = {
    M.build_path(M.paths.mason_packages, "codelldb", "extension", "adapter", "codelldb"),
    M.build_path(M.paths.mason_bin, "codelldb"),
    "/opt/homebrew/bin/codelldb",
    "/usr/local/bin/codelldb",
    "/Applications/codelldb.app/Contents/MacOS/codelldb",
  },

  cargo_home = M.build_path(M.paths.home, ".cargo"),
  rustup_home = M.build_path(M.paths.home, ".rustup"),
}

-- Linux Rust Configuration
M.rust.linux = {
  rust_analyzer_paths = {
    M.build_path(M.paths.mason_bin, "rust-analyzer"),
    M.build_path(M.paths.mason_packages, "rust-analyzer", "rust-analyzer"),
    M.build_path(M.paths.home, ".cargo", "bin", "rust-analyzer"),
    "/usr/local/bin/rust-analyzer",
    "/usr/bin/rust-analyzer",
    M.build_path(M.paths.home, ".local", "bin", "rust-analyzer"),
  },

  codelldb_paths = {
    M.build_path(M.paths.mason_packages, "codelldb", "extension", "adapter", "codelldb"),
    M.build_path(M.paths.mason_bin, "codelldb"),
    "/usr/local/bin/codelldb",
    "/usr/bin/codelldb",
    M.build_path(M.paths.home, ".local", "bin", "codelldb"),
  },

  cargo_home = M.build_path(M.paths.home, ".cargo"),
  rustup_home = M.build_path(M.paths.home, ".rustup"),
}

-- Get Rust configuration for current platform
function M.rust.get_config()
  return M.rust[M.platform] or M.rust.linux
end

-- Find rust-analyzer executable
function M.rust.find_rust_analyzer()
  local config = M.rust.get_config()
  local exe_name = M.is_windows and "rust-analyzer.exe" or "rust-analyzer"
  return M.find_executable(exe_name, config.rust_analyzer_paths)
end

-- Find codelldb debugger
function M.rust.find_codelldb()
  local config = M.rust.get_config()
  local exe_name = M.is_windows and "codelldb.exe" or "codelldb"
  return M.find_executable(exe_name, config.codelldb_paths)
end

-- ============================================================================
-- PYTHON CONFIGURATION BY PLATFORM
-- ============================================================================
-- M.python = {}

-- Windows Python Configuration
-- M.python.windows = {
--   python_paths = {
--     M.build_path(vim.fn.getcwd(), ".venv", "Scripts", "python.exe"),
--     M.build_path(vim.fn.getcwd(), "venv", "Scripts", "python.exe"),
--     M.build_path(vim.fn.getcwd(), "env", "Scripts", "python.exe"),
--     M.build_path(M.paths.home, "AppData", "Local", "Programs", "Python", "Python312", "python.exe"),
--     M.build_path(M.paths.home, "AppData", "Local", "Programs", "Python", "Python311", "python.exe"),
--     "C:\\Python312\\python.exe",
--     "C:\\Python311\\python.exe",
--     "C:\\Python310\\python.exe",
--   },

--   pyright_paths = {
--     M.build_path(M.paths.mason_bin, "pyright-langserver.cmd"),
--     M.build_path(M.paths.mason_bin, "pyright-langserver.exe"),
--     M.build_path(M.paths.mason_packages, "pyright", "node_modules", ".bin", "pyright-langserver.cmd"),
--   },

--   ruff_paths = {
--     M.build_path(M.paths.mason_bin, "ruff.exe"),
--     M.build_path(M.paths.mason_bin, "ruff-lsp.exe"),
--     M.build_path(M.paths.mason_packages, "ruff", "ruff.exe"),
--   },

--   debugpy_paths = {
--     M.build_path(M.paths.mason_bin, "debugpy-adapter.exe"),
--     M.build_path(M.paths.mason_packages, "debugpy", "venv", "Scripts", "python.exe"),
--   },
-- }

-- macOS Python Configuration
-- M.python.macos = {
--   python_paths = {
--     M.build_path(vim.fn.getcwd(), ".venv", "bin", "python3"),
--     M.build_path(vim.fn.getcwd(), ".venv", "bin", "python"),
--     M.build_path(vim.fn.getcwd(), "venv", "bin", "python3"),
--     M.build_path(vim.fn.getcwd(), "venv", "bin", "python"),
--     "/opt/homebrew/bin/python3",
--     "/usr/local/bin/python3",
--     "/usr/bin/python3",
--     M.build_path(M.paths.home, ".pyenv", "shims", "python3"),
--   },

--   pyright_paths = {
--     M.build_path(M.paths.mason_bin, "pyright-langserver"),
--     M.build_path(M.paths.mason_packages, "pyright", "node_modules", ".bin", "pyright-langserver"),
--     "/opt/homebrew/bin/pyright-langserver",
--     "/usr/local/bin/pyright-langserver",
--   },

--   ruff_paths = {
--     M.build_path(M.paths.mason_bin, "ruff"),
--     M.build_path(M.paths.mason_bin, "ruff-lsp"),
--     "/opt/homebrew/bin/ruff",
--     "/usr/local/bin/ruff",
--   },

--   debugpy_paths = {
--     M.build_path(M.paths.mason_bin, "debugpy-adapter"),
--     M.build_path(M.paths.mason_packages, "debugpy", "venv", "bin", "python"),
--     "/opt/homebrew/bin/debugpy-adapter",
--   },
-- }

-- Linux Python Configuration
-- M.python.linux = {
--   python_paths = {
--     M.build_path(vim.fn.getcwd(), ".venv", "bin", "python3"),
--     M.build_path(vim.fn.getcwd(), ".venv", "bin", "python"),
--     M.build_path(vim.fn.getcwd(), "venv", "bin", "python3"),
--     M.build_path(vim.fn.getcwd(), "venv", "bin", "python"),
--     "/usr/bin/python3",
--     "/usr/local/bin/python3",
--     M.build_path(M.paths.home, ".local", "bin", "python3"),
--     M.build_path(M.paths.home, ".pyenv", "shims", "python3"),
--   },

--   pyright_paths = {
--     M.build_path(M.paths.mason_bin, "pyright-langserver"),
--     M.build_path(M.paths.mason_packages, "pyright", "node_modules", ".bin", "pyright-langserver"),
--     "/usr/local/bin/pyright-langserver",
--     M.build_path(M.paths.home, ".local", "bin", "pyright-langserver"),
--   },

--   ruff_paths = {
--     M.build_path(M.paths.mason_bin, "ruff"),
--     M.build_path(M.paths.mason_bin, "ruff-lsp"),
--     "/usr/local/bin/ruff",
--     M.build_path(M.paths.home, ".local", "bin", "ruff"),
--   },

--   debugpy_paths = {
--     M.build_path(M.paths.mason_bin, "debugpy-adapter"),
--     M.build_path(M.paths.mason_packages, "debugpy", "venv", "bin", "python"),
--     M.build_path(M.paths.home, ".local", "bin", "debugpy-adapter"),
--   },
-- }

-- Get Python configuration for current platform
-- function M.python.get_config()
--   return M.python[M.platform] or M.python.linux
-- end

-- Find Python executable
-- function M.python.find_python()
--   local config = M.python.get_config()

--   -- Check virtual environments first
--   for _, path in ipairs(config.python_paths) do
--     if M.executable_exists(path) then
--       return path
--     end
--   end

--   -- Fall back to system Python
--   local exe_name = M.is_windows and "python.exe" or "python3"
--   return M.find_executable(exe_name, {}) or M.find_executable("python", {})
-- end

-- Find pyright language server
-- function M.python.find_pyright()
--   local config = M.python.get_config()
--   local exe_name = M.is_windows and "pyright-langserver.cmd" or "pyright-langserver"
--   return M.find_executable(exe_name, config.pyright_paths)
-- end

-- Find ruff linter/formatter
-- function M.python.find_ruff()
--   local config = M.python.get_config()
--   local exe_name = M.is_windows and "ruff.exe" or "ruff"
--   local ruff = M.find_executable(exe_name, config.ruff_paths)
--   if not ruff then
--     exe_name = M.is_windows and "ruff-lsp.exe" or "ruff-lsp"
--     ruff = M.find_executable(exe_name, config.ruff_paths)
--   end
--   return ruff
-- end

-- Find debugpy debugger
-- function M.python.find_debugpy()
--   local config = M.python.get_config()
--   local exe_name = M.is_windows and "debugpy-adapter.exe" or "debugpy-adapter"
--   return M.find_executable(exe_name, config.debugpy_paths)
-- end

-- ============================================================================
-- C# CONFIGURATION BY PLATFORM
-- ============================================================================
-- M.csharp = {}

-- Windows C# Configuration
-- M.csharp.windows = {
--   omnisharp_paths = {
--     M.build_path(M.paths.mason_bin, "omnisharp.exe"),
--     M.build_path(M.paths.mason_packages, "omnisharp", "omnisharp.exe"),
--     "C:\\Program Files\\OmniSharp\\OmniSharp.exe",
--     M.build_path(M.paths.home, ".omnisharp", "OmniSharp.exe"),
--   },

--   csharp_ls_paths = {
--     M.build_path(M.paths.mason_bin, "csharp-ls.exe"),
--     M.build_path(M.paths.mason_packages, "csharp-ls", "csharp-ls.exe"),
--   },

--   netcoredbg_paths = {
--     M.build_path(M.paths.mason_packages, "netcoredbg", "netcoredbg", "netcoredbg.exe"),
--     M.build_path(M.paths.mason_bin, "netcoredbg.exe"),
--     "C:\\Program Files\\netcoredbg\\netcoredbg.exe",
--   },

--   dotnet_root = os.getenv("DOTNET_ROOT") or "C:\\Program Files\\dotnet",
-- }

-- macOS C# Configuration
-- M.csharp.macos = {
--   omnisharp_paths = {
--     M.build_path(M.paths.mason_bin, "omnisharp"),
--     M.build_path(M.paths.mason_packages, "omnisharp", "omnisharp"),
--     "/opt/homebrew/bin/omnisharp",
--     "/usr/local/bin/omnisharp",
--     M.build_path(M.paths.home, ".omnisharp", "omnisharp"),
--   },

--   csharp_ls_paths = {
--     M.build_path(M.paths.mason_bin, "csharp-ls"),
--     M.build_path(M.paths.mason_packages, "csharp-ls", "csharp-ls"),
--     "/opt/homebrew/bin/csharp-ls",
--   },

--   netcoredbg_paths = {
--     M.build_path(M.paths.mason_packages, "netcoredbg", "netcoredbg"),
--     M.build_path(M.paths.mason_bin, "netcoredbg"),
--     "/opt/homebrew/bin/netcoredbg",
--     "/usr/local/bin/netcoredbg",
--   },

--   dotnet_root = os.getenv("DOTNET_ROOT") or "/usr/local/share/dotnet",
-- }

-- Linux C# Configuration
-- M.csharp.linux = {
--   omnisharp_paths = {
--     M.build_path(M.paths.mason_bin, "omnisharp"),
--     M.build_path(M.paths.mason_packages, "omnisharp", "omnisharp"),
--     "/usr/local/bin/omnisharp",
--     "/usr/bin/omnisharp",
--     M.build_path(M.paths.home, ".local", "bin", "omnisharp"),
--     M.build_path(M.paths.home, ".omnisharp", "omnisharp"),
--   },

--   csharp_ls_paths = {
--     M.build_path(M.paths.mason_bin, "csharp-ls"),
--     M.build_path(M.paths.mason_packages, "csharp-ls", "csharp-ls"),
--     "/usr/local/bin/csharp-ls",
--     M.build_path(M.paths.home, ".local", "bin", "csharp-ls"),
--   },

--   netcoredbg_paths = {
--     M.build_path(M.paths.mason_packages, "netcoredbg", "netcoredbg"),
--     M.build_path(M.paths.mason_bin, "netcoredbg"),
--     "/usr/local/bin/netcoredbg",
--     "/usr/bin/netcoredbg",
--     M.build_path(M.paths.home, ".local", "bin", "netcoredbg"),
--   },

--   dotnet_root = os.getenv("DOTNET_ROOT") or "/usr/share/dotnet",
-- }

-- Get C# configuration for current platform
-- function M.csharp.get_config()
--   return M.csharp[M.platform] or M.csharp.linux
-- end

-- Find OmniSharp executable
-- function M.csharp.find_omnisharp()
--   local config = M.csharp.get_config()
--   local exe_name = M.is_windows and "omnisharp.exe" or "omnisharp"
--   return M.find_executable(exe_name, config.omnisharp_paths)
-- end

-- Find csharp-ls executable
-- function M.csharp.find_csharp_ls()
--   local config = M.csharp.get_config()
--   local exe_name = M.is_windows and "csharp-ls.exe" or "csharp-ls"
--   return M.find_executable(exe_name, config.csharp_ls_paths)
-- end

-- Find netcoredbg debugger
-- function M.csharp.find_netcoredbg()
--   local config = M.csharp.get_config()
--   local exe_name = M.is_windows and "netcoredbg.exe" or "netcoredbg"
--   return M.find_executable(exe_name, config.netcoredbg_paths)
-- end

-- ============================================================================
-- LSP SETUP FUNCTIONS
-- ============================================================================

-- Setup Rust LSP
function M.setup_rust_lsp(lspconfig, capabilities)
  local rust_analyzer = M.rust.find_rust_analyzer()

  if not rust_analyzer then
    vim.notify(string.format(
      "[%s] rust-analyzer not found. Install via: rustup component add rust-analyzer or :MasonInstall rust-analyzer",
      M.platform
    ), vim.log.levels.ERROR)
    return false
  end

  vim.notify(string.format(
    "[%s] Found rust-analyzer at: %s",
    M.platform,
    rust_analyzer
  ), vim.log.levels.INFO)

  lspconfig.rust_analyzer.setup({
    capabilities = capabilities,
    cmd = { rust_analyzer },
    settings = {
      ["rust-analyzer"] = {
        cargo = {
          allFeatures = true,
          loadOutDirsFromCheck = true,
          runBuildScripts = true,
        },
        checkOnSave = {
          allFeatures = true,
          command = "clippy",
          extraArgs = { "--no-deps" },
        },
        procMacro = {
          enable = true,
          ignored = {
            ["async-trait"] = { "async_trait" },
            ["napi-derive"] = { "napi" },
            ["async-recursion"] = { "async_recursion" },
          },
        },
        diagnostics = {
          enable = true,
          experimental = {
            enable = true,
          },
        },
        inlayHints = {
          bindingModeHints = {
            enable = false,
          },
          chainingHints = {
            enable = true,
          },
          closingBraceHints = {
            enable = true,
            minLines = 25,
          },
          parameterHints = {
            enable = true,
          },
          typeHints = {
            enable = true,
          },
        },
      },
    },
  })

  return true
end

-- Setup Python LSP
-- function M.setup_python_lsp(lspconfig, capabilities)
--   local pyright = M.python.find_pyright()
--   local python = M.python.find_python()
--   local ruff = M.python.find_ruff()

--   if not python then
--     vim.notify(string.format(
--       "[%s] Python not found. Please install Python 3",
--       M.platform
--     ), vim.log.levels.ERROR)
--     return false
--   end

--   vim.notify(string.format(
--     "[%s] Using Python: %s",
--     M.platform,
--     python
--   ), vim.log.levels.INFO)

--   if pyright then
--     vim.notify(string.format(
--       "[%s] Found pyright at: %s",
--       M.platform,
--       pyright
--     ), vim.log.levels.INFO)

--     lspconfig.pyright.setup({
--       capabilities = capabilities,
--       cmd = { pyright, "--stdio" },
--       settings = {
--         python = {
--           pythonPath = python,
--           analysis = {
--             typeCheckingMode = "basic",
--             autoSearchPaths = true,
--             diagnosticMode = "workspace",
--             useLibraryCodeForTypes = true,
--             autoImportCompletions = true,
--           },
--         },
--       },
--     })
--   else
--     vim.notify(string.format(
--       "[%s] pyright not found. Install via: :MasonInstall pyright",
--       M.platform
--     ), vim.log.levels.WARN)
--   end

--   if ruff then
--     vim.notify(string.format(
--       "[%s] Found ruff at: %s",
--       M.platform,
--       ruff
--     ), vim.log.levels.INFO)

--     lspconfig.ruff.setup({
--       capabilities = capabilities,
--       cmd = { ruff, "server", "--preview" },
--       init_options = {
--         settings = {
--           args = {
--             "--line-length=88",
--             "--select=E,W,F,I,N,UP,YTT,ANN,S,BLE,FBT,B,A,COM,C4,DTZ,T10,EM,EXE,ISC,ICN,G,INP,PIE,T20,PYI,PT,Q,RSE,RET,SLF,SIM,TID,TCH,INT,ARG,PTH,ERA,PD,PGH,PL,TRY,NPY,RUF",
--             "--ignore=E501,W503,E203",
--           },
--         },
--       },
--     })
--   else
--     vim.notify(string.format(
--       "[%s] ruff not found. Install via: :MasonInstall ruff-lsp",
--       M.platform
--     ), vim.log.levels.WARN)
--   end

--   return true
-- end

-- Setup C# LSP
-- function M.setup_csharp_lsp(lspconfig, capabilities)
--   local omnisharp = M.csharp.find_omnisharp()
--   local csharp_ls = M.csharp.find_csharp_ls()

--   if omnisharp then
--     vim.notify(string.format(
--       "[%s] Found OmniSharp at: %s",
--       M.platform,
--       omnisharp
--     ), vim.log.levels.INFO)

--     lspconfig.omnisharp.setup({
--       capabilities = capabilities,
--       cmd = {
--         omnisharp,
--         "--languageserver",
--         "--hostPID", tostring(vim.fn.getpid())
--       },
--       on_init = function(client)
--         client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
--       end,
--       root_dir = lspconfig.util.root_pattern("*.sln", "*.csproj", "omnisharp.json"),
--       init_options = {
--         AutomaticWorkspaceInit = true
--       },
--       settings = {
--         FormattingOptions = {
--           EnableEditorConfigSupport = true,
--           OrganizeImports = true,
--         },
--         MsBuild = {
--           LoadProjectsOnDemand = true,
--         },
--         RoslynExtensionsOptions = {
--           EnableAnalyzersSupport = true,
--           EnableImportCompletion = true,
--           AnalyzeOpenDocumentsOnly = false,
--         },
--         Sdk = {
--           IncludePrereleases = true,
--         },
--       },
--     })
--     return true
--   elseif csharp_ls then
--     vim.notify(string.format(
--       "[%s] OmniSharp not found, using csharp-ls at: %s",
--       M.platform,
--       csharp_ls
--     ), vim.log.levels.WARN)

--     lspconfig.csharp_ls.setup({
--       capabilities = capabilities,
--       cmd = { csharp_ls },
--       root_dir = lspconfig.util.root_pattern("*.sln", "*.csproj", "omnisharp.json"),
--       init_options = {
--         AutomaticWorkspaceInit = true
--       }
--     })
--     return true
--   else
--     vim.notify(string.format(
--       "[%s] No C# language server found. Install via: :MasonInstall omnisharp",
--       M.platform
--     ), vim.log.levels.ERROR)
--     return false
--   end
-- end

-- ============================================================================
-- DEBUGGER SETUP FUNCTIONS
-- ============================================================================

-- Setup Rust debugger
function M.setup_rust_debugger(dap)
  local codelldb = M.rust.find_codelldb()

  if not codelldb then
    vim.notify(string.format(
      "[%s] codelldb not found. Install via: :MasonInstall codelldb",
      M.platform
    ), vim.log.levels.WARN)
    return false
  end

  vim.notify(string.format(
    "[%s] Found codelldb at: %s",
    M.platform,
    codelldb
  ), vim.log.levels.INFO)

  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
      command = codelldb,
      args = { "--port", "${port}" },
    },
  }

  return true
end

-- Setup Python debugger
-- function M.setup_python_debugger(dap)
--   local debugpy = M.python.find_debugpy()

--   if not debugpy then
--     vim.notify(string.format(
--       "[%s] debugpy not found. Install via: :MasonInstall debugpy",
--       M.platform
--     ), vim.log.levels.WARN)
--     return false
--   end

--   vim.notify(string.format(
--     "[%s] Found debugpy at: %s",
--     M.platform,
--     debugpy
--   ), vim.log.levels.INFO)

--   require("dap-python").setup(M.python.find_python())

--   return true
-- end

-- Setup C# debugger
-- function M.setup_csharp_debugger(dap)
--   local netcoredbg = M.csharp.find_netcoredbg()
--   local codelldb = M.rust.find_codelldb() -- Can also use codelldb for C#

--   if netcoredbg then
--     vim.notify(string.format(
--       "[%s] Found netcoredbg at: %s",
--       M.platform,
--       netcoredbg
--     ), vim.log.levels.INFO)

--     dap.adapters.coreclr = {
--       type = "executable",
--       command = netcoredbg,
--       args = { "--interpreter=vscode" },
--     }
--     return true
--   elseif codelldb then
--     vim.notify(string.format(
--       "[%s] netcoredbg not found, using codelldb at: %s",
--       M.platform,
--       codelldb
--     ), vim.log.levels.WARN)

--     dap.adapters.coreclr = {
--       type = "server",
--       port = "${port}",
--       executable = {
--         command = codelldb,
--         args = { "--port", "${port}" },
--       },
--     }
--     return true
--   else
--     vim.notify(string.format(
--       "[%s] No C# debugger found. Install via: :MasonInstall netcoredbg",
--       M.platform
--     ), vim.log.levels.ERROR)
--     return false
--   end
-- end

-- ============================================================================
-- DIAGNOSTIC FUNCTIONS
-- ============================================================================

-- Check all installations
function M.check_installations()
  vim.notify(string.format("=== Platform: %s ===", M.platform), vim.log.levels.INFO)

  -- Check Rust
  vim.notify("--- Rust ---", vim.log.levels.INFO)
  local rust_analyzer = M.rust.find_rust_analyzer()
  local codelldb = M.rust.find_codelldb()
  vim.notify(string.format("rust-analyzer: %s", rust_analyzer or "NOT FOUND"),
    rust_analyzer and vim.log.levels.INFO or vim.log.levels.ERROR)
  vim.notify(string.format("codelldb: %s", codelldb or "NOT FOUND"),
    codelldb and vim.log.levels.INFO or vim.log.levels.ERROR)

  -- Check Python
  -- vim.notify("--- Python ---", vim.log.levels.INFO)
  -- local python = M.python.find_python()
  -- local pyright = M.python.find_pyright()
  -- local ruff = M.python.find_ruff()
  -- local debugpy = M.python.find_debugpy()
  -- vim.notify(string.format("python: %s", python or "NOT FOUND"),
  --   python and vim.log.levels.INFO or vim.log.levels.ERROR)
  -- vim.notify(string.format("pyright: %s", pyright or "NOT FOUND"),
  --   pyright and vim.log.levels.INFO or vim.log.levels.WARN)
  -- vim.notify(string.format("ruff: %s", ruff or "NOT FOUND"),
  --   ruff and vim.log.levels.INFO or vim.log.levels.WARN)
  -- vim.notify(string.format("debugpy: %s", debugpy or "NOT FOUND"),
  --   debugpy and vim.log.levels.INFO or vim.log.levels.WARN)

  -- Check C#
  -- vim.notify("--- C# ---", vim.log.levels.INFO)
  -- local omnisharp = M.csharp.find_omnisharp()
  -- local csharp_ls = M.csharp.find_csharp_ls()
  -- local netcoredbg = M.csharp.find_netcoredbg()
  -- vim.notify(string.format("omnisharp: %s", omnisharp or "NOT FOUND"),
  --   omnisharp and vim.log.levels.INFO or vim.log.levels.WARN)
  -- vim.notify(string.format("csharp-ls: %s", csharp_ls or "NOT FOUND"),
  --   csharp_ls and vim.log.levels.INFO or vim.log.levels.WARN)
  -- vim.notify(string.format("netcoredbg: %s", netcoredbg or "NOT FOUND"),
  --   netcoredbg and vim.log.levels.INFO or vim.log.levels.WARN)
end

-- Install missing tools via Mason
function M.install_missing_tools()
  local tools_to_install = {}

  -- Check what's missing
  if not M.rust.find_rust_analyzer() then
    table.insert(tools_to_install, "rust-analyzer")
  end
  if not M.rust.find_codelldb() then
    table.insert(tools_to_install, "codelldb")
  end
  -- if not M.python.find_pyright() then
  --   table.insert(tools_to_install, "pyright")
  -- end
  -- if not M.python.find_ruff() then
  --   table.insert(tools_to_install, "ruff-lsp")
  -- end
  -- if not M.python.find_debugpy() then
  --   table.insert(tools_to_install, "debugpy")
  -- end
  -- if not M.csharp.find_omnisharp() then
  --   table.insert(tools_to_install, "omnisharp")
  -- end
  -- if not M.csharp.find_netcoredbg() then
  --   table.insert(tools_to_install, "netcoredbg")
  -- end

  if #tools_to_install > 0 then
    vim.notify(string.format(
      "[%s] Installing missing tools: %s",
      M.platform,
      table.concat(tools_to_install, ", ")
    ), vim.log.levels.INFO)

    for _, tool in ipairs(tools_to_install) do
      vim.cmd("MasonInstall " .. tool)
    end
  else
    vim.notify(string.format(
      "[%s] All tools are already installed!",
      M.platform
    ), vim.log.levels.INFO)
  end
end

return M
