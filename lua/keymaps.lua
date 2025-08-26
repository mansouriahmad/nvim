-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

local opts = { noremap = true, silent = true}
local term_opts = { silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

vim.keymap.set("n", "<Space>", "<Nop>", opts)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

vim.keymap.set('n', '<leader>e', '<cmd>NvimTreeToggle<CR>', { desc = 'Toggle NvimTree' })

-- Quick navigation shortcuts
vim.keymap.set('', 'H', '^')
vim.keymap.set('', 'L', '$')

-- FIXED: Consistent arrow key behavior - choose one approach
-- Option 1: Disable with educational messages (current)
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')
-- FIXED: Removed conflicting left/right mappings

-- Option 2: Allow arrow keys for buffer switching
vim.keymap.set('n', '<left>', ':bp<cr>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<right>', ':bn<cr>', { desc = 'Next buffer' })

-- Window navigation is handled by vim-tmux-navigator plugin
-- If you don't use tmux, uncomment these lines and remove vim-tmux-navigator:
-- vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
-- vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
-- vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
-- vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- FIXED: Consistent line movement in normal mode
vim.keymap.set("n", "<leader>j", ":m .+1<CR>==", { noremap = true, silent = true, desc = "Move line down"})
vim.keymap.set("n", "<leader>k", ":m .-2<CR>==", { noremap = true, silent = true, desc = "Move line up"})

-- FIXED: Consistent line movement in visual mode
vim.keymap.set("x", "<leader>j", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("x", "<leader>k", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Updates how vim uses registers when pasting
vim.keymap.set("v", "p", '"_dP', opts)

-- Less restrictive insert mode arrow keys (allow basic movement)
vim.keymap.set('i', '<up>', '<up>')
vim.keymap.set('i', '<down>', '<down>')
vim.keymap.set('i', '<left>', '<left>')
vim.keymap.set('i', '<right>', '<right>')

-- Make j and k move by visual line, not actual line, when text is soft-wrapped
vim.keymap.set('n', 'j', 'gj')
vim.keymap.set('n', 'k', 'gk')

-- Handy keymap for replacing up to next _ (like in variable names)
vim.keymap.set('n', '<leader>m', 'ct_', { desc = 'Delete until next _'})

-- F1 is pretty close to Esc, so you probably meant Esc
vim.keymap.set('', '<F1>', '<Esc>')
vim.keymap.set('i', '<F1>', '<Esc>')      

-- Save all files
vim.keymap.set('n', '<leader>a', ':wa<CR>', { noremap = true, silent = true, desc = 'Save all files'} )

-- More useful diffs (nvim -d) by ignoring whitespace
vim.opt.diffopt:append('iwhite')

-- Files command (if you have fzf installed)
vim.keymap.set('', '<C-p>', '<cmd>Files<cr>')

-- Show/hide hidden characters
vim.keymap.set('n', '<leader>,', ':set invlist<cr>', {desc= 'Toggle list mode'})

-- Always center search results
vim.keymap.set('n', 'n', 'nzz', { silent = true })
vim.keymap.set('n', 'N', 'Nzz', { silent = true })
vim.keymap.set('n', '*', '*zz', { silent = true })
vim.keymap.set('n', '#', '#zz', { silent = true })
vim.keymap.set('n', 'g*', 'g*zz', { silent = true })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Prevent accidental writes to buffers that shouldn't be edited
vim.api.nvim_create_autocmd('BufRead', { pattern = '*.orig', command = 'set readonly' })
vim.api.nvim_create_autocmd('BufRead', { pattern = '*.pacnew', command = 'set readonly' })