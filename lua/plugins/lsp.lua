-- lua/plugins/lsp.lua

return {
  -- Mason: Portable package manager for Neovim
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup({
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗"
          }
        }
      })
    end,
  },

  -- Bridge between Mason and lspconfig
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "rust_analyzer", -- Rust
          "lua_ls",        -- Lua for Neovim config
          "taplo",         -- TOML files (Cargo.toml)
          "yamlls",        -- YAML
          "jsonls",        -- JSON
          "bashls",        -- Shell scripts
          "pyright",       -- Python LSP
          "ruff",          -- Python linter/formatter
          "omnisharp",     -- C# Language Server
        },
        automatic_installation = true,
      })

      -- Auto-install debuggers based on platform
      vim.defer_fn(function()
        local mason_registry = require("mason-registry")
        local debuggers_to_install = {}

        -- Always install these
        table.insert(debuggers_to_install, "codelldb")  -- Rust and C# (cross-platform)
        table.insert(debuggers_to_install, "debugpy")   -- Python
        table.insert(debuggers_to_install, "netcoredbg") -- C# (preferred for all platforms)

        for _, debugger in ipairs(debuggers_to_install) do
          if not mason_registry.is_installed(debugger) then
            vim.notify("Installing " .. debugger .. " via Mason...", vim.log.levels.INFO)
            vim.cmd("MasonInstall " .. debugger)
          end
        end
      end, 1000)
    end,
  },

  -- LSP Configuration
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp", -- LSP source for nvim-cmp
      -- Useful status updates for LSP
      { "j-hui/fidget.nvim", opts = {} },
    },
    config = function()
      vim.lsp.set_log_level("debug") -- Set LSP logging to debug level

      -- Override default LSP server configurations using handlers
      require("mason-lspconfig").setup_handlers({
        -- Custom handler for omnisharp
        omnisharp = function()
          require("lspconfig").omnisharp.setup({
            capabilities = capabilities,
            cmd = { vim.fn.stdpath("data") .. "/mason/bin/omnisharp", "--languageserver", "--hostPID", tostring(vim.fn.getpid()) },
            settings = {
              dotnet = {
                enable = true,
                enablePackageRestore = false, -- Explicitly disable if causing issues
              },
              FormattingOptions = {
                EnableEditorConfigSupport = true,
              },
              Sdk = {
                IncludePrereleases = true,
              },
            },
          })
        end,

        -- Default handler for other language servers
        -- This will be called for all other servers that don't have a custom handler
        ["_"] = function(server_name)
          require("lspconfig")[server_name].setup({
            capabilities = capabilities,
          })
        end,
      })

      -- Helper functions
      local function get_python_command()
        if vim.fn.executable("python3") == 1 then
          return "python3"
        elseif vim.fn.executable("python") == 1 then
          return "python"
        else
          vim.notify("Neither 'python3' nor 'python' found in PATH", vim.log.levels.ERROR)
          return "python3"
        end
      end

      local function get_pip_command()
        if vim.fn.executable("pip3") == 1 then
          return "pip3"
        elseif vim.fn.executable("pip") == 1 then
          return "pip"
        else
          return "pip3"
        end
      end

      local lspconfig = require("lspconfig")
      local configs = require("configs")

      -- nvim-cmp capabilities
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
      -- Enable snippets support
      capabilities.textDocument.completion.completionItem.snippetSupport = true

      -- Diagnostic configuration
      vim.diagnostic.config({
        virtual_text = {
          prefix = "●",
          source = "if_many",
        },
        float = {
          source = "always",
          border = "rounded",
        },
        signs = true,
        underline = true,
        update_in_insert = true,
        severity_sort = true,
      })

      -- Diagnostic signs
      vim.diagnostic.config({
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.INFO] = " ",
            [vim.diagnostic.severity.HINT] = "󰠠 ",
          },
          texthl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
            [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
            [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
            [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
          },
          numhl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
            [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
            [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
            [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
          },
        },
        virtual_text = true,
        update_in_insert = false,
        severity_sort = true,
      })

      -- Add border to hover and signature help
      vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
        vim.lsp.handlers.hover, { border = "rounded" }
      )
      vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
        vim.lsp.handlers.signature_help, { border = "rounded" }
      )

      -- LSP Attach configuration
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", {}),
        callback = function(ev)
          local bufnr = ev.buf
          local client = vim.lsp.get_client_by_id(ev.data.client_id)

          -- Enable completion triggered by <c-x><c-o>
          vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

          -- Buffer local mappings
          local opts = { buffer = bufnr, noremap = true, silent = true }
          local function desc_opts(desc)
            return vim.tbl_extend("force", opts, { desc = desc })
          end

          -- Navigation
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, desc_opts("Go to declaration"))
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, desc_opts("Go to definition"))
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, desc_opts("Go to implementation"))
          vim.keymap.set("n", "gr", vim.lsp.buf.references, desc_opts("Go to references"))
          vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, desc_opts("Go to type definition"))

          -- Documentation
          vim.keymap.set("n", "K", vim.lsp.buf.hover, desc_opts("Hover documentation"))
          vim.keymap.set("n", "<leader>gs", vim.lsp.buf.signature_help, desc_opts("Signature help"))

          -- Workspace
          vim.keymap.set("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, desc_opts("Add workspace folder"))
          vim.keymap.set("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, desc_opts("Remove workspace folder"))
          vim.keymap.set("n", "<leader>wl", function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
          end, desc_opts("List workspace folders"))

          -- Actions
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, desc_opts("Rename symbol"))
          vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, desc_opts("Code action"))
          vim.keymap.set("n", "<leader>cf", function()
            vim.lsp.buf.format({ async = true })
          end, desc_opts("Format buffer"))

          -- Diagnostics
          vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, desc_opts("Previous diagnostic"))
          vim.keymap.set("n", "]d", vim.diagnostic.goto_next, desc_opts("Next diagnostic"))
          vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, desc_opts("Show diagnostic"))
          vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, desc_opts("Diagnostics to loclist"))

          -- Rust-specific keymaps
          if client.name == "rust_analyzer" then
            vim.keymap.set("n", "<leader>rc", function()
              vim.cmd("!cargo check")
            end, desc_opts("Cargo check"))

            vim.keymap.set("n", "<leader>rt", function()
              vim.cmd("!cargo test")
            end, desc_opts("Cargo test"))

            vim.keymap.set("n", "<leader>rb", function()
              vim.cmd("!cargo build")
            end, desc_opts("Cargo build"))

            vim.keymap.set("n", "<leader>rr", function()
              vim.cmd("!cargo run")
            end, desc_opts("Cargo run"))
          end

          -- Python-specific keymaps
          if client.name == "pyright" or client.name == "ruff" then
            local python_cmd = get_python_command()
            local pip_cmd = get_pip_command()

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

          -- C# specific keymaps
          if client.name == "omnisharp" then
            vim.keymap.set("n", "<leader>cb", function()
              vim.cmd("!dotnet build")
            end, desc_opts("dotnet build"))

            vim.keymap.set("n", "<leader>cr", function()
              vim.cmd("!dotnet run")
            end, desc_opts("dotnet run"))

            vim.keymap.set("n", "<leader>ct", function()
              vim.cmd("!dotnet test")
            end, desc_opts("dotnet test"))

            vim.keymap.set("n", "<leader>cR", function()
              vim.cmd("!dotnet restore")
            end, desc_opts("dotnet restore"))
          end

          -- Telescope integration for LSP
          local telescope_builtin = require("telescope.builtin")
          vim.keymap.set("n", "<leader>lr", telescope_builtin.lsp_references, desc_opts("Find references"))
          vim.keymap.set("n", "<leader>ld", telescope_builtin.lsp_definitions, desc_opts("Find definitions"))
          vim.keymap.set("n", "<leader>lt", telescope_builtin.lsp_type_definitions, desc_opts("Find type definitions"))
          vim.keymap.set("n", "<leader>li", telescope_builtin.lsp_implementations, desc_opts("Find implementations"))
          vim.keymap.set("n", "<leader>ls", telescope_builtin.lsp_document_symbols, desc_opts("Document symbols"))
          vim.keymap.set("n", "<leader>lw", telescope_builtin.lsp_workspace_symbols, desc_opts("Workspace symbols"))

          -- Enable inlay hints if supported
          if client.server_capabilities.inlayHintProvider then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
            vim.keymap.set("n", "<leader>ih", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
            end, desc_opts("Toggle inlay hints"))
          end
        end,
      })

      -- Custom breakpoint signs for better clarity
      vim.fn.sign_define('DapBreakpoint', {
        text = '🔴',
        texthl = 'DapBreakpoint',
        linehl = '',
        numhl = 'DapBreakpoint'
      })

      vim.fn.sign_define('DapBreakpointCondition', {
        text = '🟡',
        texthl = 'DapBreakpointCondition',
        linehl = '',
        numhl = 'DapBreakpointCondition'
      })

      vim.fn.sign_define('DapBreakpointRejected', {
        text = '❌',
        texthl = 'DapBreakpointRejected',
        linehl = '',
        numhl = 'DapBreakpointRejected'
      })

      vim.fn.sign_define('DapStopped', {
        text = '▶️',
        texthl = 'DapStopped',
        linehl = 'DapStoppedLine',
        numhl = 'DapStopped'
      })

      vim.fn.sign_define('DapLogPoint', {
        text = '📝',
        texthl = 'DapLogPoint',
        linehl = '',
        numhl = 'DapLogPoint'
      })

      -- Rust Analyzer configuration
      lspconfig.rust_analyzer.setup({
        capabilities = capabilities,
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
              disabled = false,
              enableExperimental = true,
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
              closureReturnTypeHints = {
                enable = "never",
              },
              lifetimeElisionHints = {
                enable = "never",
                useParameterNames = false,
              },
              maxLength = 25,
              parameterHints = {
                enable = true,
              },
              reborrowHints = {
                enable = "never",
              },
              renderColons = true,
              typeHints = {
                enable = true,
                hideClosureInitialization = false,
                hideNamedConstructor = false,
              },
            },
          },
        },
        on_attach = function(client, bufnr)
          client.server_capabilities.semanticTokensProvider = nil
        end,
      })

      -- Python Language Server (Pyright)
      lspconfig.pyright.setup({
        capabilities = capabilities,
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "basic",
              autoSearchPaths = true,
              diagnosticMode = "workspace",
              useLibraryCodeForTypes = true,
              autoImportCompletions = true,
            },
          },
        },
        on_attach = function(client, bufnr)
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end,
      })

      -- Python Linter/Formatter (Ruff)
      lspconfig.ruff.setup({
        capabilities = capabilities,
        init_options = {
          settings = {
            args = {
              "--line-length=88",
              "--select=E,W,F,I",
            },
          },
        },
      })

      -- Lua LS for Neovim configuration
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
        settings = {
          Lua = {
            runtime = {
              version = "LuaJIT",
            },
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = {
              enable = false,
            },
          },
        },
      })

      -- TOML (for Cargo.toml)
      lspconfig.taplo.setup({
        capabilities = capabilities,
      })

      -- Other language servers with minimal config
      local servers = { "jsonls", "yamlls", "bashls" }
      for _, lsp in ipairs(servers) do
        lspconfig[lsp].setup({
          capabilities = capabilities,
        })
      end
    end,
  },

  -- Autocompletion
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind.nvim",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      local lspkind = require("lspkind")
      local configs = require("configs")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-k>"] = cmp.mapping.select_prev_item(),
          ["<C-j>"] = cmp.mapping.select_next_item(),
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip",  priority = 750 },
          { name = "buffer",   priority = 500 },
          { name = "path",     priority = 250 },
        }),
        formatting = {
          format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "...",
            menu = {
              nvim_lsp = "[LSP]",
              luasnip = "[Snippet]",
              buffer = "[Buffer]",
              path = "[Path]",
            },
          }),
        },
        experimental = {
          ghost_text = true,
        },
      })

      -- Set up completion for / search
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "buffer" },
        },
      })

      -- Set up completion for : commands
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = "path" },
        }, {
          { name = "cmdline" },
        }),
      })
    end,
  },

  -- Better Rust tools
  {
    "simrat39/rust-tools.nvim",
    ft = "rust",
    dependencies = { "neovim/nvim-lspconfig" },
    config = function()
      local rt = require("rust-tools")
      rt.setup({
        server = {
          on_attach = function(_, bufnr)
            vim.keymap.set("n", "<leader>rh", rt.hover_actions.hover_actions,
              { buffer = bufnr, desc = "Rust hover actions" })
            vim.keymap.set("n", "<leader>ra", rt.code_action_group.code_action_group,
              { buffer = bufnr, desc = "Rust code action group" })
          end,
        },
        tools = {
          hover_actions = {
            auto_focus = true,
          },
        },
      })
    end,
  },

  -- Crate management for Cargo.toml
  {
    "saecki/crates.nvim",
    ft = { "toml" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("crates").setup({
        null_ls = {
          enabled = true,
          name = "crates.nvim",
        },
        popup = {
          autofocus = true,
          border = "rounded",
        },
      })
      vim.api.nvim_create_autocmd("BufRead", {
        group = vim.api.nvim_create_augroup("CratesKeymaps", { clear = true }),
        pattern = "Cargo.toml",
        callback = function()
          local crates = require("crates")
          local opts = { noremap = true, silent = true, buffer = true }
          vim.keymap.set("n", "<leader>ct", crates.toggle, opts)
          vim.keymap.set("n", "<leader>cr", crates.reload, opts)
          vim.keymap.set("n", "<leader>cv", crates.show_versions_popup, opts)
          vim.keymap.set("n", "<leader>cf", crates.show_features_popup, opts)
          vim.keymap.set("n", "<leader>cd", crates.show_dependencies_popup, opts)
          vim.keymap.set("n", "<leader>cu", crates.update_crate, opts)
          vim.keymap.set("v", "<leader>cu", crates.update_crates, opts)
          vim.keymap.set("n", "<leader>ca", crates.update_all_crates, opts)
          vim.keymap.set("n", "<leader>cU", crates.upgrade_crate, opts)
          vim.keymap.set("v", "<leader>cU", crates.upgrade_crates, opts)
          vim.keymap.set("n", "<leader>cA", crates.upgrade_all_crates, opts)
        end,
      })
    end,
  },
}
