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
        },
        automatic_installation = true,
      })
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
    },
    config = function()
      local lspconfig = require("lspconfig")
      local configs = require("configs")
      local lsp_rust = require("configs.lsp.rust")
      local lsp_python = require("configs.lsp.python")

      -- nvim-cmp capabilities (FIXED: moved before LSP setups)
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
        underline = true,
        update_in_insert = true, -- CHANGED: This enables diagnostics while typing
        severity_sort = true,
        signs = {
          -- Configuration for the signs displayed in the sign column
          -- See :help vim.diagnostic.config for more details
          text = {
            [vim.diagnostic.severity.ERROR] = "  ", -- Error sign
            [vim.diagnostic.severity.WARN] = "  ",  -- Warning sign
            [vim.diagnostic.severity.HINT] = "󰠠 ",  -- Hint sign
            [vim.diagnostic.severity.INFO] = "  ",  -- Info sign
          },
          -- Customize the highlight groups for diagnostic signs
          -- Example: highlight groups for Dap signs (if you move them here)
          -- text_hl = {
          --   DapBreakpoint = "DapBreakpoint",
          --   DapBreakpointCondition = "DapBreakpointCondition",
          --   DapBreakpointRejected = "DapBreakpointRejected",
          --   DapStopped = "DapStopped",
          --   DapLogPoint = "DapLogPoint",
          -- },
          num_hl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
            [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
            [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
            [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
          },
          line_hl = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticVirtualTextError",
            [vim.diagnostic.severity.WARN] = "DiagnosticVirtualTextWarn",
            [vim.diagnostic.severity.HINT] = "DiagnosticVirtualTextHint",
            [vim.diagnostic.severity.INFO] = "DiagnosticVirtualTextInfo",
          },
        },
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
          lsp_rust.setup_keymaps(client, bufnr, desc_opts)

          -- Python-specific keymaps
          lsp_python.setup_keymaps(client, bufnr, desc_opts)

          -- Telescope integration for LSP
          local telescope_builtin = require("telescope.builtin")
          vim.keymap.set("n", "<leader>lr", telescope_builtin.lsp_references, desc_opts("Find references"))
          vim.keymap.set("n", "<leader>ld", telescope_builtin.lsp_definitions, desc_opts("Find definitions"))
          vim.keymap.set("n", "<leader>lt", telescope_builtin.lsp_type_definitions, desc_opts("Find type definitions"))
          vim.keymap.set("n", "<leader>li", telescope_builtin.lsp_implementations, desc_opts("Find implementations"))
          vim.keymap.set("n", "<leader>ls", telescope_builtin.lsp_document_symbols, desc_opts("Document symbols"))
          vim.keymap.set("n", "<leader>lw", telescope_builtin.lsp_workspace_symbols, desc_opts("Workspace symbols"))

          -- Enable inlay hints if supported (great for Rust!)
          if client.server_capabilities.inlayHintProvider then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
            vim.keymap.set("n", "<leader>ih", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
            end, desc_opts("Toggle inlay hints"))
          end
        end,
      })

      -- Rust Analyzer configuration
      lsp_rust.setup_rust_analyzer(lspconfig, capabilities)

      -- Python Language Server (Pyright)
      lsp_python.setup_pyright(lspconfig, capabilities)

      -- Python Linter/Formatter (Ruff) - super fast Python tooling
      lsp_python.setup_ruff(lspconfig, capabilities)

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
      "onsails/lspkind.nvim", -- VS Code-like pictograms
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
}

