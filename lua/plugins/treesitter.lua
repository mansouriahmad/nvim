return {
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',   -- This command compiles the parsers for the first time
  dependencies = {
    'nvim-treesitter/nvim-treesitter-textobjects',
    'nvim-treesitter/nvim-treesitter-context',
  },
  config = function()
    require('nvim-treesitter.configs').setup {
      -- A list of parser names, or "all" (the five listed parsers should always be installed)
      ensure_installed = { 
        "c", "lua", "vim", "vimdoc", "javascript", "typescript", "html", "css", "python", "rust",
        "json", "yaml", "markdown", "bash", "sql", "go", "java", "cpp", "c_sharp", "php"
      },

      -- Install parsers synchronously (build process for `ensure_installed`)
      -- Setting this to true will make your Neovim startup slower the first time
      -- after adding new parsers, as it will compile them.
      sync_install = false,

      -- Automatically install missing parsers when entering a buffer for a given filetype
      auto_install = true,

      ---- Highlight options ----
      highlight = {
        enable = true,   -- `false` will disable the whole extension
        -- Setting this to true will add an `hl` group to the Treesitter nodes.
        -- You can then use it for more advanced highlighting.
        -- disable = { "c", "rust" },  -- uncomment to disable highlight for a list of filetypes
        additional_vim_regex_highlighting = false,
      },

      ---- Indentation options ----
      indent = { enable = true },

      ---- Text Objects (optional, but highly recommended) ----
      -- This enables text objects like `ac` (around class), `if` (in function)
      -- which are incredibly useful for selections and motions.
      textobjects = {
        select = {
          enable = true,
          lookahead = true, -- Automatically jump to the end of a textobject (e.g. after 'if')
          keymaps = {
            -- You can use these to select different parts of your code
            ['af'] = '@function.outer',
            ['if'] = '@function.inner',
            ['ac'] = '@class.outer',
            ['ic'] = '@class.inner',
            ['aa'] = '@parameter.outer',
            ['ia'] = '@parameter.inner',
            ['ab'] = '@block.outer',
            ['ib'] = '@block.inner',
          },
        },
        move = {
          enable = true,
          set_jumps = true, -- whether to set jumps in the jumplist
          goto_next_start = {
            [']m'] = '@function.outer',
            [']]'] = '@class.outer',
          },
          goto_next_end = {
            [']M'] = '@function.outer',
            [']['] = '@class.outer',
          },
          goto_previous_start = {
            ['[m'] = '@function.outer',
            ['[['] = '@class.outer',
          },
          goto_previous_end = {
            ['[M'] = '@function.outer',
            ['[]'] = '@class.outer',
          },
        },
      },

      ---- Other optional configurations ----
      -- nvim-treesitter-context (optional, shows current function/class in a floating window)
      -- context_commentstring (optional, for smart commenting)
      -- Incremental selection (useful for selecting increasing AST nodes)
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = '<CR>',
          node_incremental = '<CR>',
          node_decremental = '<BS>',
          scope_incremental = '<TAB>',
        },
      },
    }

    -- Setup treesitter-context
    require('treesitter-context').setup({
      enable = true,
      max_lines = 0,
      trim_scope = 'outer',
      patterns = {
        default = {
          'class',
          'function',
          'method',
          'for',
          'while',
          'if',
          'switch',
          'case',
        },
      },
    })
  end,
}
