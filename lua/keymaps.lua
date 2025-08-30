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

-- Smart Enter key for better brace/bracket behavior with mini.pairs
vim.keymap.set('i', '<CR>', function()
  local line = vim.api.nvim_get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local col = cursor[2]
  local prev_char = col > 0 and line:sub(col, col) or ""
  local next_char = col < #line and line:sub(col + 1, col + 1) or ""
  
  -- Check if we're between matching pairs that should expand
  local expanding_pairs = {
    ['{'] = '}',
    ['['] = ']',
    ['('] = ')',
  }
  
  if expanding_pairs[prev_char] and next_char == expanding_pairs[prev_char] then
    -- This creates: 
    -- {
    --   |cursor here with proper indentation
    -- }
    return '<CR><Esc>O'
  else
    return '<CR>'
  end
end, { expr = true, desc = "Smart Enter for pairs" })

-- Optional: Add Ctrl+Enter for the old behavior if you sometimes want it
vim.keymap.set('i', '<C-CR>', '<CR>', { desc = "Regular Enter (no smart pairing)" })

-- Enhanced C# debugging keymaps (in addition to the ones in debug.lua)
vim.keymap.set('n', '<leader>cs', function()
  vim.cmd('!dotnet restore')
end, { desc = 'C# Restore packages' })

vim.keymap.set('n', '<leader>cc', function()
  vim.cmd('!dotnet clean')
end, { desc = 'C# Clean solution' })

vim.keymap.set('n', '<leader>cn', function()
  local name = vim.fn.input('Project name: ')
  if name ~= '' then
    vim.cmd('!dotnet new console -n ' .. name)
  end
end, { desc = 'C# New console project' })

vim.keymap.set('n', '<leader>cw', function()
  local name = vim.fn.input('Project name: ')
  if name ~= '' then
    vim.cmd('!dotnet new webapi -n ' .. name)
  end
end, { desc = 'C# New web API project' })

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

-- Enhanced C# file detection and setup
vim.api.nvim_create_autocmd({'BufNewFile', 'BufRead'}, {
  pattern = '*.cs',
  callback = function()
    -- Set up C#-specific options
    vim.opt_local.commentstring = '// %s'
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.expandtab = true
    
    -- C# specific keymaps for the buffer
    local opts = { buffer = true, noremap = true, silent = true }
    
    -- Quick class/method navigation
    vim.keymap.set('n', '<leader>cf', function()
      require('telescope.builtin').lsp_document_symbols({
        symbols = { 'class', 'method', 'property', 'field', 'constructor' }
      })
    end, vim.tbl_extend('force', opts, { desc = 'Find C# symbols' }))
    
    -- Quick using statement addition
    vim.keymap.set('n', '<leader>cu', function()
      local using = vim.fn.input('Add using: ')
      if using ~= '' then
        vim.cmd('normal! ggO')
        vim.cmd('normal! iusing ' .. using .. ';')
        vim.cmd('normal! <Esc>')
      end
    end, vim.tbl_extend('force', opts, { desc = 'Add using statement' }))
  end,
})

-- Enhanced project detection for better debugging
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    -- Check if we're in a C# project and notify
    if vim.fn.glob('*.csproj', false, true)[1] or vim.fn.glob('*.sln', false, true)[1] then
      vim.notify('C# project detected. Press F5 to debug!', vim.log.levels.INFO)
    elseif vim.fn.filereadable('Cargo.toml') == 1 then
      vim.notify('Rust project detected. Press F5 to debug!', vim.log.levels.INFO)
    elseif vim.fn.filereadable('requirements.txt') == 1 or vim.fn.filereadable('pyproject.toml') == 1 then
      vim.notify('Python project detected. Press F5 to debug!', vim.log.levels.INFO)
    end
  end,
})
