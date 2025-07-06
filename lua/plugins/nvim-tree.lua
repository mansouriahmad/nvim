return {
  "nvim-tree/nvim-tree.lua",
  version = "*", -- recommended, use latest release installs the latest stable version
  lazy = false, -- or your preference for when it loads
  dependencies = {
    "nvim-tree/nvim-web-devicons", -- optional, for file icons
  },
  config = function()
    require("nvim-tree").setup({
      -- You can customize your nvim-tree setup here
      -- For a full list of options, see :help nvim-tree.setup

      -- Example: Disable file_icons (if you don't want web-devicons)
      -- disable_file_icons = false,

      -- Example: Only open nvim-tree when Neovim starts without arguments
      -- auto_open = true,
      -- auto_close = true,
      -- hijack_netrw = true, -- recommended to hijack netrw completely

      -- Example: Configure filters (e.g., ignore .git and node_modules)
      filters = {
        dotfiles = true, -- Hide dotfiles by default
        custom = { ".git", "node_modules" },
      },

      -- Example: Configure view options
      view = {
        width = 30, -- Set the width of the tree
        -- adaptive_size = false,
        side = "left", -- "left" or "right"
        -- preserve_window_proportions = false,
        -- hide_root_folder = false,
        -- float = {
        --   enable = false,
        --   quit_on_focus_loss = true,
        --   open_fn = nil,
        -- },
        -- mappings = {
        --   custom_only = false,
        --   list = {},
        -- },
        -- number = false,
        -- relativenumber = false,
        -- signcolumn = "yes",
      },

      -- Example: Configure keymaps for nvim-tree
      actions = {
        open_file = {
          quit_on_open = false, -- Keep nvim-tree open when opening a file
        },
      },
    })

    -- Optional: Set up a keymap to toggle nvim-tree
    vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle NvimTree" })
  end,
}
