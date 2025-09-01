return {
   "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",         -- required
    "sindrets/diffview.nvim",        -- optional - Diff integration

    -- Only one of these is needed.
    "nvim-telescope/telescope.nvim", -- optional
    -- "echasnovski/mini.pick",         -- optional
    -- "ibhagwan/fzf-lua",              -- optional
    -- "folke/snacks.nvim",             -- optional
  },
  -- {
  --   'kdheepak/lazygit.nvim',
  --   dependencies = { 'nvim-lua/plenary.nvim' },
  --   keys = {
  --     { "<leader>gg", "<cmd>LazyGit<CR>", desc = "Open LazyGit" }
  --   }
  -- },
}
