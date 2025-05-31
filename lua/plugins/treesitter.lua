return {
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',   -- This command compiles the parsers for the first time
  config = function()
    require('nvim-treesitter.configs').setup {
      -- A list of parser names, or "all" (the five listed parsers should always be installed)
      ensure_installed = { "c", "lua", "vim", "vimdoc", "javascript", "typescript", "html", "css", "python", "rust" },

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
      -- Requires 'nvim-treesitter/nvim-treesitter-textobjects' to be a dependency if you use lazy.nvim.
      -- See point 2 below for this.
      -- textobjects = {
      --   select = {
      --     enable = true,
      --     lookahead = true, -- Automatically jump to the end of a textobject (e.g. after 'if')
      --     keymaps = {
      --       -- You can use these to select different parts of your code
      --       ['af'] = '@function.outer',
      --       ['if'] = '@function.inner',
      --       ['ac'] = '@class.outer',
      --       ['ic'] = '@class.inner',
      --     },
      --   },
      -- },

      ---- Other optional configurations ----
      -- nvim-treesitter-context (optional, shows current function/class in a floating window)
      -- context_commentstring (optional, for smart commenting)
      -- Incremental selection (useful for selecting increasing AST nodes)
    }
  end,
}
