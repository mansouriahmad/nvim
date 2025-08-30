require 'options'

require 'keymaps'
require 'lazy-bootstrap'

require 'lazy-plugins'

require 'selected-theme'

-- Windows compatibility: Ensure PowerShell is set as the default shell in plugins/toggleterm.lua
-- Some plugins may require additional setup or dependencies on Windows (see plugin configs)
vim.o.background = "dark"
-- Set colors for regular line numbers and current line number
vim.api.nvim_set_hl(0, "LineNr", { fg = "#888888", bold = true }) -- Regular line numbers (bright white)
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#FFFF00" })        -- Current line number (yellow)
vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#888888" })         -- Lines above current (light gray)
vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#888888" })         -- Lines below current (light gray)



