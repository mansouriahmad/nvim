return {
  {
    'sainnhe/everforest'
  },
  {
    'projekt0n/github-nvim-theme',
    name = 'github-theme',
    lazy = false,    -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      require('github-theme').setup({
        -- ...
      })
    end,
  },
  -- {
  --   "uloco/bluloco.nvim",
  --   dependencies = { "rktjmp/lush.nvim" },
  --   lazy = false,
  --   priority = 1000,
  --   config = function()
  --     require("bluloco").setup({
  --       style = "auto", -- "auto" | "dark" | "light"
  --       transparent = false,
  --       italics = false,
  --       terminal = vim.fn.has("gui_running") == 1,
  --       guicursor = true,
  --       rainbow_headings = false,
  --     })
  --   end,
  -- },
  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
      }

      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
    end,
  },
  {
    'ellisonleao/gruvbox.nvim',
    config = function()
      -- Default options:
      require("gruvbox").setup({
        terminal_colors = true, -- add neovim terminal colors
        undercurl = true,
        underline = true,
        bold = true,
        italic = {
          strings = true,
          emphasis = true,
          comments = true,
          operators = false,
          folds = true,
        },
        strikethrough = true,
        invert_selection = false,
        invert_signs = false,
        invert_tabline = false,
        inverse = true, -- invert background for search, diffs, statuslines and errors
        contrast = "hard",  -- can be "hard", "soft" or empty string
        palette_overrides = {},
        overrides = {},
        dim_inactive = false,
        transparent_mode = false,
      })
    end
  },
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      require('catppuccin').setup({
        flavour = 'mocha', -- latte, frappe, macchiato, mocha
        background = {
          light = 'latte',
          dark = 'mocha',
        },
        transparent_background = false,
        term_colors = true,
        dim_inactive = {
          enabled = false,
          shade = 0.6,
          percentage = 0.0,
        },
        no_italic = false,
        no_bold = false,
        integrations = {
          cmp = true,
          gitsigns = true,
          nvimtree = true,
          telescope = true,
          which_key = true,
          -- ... and many more
        },
      })
      vim.cmd.colorscheme('catppuccin')
    end,
  },
}
