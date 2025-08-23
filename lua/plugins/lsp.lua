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
      -- 'j-hui/fidget.nvim',   -- LSP progress indicator
    },
    config = function()
      local lspconfig = require('lspconfig')
      local mason = require('mason')
      local mason_lspconfig = require('mason-lspconfig')
      local cmp = require('cmp')
      local luasnip = require('luasnip')

      -- Fidget for LSP progress messages
      -- require('fidget').setup({
      --   -- Set `nvim_notify` to false to make fidget less intrusive
      --   integration = {
      --     nvim_notify = false,
      --   },
      --   -- Optional: Further customize fidget's display
      --   align = "bottom", -- or "top", "right", "left"
      --   timer_float_up = 1000, -- how long float goes up
      --   timer_decay = 4000, -- how long till message decays
      --   max_width = 80,
      --   max_height = 10,
      --   progress = {
      --     display = {
      --       done = false,       -- Do not show completed progress messages
      --       progress = false,   -- Do not show in-progress messages
      --     },
      --   },
      -- })

      -- Mason setup for installing LSP servers (with error handling)
      local ok, mason_setup_error = pcall(mason.setup)
      if not ok then
        vim.notify('Failed to setup Mason: ' .. tostring(mason_setup_error), vim.log.levels.ERROR)
      end
      
      local ok2, mason_lsp_setup_error = pcall(mason_lspconfig.setup, {
        ensure_installed = {
          'lua_ls',
          'omnisharp',
          'rust_analyzer',
          'pyright'
        },
        automatic_installation = true,
      })
      if not ok2 then
        vim.notify('Failed to setup Mason LSP config: ' .. tostring(mason_lsp_setup_error), vim.log.levels.ERROR)
      end

      -- Install codelldb for better Rust debugging (with error handling)
      local function install_codelldb()
        local ok, mason_registry = pcall(require, 'mason-registry')
        if ok and mason_registry then
          if not mason_registry.is_installed('codelldb') then
            mason_registry.get('codelldb'):install()
          end
        else
          -- Fallback: use vim.notify to inform user
          vim.notify('Mason registry not available. Please install codelldb manually via :MasonInstall codelldb', vim.log.levels.WARN)
        end
      end
      
      -- Try to install codelldb, but don't fail if it doesn't work
      pcall(install_codelldb)


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
        vim.keymap.set('n', 'gd', function()
          local util = vim.lsp.util
          local definitions = vim.lsp.buf.definition()

          if not definitions or #definitions == 0 then
            vim.notify("No definitions found", vim.log.levels.INFO)
            return
          end

          -- Debugging: Log raw definitions
          vim.notify("Raw definitions count: " .. #definitions, vim.log.levels.INFO)
          -- For detailed inspection, you might need to iterate and log each definition
          for i, def in ipairs(definitions) do
            vim.notify(string.format("Def %d: %s, %d:%d", i, def.uri, def.range.start.line, def.range.start.character), vim.log.levels.INFO)
          end

          local unique_definitions = {}
          local seen = {}

          for _, def in ipairs(definitions) do
            local key = def.uri .. ":" .. def.range.start.line .. ":" .. def.range.start.character
            if not seen[key] then
              table.insert(unique_definitions, def)
              seen[key] = true
            end
          end

          -- Debugging: Log unique definitions count
          vim.notify("Unique definitions count: " .. #unique_definitions, vim.log.levels.INFO)

          if #unique_definitions == 1 then
            -- If only one unique definition, go directly to it
            util.jump_to_location(unique_definitions[1].uri, unique_definitions[1].range.start)
          elseif #unique_definitions > 1 then
            -- If multiple unique definitions, open them in the quickfix list
            util.set_qflist(unique_definitions)
            vim.cmd('copen') -- Open quickfix window
          else
            vim.notify("No unique definitions found", vim.log.levels.INFO)
          end
        end, common_buf_opts)
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
          ['<CR>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.confirm({ select = true })
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_locally_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),

          -- Autocomplete navigation with Ctrl+j and Ctrl+k
          ['<C-j>'] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
          ['<C-k>'] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),

          -- Jump to next/previous snippet node (for LuaSnip)
          ['<Tab>'] = cmp.mapping(function(fallback)
            if luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'buffer' },
          { name = 'path' },
        }),
      })

      lspconfig.rust_analyzer.setup({
        on_attach = function(client, bufnr)
          client.resolved_capabilities.document_diagnostics = false
          on_attach(client, bufnr)
        end,
        settings = {
          ['rust-analyzer'] = {
            checkOnSave = true,
            check = {
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
            diagnostics = {
              disabled = {"unlinked-file"}
            }
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

      -- Python LSP configuration
      lspconfig.pyright.setup({
        on_attach = on_attach,
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "basic",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticMode = "workspace",
              inlayHints = {
                functionReturnTypes = true,
                variableTypes = true,
                parameterTypes = true,
              },
            },
            linting = {
              enabled = true,
            },
          },
        },
      })

      -- C# LSP configuration
      lspconfig.omnisharp.setup({
        on_attach = on_attach,
        -- You can add more settings here if needed
        -- settings = { ... }
      })
    end,
  },
}
