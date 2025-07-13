local plugins = {
	require('plugins.nvim-tree'),
	require('plugins.which-key'),
	require('plugins.colorschemes'),
	require('plugins.telescope'),
	require('plugins.lightline'),
	require('plugins.git'),
	require('plugins.lsp'),
	require('plugins.trouble'), -- This is fancy UI for showing the errors
	require('plugins.treesitter'),
	require('plugins.debug'),
  require('plugins.noice'),
  require('plugins.toggleterm'),
  require('plugins.bufferline'),
  require('plugins.autopairs')
}

local opts = {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    --icons =  {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  }
}
require("lazy").setup(plugins, opts);
