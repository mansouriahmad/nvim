return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- optional, for file icons
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("neo-tree").setup({
      -- Your configuration settings here
      window = {
        width = 30,
      },
      filesystem = {
        filtered_items = {
          visible = true, -- Show hidden files
        },
      },
    })
  end,
  cmd = "Neotree",
  keys = {
    { "<leader>e", function() vim.cmd("Neotree toggle") end, desc = "Toggle Neo-tree" },
  },
}
