return {
  "shellRaining/hlchunk.nvim",
  event = { "UIEnter" },
  config = function()
    require("hlchunk").setup({
      indent = {
        enable = true,
      },
      line_num = {
        enable = false,
      },
      blank = {
        enable = false,
      },
    })
  end,
}
