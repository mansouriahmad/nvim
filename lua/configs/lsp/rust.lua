return {
  -- Rust Analyzer configuration
  setup_rust_analyzer = function(lspconfig, capabilities)
    lspconfig.rust_analyzer.setup({
      capabilities = capabilities,
      settings = {
        ["rust-analyzer"] = {
          cargo = {
            allFeatures = true,
            loadOutDirsFromCheck = true,
            runBuildScripts = true,
          },
          -- Check on save with clippy
          check = {
            enable = true,
            command = "clippy",
            extraArgs = { "--no-deps" },
            allFeatures = true,
          },
          procMacro = {
            enable = true,
            ignored = {
              ["async-trait"] = { "async_trait" },
              ["napi-derive"] = { "napi" },
              ["async-recursion"] = { "async_recursion" },
            },
          },
          -- Real-time diagnostics configuration
          diagnostics = {
            enable = true,
            experimental = {
              enable = true,
            },
            disabled = {},
            enableExperimental = true,
          },
          -- Inlay hints configuration
          inlayHints = {
            bindingModeHints = {
              enable = false,
            },
            chainingHints = {
              enable = false,
            },
            closingBraceHints = {
              enable = false,
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
              enable = false,
            },
            reborrowHints = {
              enable = "never",
            },
            renderColons = true,
            typeHints = {
              enable = false,
              hideClosureInitialization = false,
              hideNamedConstructor = false,
            },
          },
        },
      },
      -- Additional rust-analyzer specific options
      on_attach = function(client, bufnr)
        -- Request semantic tokens for better highlighting
      end,
    })
  end,

  -- Better Rust tools
  plugins = {
    {
      "simrat39/rust-tools.nvim",
      ft = "rust",
      dependencies = { "neovim/nvim-lspconfig" },
      config = function()
        local rt = require("rust-tools")
        rt.setup({
          server = {
            on_attach = function(_, bufnr)
              -- Rust-specific keybindings
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
        local crates = require("crates")
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
        -- Keymaps for crate management
        vim.api.nvim_create_autocmd("BufRead", {
          group = vim.api.nvim_create_augroup("CratesKeymaps", { clear = true }),
          pattern = "Cargo.toml",
          callback = function()
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
  },

  -- Rust-specific keymaps to be called in LspAttach
  setup_keymaps = function(client, bufnr, desc_opts)
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
  end,
}

