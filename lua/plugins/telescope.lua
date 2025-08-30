-- NOTE: Plugins can specify dependencies.
-- The dependencies are proper plugin specifications as well - anything
-- you do for a plugin at the top level, you can do for a dependency.
--
-- Use the `dependencies` key to specify the dependencies of a particular plugin
return {
  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons',            enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        defaults = {
          -- This section defines default mappings for ALL Telescope pickers
          mappings = {
            i = { -- Insert mode mappings
              -- Disable default C-n/C-p if you don't want them at all
              -- ["<C-n>"] = false,
              -- ["<C-p>"] = false,

              -- Map C-j and C-k to navigate next/previous item
              -- actions.move_selection_next and actions.move_selection_previous are the core Telescope actions
              ["<C-j>"] = require('telescope.actions').move_selection_next,
              ["<C-k>"] = require('telescope.actions').move_selection_previous,

              -- You can also map regular j/k if you prefer (though C-j/C-k is common for completion/pickers)
              -- This might conflict with other insert mode mappings if you don't have good rules
              -- ["j"] = require('telescope.actions').move_selection_next,
              -- ["k"] = require('telescope.actions').move_selection_previous,
            },
            n = { -- Normal mode mappings
              -- Telescope pickers also work in normal mode
              -- Using C-j/C-k instead of j/k to avoid conflicts with other plugins
              ["<C-j>"] = require('telescope.actions').move_selection_next,
              ["<C-k>"] = require('telescope.actions').move_selection_previous,
            },
          },
        },
        -- pickers = {}
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      --vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      --vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      --vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      -- ============================================
      -- THEME SWITCHER WITH REAL-TIME PREVIEW 
      -- ============================================
      
      -- Main theme switcher with live preview (like NvChad)
      vim.keymap.set('n', '<leader>th', function()
        builtin.colorscheme({
          enable_preview = true,  -- This enables real-time preview as you navigate!
        })
      end, { desc = '[T]heme selector with live preview' })

      -- Quick theme cycling through your favorites
      local favorite_themes = {
        'everforest',
        'gruvbox',
        'tokyonight',
        'tokyonight-night',
        'tokyonight-storm',
        'tokyonight-day',
        'tokyonight-moon',
        'github_dark',
        'github_dark_default',
        'github_dark_dimmed',
        'github_light',
        'github_light_default',
        'rose-pine',
        'catppuccin',
      }
      
      local current_theme_index = 1
      
      -- Cycle to next theme with notification
      vim.keymap.set('n', '<leader>tn', function()
        current_theme_index = current_theme_index % #favorite_themes + 1
        local theme = favorite_themes[current_theme_index]
        vim.cmd.colorscheme(theme)
        vim.notify('Theme: ' .. theme, vim.log.levels.INFO)
      end, { desc = 'Cycle to [N]ext theme' })
      
      -- Show only favorite themes
      vim.keymap.set('n', '<leader>tf', function()
        builtin.colorscheme({
          enable_preview = true,
          -- Filter to show only your installed/favorite themes
          -- This function will be called for each available colorscheme
          filter = function(colorscheme_name)
            for _, theme in ipairs(favorite_themes) do
              if colorscheme_name == theme then
                return true
              end
            end
            return false
          end,
        })
      end, { desc = '[T]heme selector ([F]avorites only)' })

      -- Optional: Save theme selection persistently
      local function save_theme_selection(theme_name)
        local config_dir = vim.fn.stdpath('config')
        local theme_file = config_dir .. '/lua/selected-theme.lua'
        local file = io.open(theme_file, 'w')
        if file then
          file:write(string.format("-- Auto-generated theme selection\nvim.cmd.colorscheme('%s')\n", theme_name))
          file:close()
        end
      end

      -- Auto-save theme when changed
      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = '*',
        callback = function(args)
          -- Uncomment the next line if you want to persist theme selection
          save_theme_selection(args.match)
        end,
      })

      -- ============================================
      -- END THEME SWITCHER
      -- ============================================

      -- Slightly advanced example of overriding default behavior and theme
      vim.keymap.set('n', '<leader>s/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
