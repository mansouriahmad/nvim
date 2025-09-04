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

-- Add these to your keymaps.lua or init.lua

-- Better buffer navigation (add to keymaps.lua)
vim.keymap.set('n', '<leader>bd', function()
  -- Smart buffer delete - don't close window if it's the last buffer
  local bufs = vim.fn.getbufinfo({buflisted = 1})
  if #bufs > 1 then
    vim.cmd('bdelete')
  else
    vim.notify("Cannot close the last buffer", vim.log.levels.WARN)
  end
end, { desc = 'Delete buffer (smart)' })

vim.keymap.set('n', '<leader>ba', ':%bdelete|edit #|normal `"<CR>', { desc = 'Close all buffers except current' })

-- Quick buffer switching with fuzzy search
vim.keymap.set('n', '<leader>bb', function()
  require('telescope.builtin').buffers({
    sort_mru = true,
    ignore_current_buffer = true,
  })
end, { desc = 'Switch buffers' })

-- Show buffer info
vim.keymap.set('n', '<leader>bi', function()
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  local filetype = vim.bo[buf].filetype
  local line_count = vim.api.nvim_buf_line_count(buf)
  local modified = vim.bo[buf].modified and "✓" or "✗"
  
  local info = {
    string.format("📄 Buffer: %s", vim.fn.fnamemodify(name, ":t")),
    string.format("📁 Path: %s", name),
    string.format("🏷️ Type: %s", filetype == "" and "plaintext" or filetype),
    string.format("📊 Lines: %d", line_count),
    string.format("✏️ Modified: %s", modified),
    "",
    "Press any key to close"
  }
  
  vim.notify(table.concat(info, "\n"), vim.log.levels.INFO)
end, { desc = 'Show buffer info' })


-- Add these to your keymaps.lua

-- Smart line movements that respect indentation
vim.keymap.set('n', 'H', function()
  local line = vim.api.nvim_get_current_line()
  local first_non_blank = line:find('%S') or 1
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  
  if col == first_non_blank then
    vim.cmd('normal! 0')  -- Go to beginning of line
  else
    vim.cmd('normal! ^')  -- Go to first non-blank character
  end
end, { desc = 'Smart home' })

-- Better paragraph navigation
vim.keymap.set({'n', 'v'}, 'J', '5j', { desc = 'Jump down 5 lines' })

-- Quick word replacement
vim.keymap.set('n', '<leader>rw', function()
  local word = vim.fn.expand('<cword>')
  local replacement = vim.fn.input(string.format('Replace "%s" with: ', word))
  if replacement ~= '' then
    vim.cmd(string.format('%%s/\\<%s\\>/%s/gc', word, replacement))
  end
end, { desc = 'Replace word under cursor' })

-- Select all text
vim.keymap.set('n', '<C-a>', 'ggVG', { desc = 'Select all text' })

-- Duplicate line/selection
vim.keymap.set('n', '<leader>d', 'yyp', { desc = 'Duplicate line' })
vim.keymap.set('v', '<leader>d', 'y`>p', { desc = 'Duplicate selection' })

-- Smart joining (join lines but keep cursor position)
vim.keymap.set('n', 'gJ', function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.cmd('normal! J')
  vim.api.nvim_win_set_cursor(0, cursor)
end, { desc = 'Join lines (keep cursor)' })

-- Add these to your keymaps.lua or a new file operations module

-- Quick file operations
vim.keymap.set('n', '<leader>fn', function()
  local current_dir = vim.fn.expand('%:p:h')
  local filename = vim.fn.input('New file name: ', current_dir .. '/')
  if filename ~= '' then
    vim.cmd('edit ' .. filename)
  end
end, { desc = 'Create new file in current directory' })

-- Copy current file path to clipboard
vim.keymap.set('n', '<leader>fp', function()
  local path = vim.fn.expand('%:p')
  vim.fn.setreg('+', path)
  vim.notify('📋 Copied path: ' .. path, vim.log.levels.INFO)
end, { desc = 'Copy file path to clipboard' })

-- Copy current file name to clipboard
vim.keymap.set('n', '<leader>fP', function()
  local name = vim.fn.expand('%:t')
  vim.fn.setreg('+', name)
  vim.notify('📋 Copied filename: ' .. name, vim.log.levels.INFO)
end, { desc = 'Copy filename to clipboard' })

-- Rename current file
vim.keymap.set('n', '<leader>fr', function()
  local current_name = vim.fn.expand('%:p')
  local new_name = vim.fn.input('Rename to: ', current_name)
  if new_name ~= '' and new_name ~= current_name then
    -- Save current file first
    vim.cmd('write')
    
    -- Rename the file
    local success = os.rename(current_name, new_name)
    if success then
      -- Close current buffer and open new one
      vim.cmd('bdelete')
      vim.cmd('edit ' .. new_name)
      vim.notify('✅ File renamed successfully', vim.log.levels.INFO)
    else
      vim.notify('❌ Failed to rename file', vim.log.levels.ERROR)
    end
  end
end, { desc = 'Rename current file' })

-- Delete current file
vim.keymap.set('n', '<leader>fd', function()
  local current_file = vim.fn.expand('%:p')
  local filename = vim.fn.expand('%:t')
  
  if current_file == '' then
    vim.notify('No file to delete', vim.log.levels.WARN)
    return
  end
  
  local confirm = vim.fn.confirm(
    string.format('Delete file "%s"?', filename),
    '&Yes\n&No', 2
  )
  
  if confirm == 1 then
    vim.cmd('bdelete')
    local success = os.remove(current_file)
    if success then
      vim.notify('🗑️ File deleted: ' .. filename, vim.log.levels.INFO)
    else
      vim.notify('❌ Failed to delete file', vim.log.levels.ERROR)
    end
  end
end, { desc = 'Delete current file' })

-- Formatting
vim.keymap.set('n', '<leader>F', function()
  vim.lsp.buf.format({ async = true })
end, { desc = 'Format document' })

-- Open file explorer at current file location
vim.keymap.set('n', '<leader>fo', function()
  local path = vim.fn.expand('%:p:h')
  local system = vim.loop.os_uname().sysname
  
  if system == "Darwin" then
    vim.fn.system('open ' .. vim.fn.shellescape(path))
  elseif system == "Linux" then
    vim.fn.system('xdg-open ' .. vim.fn.shellescape(path))
  elseif system:match("Windows") then
    vim.fn.system('explorer ' .. vim.fn.shellescape(path))
  else
    vim.notify('Unsupported system for opening file explorer', vim.log.levels.WARN)
  end
end, { desc = 'Open file explorer' })

-- Create directory for current file if it doesn't exist
vim.api.nvim_create_autocmd('BufWritePre', {
  callback = function()
    local dir = vim.fn.expand('<afile>:p:h')
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, 'p')
      vim.notify('📁 Created directory: ' .. dir, vim.log.levels.INFO)
    end
  end,
})
