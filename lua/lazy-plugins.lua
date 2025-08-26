local plugins = {
	require('plugins.which-key'),
  require('plugins.colorschemes'),
	require('plugins.telescope'),
	--require('plugins.lightline'),
	require('plugins.git'),
	require('plugins.trouble'), -- This is fancy UI for showing the errors
	require('plugins.treesitter'),
	require('plugins.debug'),
  require('plugins.toggleterm'),
  require('plugins.bufferline'),
  require('plugins.snacks'),
  require('plugins.qol'),
  require('plugins.flash'),
  require('plugins.mini'),
  require('plugins.nvim-tree'),
  require('plugins.lsp'),
  require('plugins.vim-tmux-navigator'),
  require('plugins.lualine'),
  require('plugins.nvim-autopairs'),
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
