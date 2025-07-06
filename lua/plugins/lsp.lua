return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'hrsh7th/nvim-cmp',
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'saadparwaiz1/cmp_luasnip',
      'L3MON4D3/LuaSnip',    -- Snippet engine
      'j-hui/fidget.nvim',   -- LSP progress indicator
    },
    config = function()
      local lspconfig = require('lspconfig')
      local mason = require('mason')
      local mason_lspconfig = require('mason-lspconfig')
      local cmp = require('cmp')
      local luasnip = require('luasnip')

      -- Fidget for LSP progress messages
      require('fidget').setup({})

      -- Mason setup for installing LSP servers
      mason.setup()
      mason_lspconfig.setup({
        ensure_installed = {
          'lua_ls',
          'omnisharp',
          'rust_analyzer'
        },
      })

      -- Install codelldb for better Rust debugging
      local mason_registry = require('mason-registry')
      if not mason_registry.is_installed('codelldb') then
        mason_registry.get('codelldb'):install()
      end


      local my_mapper = require("utils.keymap")

      -- Global mappings for diagnostics
      vim.keymap.set('n', '<leader>vd', vim.diagnostic.open_float, { desc = 'Show Diagnostic' })
      vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic' })
      vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic' })
      vim.keymap.set('n', '<leader>vq', vim.diagnostic.setloclist, { desc = 'Set diagnostic loclist' })

      vim.keymap.set("n", "<leader>f", function()
        vim.lsp.buf.format({ async = true })
      end, { desc = "Format file (LSP)" })

      -- To format a range (visual selection)
      vim.keymap.set("v", "<leader>f", function()
        vim.lsp.buf.format({ async = true })
      end, { desc = "Format selected code (LSP)" })


      local on_attach = function(client, bufnr)
        vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

        local common_buf_opts = { noremap = true, silent = true, buffer = bufnr }

        my_mapper.buf_map('n', 'gD', vim.lsp.buf.declaration, "Go Declaration", bufnr)
        my_mapper.buf_map('n', 'gd', vim.lsp.buf.definition, "Go Definition", bufnr)
        my_mapper.buf_map('n', 'K', vim.lsp.buf.hover, "Show Docs", bufnr)
        my_mapper.buf_map('n', 'gi', vim.lsp.buf.implementation, "Go Implementation", bufnr)
        my_mapper.buf_map('n', 'gs', vim.lsp.buf.signature_help, "Display Signature", bufnr)
        my_mapper.buf_map('n', '<leader>rn', vim.lsp.buf.rename, "Rename a symbol", bufnr)
        my_mapper.buf_map('n', '<leader>ca', vim.lsp.buf.code_action, "Code Actions", bufnr)

        vim.keymap.set('n', 'gr', vim.lsp.buf.references, common_buf_opts)

        vim.keymap.set('n', '<leader>qf', function()
          vim.lsp.buf.code_action({
            filter = function(action)
              return action.isPreferred
            end,
            apply = true,
          })
        end, vim.tbl_extend('force', common_buf_opts, { desc = 'Quick Fix (preferred action)' }))

        -- Note: Removed problematic j/k keybindings that were causing recursive loops
        -- The cmp configuration below already handles popup navigation properly
      end

      -- Diagnostic configuration
      vim.diagnostic.config({
        virtual_text = {
          spacing = 4,
          source = 'if_many',
        },
        signs = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          focusable = false,
          style = 'minimal',
          border = 'rounded',
          source = 'always',
          header = '',
          prefix = '',
        },
      })

      -- Configure nvim-cmp
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          -- completion = cmp.config.window.bordered(),
          -- documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),

          -- Autocomplete navigation with Ctrl+j and Ctrl+k
          ['<C-j>'] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
          ['<C-k>'] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'buffer' },
          { name = 'path' },
        }),
      })

      lspconfig.rust_analyzer.setup({
        on_attach = on_attach,
        settings = {
          ['rust-analyzer'] = {
            checkOnSave = {
              command = 'clippy',
            },
            inlayHints = {
              parameterNames = true,
              parameterHints = { enable = true },
              typeHints = { enable = true },
              bindingModeHints = { enable = true },
              closureCaptureHints = { enable = true },
              maxLength = 25,
            },
            -- Enhanced debugging support
            cargo = {
              loadOutDirsFromCheck = true,
              runBuildScripts = true,
              buildScripts = {
                enable = true,
              },
            },
            procMacro = {
              enable = true,
            },
            lens = {
              enable = true,
              run = true,
              debug = true,
              implementations = true,
              references = true,
              references_adt = true,
              references_trait = true,
              references_enum_variant = true,
              references_module = true,
              references_macro = true,
              references_primitive = true,
              references_associated_type = true,
              references_associated_const = true,
              references_associated_fn = true,
              references_associated_macro = true,
              references_associated_type_impl = true,
              references_associated_const_impl = true,
              references_associated_fn_impl = true,
              references_associated_macro_impl = true,
            },
            hover = {
              actions = {
                enable = true,
                references = true,
                implementations = true,
                run = true,
                debug = true,
                goto_type_def = true,
              },
            },
          },
        },
      })

      -- Setup other language servers (optional)
      lspconfig.lua_ls.setup({
        on_attach = on_attach,
        settings = {
          Lua = {
            runtime = { version = 'LuaJIT' },
            diagnostics = { globals = { 'vim' } },
            workspace = {
              library = vim.api.nvim_get_runtime_file('', true),
              checkThirdParty = false,
            },
            telemetry = { enable = false },
          },
        },
      })
    end,
  },
  {
    'numToStr/Comment.nvim',
    opts = {},   -- This is where you would put any configuration options
  },
}
