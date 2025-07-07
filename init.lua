require 'options'

require 'keymaps'
require 'lazy-bootstrap'

require 'lazy-plugins'

vim.cmd.colorscheme("tokyonight-night")

vim.background = "dark"
-- Set colors for regular line numbers and current line number
vim.api.nvim_set_hl(0, "LineNr", { fg = "#888888", bold = true })       -- Regular line numbers (bright white)
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#FFFF00" }) -- Current line number (yellow)
vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#888888" })  -- Lines above current (light gray)
vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#888888" })  -- Lines below current (light gray)


--vim.api.nvim_create_autocmd("BufWritePost", {
--    pattern = "*.md",
--    callback = function()
--        local input = vim.fn.expand('%')
--        local output = vim.fn.expand('%:r') .. '.pdf'
--
--        vim.loop.spawn('pandoc', {
--            args = {
--				input,
--                '-o', output,
--				'-f', 'markdown+lists_without_preceding_blankline',
--                '-V', 'papersize=letterpaper',
--                '-V', 'geometry:margin=1in',
--                '-V', 'fontsize=12pt',
--				'--highlight-style', 'espresso',
--                '--pdf-engine=xelatex',
--			},
--        }, function(code, signal)
--            if code == 0 then
--                vim.schedule(function()
--                    vim.notify('✅ PDF generated: ' .. output, vim.log.levels.INFO)
--                end)
--            else
--                vim.schedule(function()
--                    vim.notify('❌ PDF generation failed', vim.log.levels.ERROR)
--                end)
--            end
--        end)
--    end,
--})

local omnisharp_bin = vim.fn.stdpath("data") .. "/mason/packages/omnisharp/omnisharp"
if vim.fn.executable(omnisharp_bin) == 0 then
  omnisharp_bin = vim.fn.stdpath("data") .. "/mason/bin/omnisharp"
end

lspconfig.omnisharp.setup({
  cmd = { omnisharp_bin, "--languageserver", "--hostPID", tostring(vim.fn.getpid()) },
  on_attach = on_attach,
})
