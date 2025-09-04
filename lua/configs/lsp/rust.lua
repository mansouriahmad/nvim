return {
  -- Rust Analyzer configuration
  -- Better Rust tools
  plugins = {
    {
      "simrat39/rust-tools.nvim",
      ft = "rust",
      dependencies = { "neovim/nvim-lspconfig" },
      config = function()
        local rt = require("rust-tools")

        -- Get capabilities for nvim-cmp integration
        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

        rt.setup({
          server = {
            capabilities = capabilities, -- Add this line
            on_attach = function(client, bufnr)
              -- Rust-tools specific keymaps
              vim.keymap.set("n", "<leader>rh", rt.hover_actions.hover_actions,
                { buffer = bufnr, desc = "Rust hover actions" })
              vim.keymap.set("n", "<leader>ra", rt.code_action_group.code_action_group,
                { buffer = bufnr, desc = "Rust code action group" })

              -- Standard Rust keymaps
              local opts = { buffer = bufnr, noremap = true, silent = true }

              vim.keymap.set("n", "<leader>rc", function()
                vim.cmd("!cargo check")
              end, vim.tbl_extend('force', opts, { desc = "Cargo check" }))

              vim.keymap.set("n", "<leader>rb", function()
                vim.cmd("!cargo build")
              end, vim.tbl_extend('force', opts, { desc = "Cargo build" }))

              vim.keymap.set("n", "<leader>rr", function()
                vim.cmd("!cargo run")
              end, vim.tbl_extend('force', opts, { desc = "Cargo run" }))

              vim.keymap.set("n", "<leader>rt", function()
                vim.cmd("!cargo test")
              end, vim.tbl_extend('force', opts, { desc = "Cargo test" }))
            end,
            settings = {
              ["rust-analyzer"] = {
                -- Important: Disable duplicate diagnostics
                diagnostics = {
                  enable = true,
                  experimental = {
                    enable = false, -- Disable experimental features that might cause duplicates
                  },
                },
                completion = {
                  postfix = {
                    enable = true,
                  },
                  autoimport = {
                    enable = true,
                  },
                  -- Prevent duplicate completions
                  callable = {
                    snippets = "fill_arguments",
                  },
                },
                -- Reduce noise
                lens = {
                  enable = true,
                  methodReferences = true,
                  references = true,
                },
                inlayHints = {
                  typeHints = {
                    enable = true,
                    hideClosureInitialization = false,
                    hideNamedConstructor = false,
                  },
                  parameterHints = {
                    enable = true,
                  },
                  chainingHints = {
                    enable = true,
                  },
                },
                checkOnSave = {
                  command = "clippy",
                },
              },
            },
          },
          tools = {
            hover_actions = {
              auto_focus = true,
            },
            inlay_hints = {
              auto = true,
              show_parameter_hints = false, -- Prevent duplicate parameter hints
              parameter_hints_prefix = "<- ",
              other_hints_prefix = "=> ",
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
