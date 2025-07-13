return {
  'windwp/nvim-autopairs',
  event = "InsertEnter",
  opts = {}, -- uses default options
  config = function()
    require('nvim-autopairs').setup({
      -- ...
      disable_filetype = { "TelescopePrompt", "vim" },
      enable_afterquote = true,
      enable_bracket_in_quote = true,
      enable_check_bracket_line = true,
      map_cr = true, -- auto-indent on <CR> between braces
    })
  end,
}
