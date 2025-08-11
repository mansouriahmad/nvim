return {
  "akinsho/toggleterm.nvim",
  version = "*",
  config = function()
    require("toggleterm").setup({
      direction = "horizontal",
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      persist_size = true,
      close_on_exit = true,
      shell = vim.o.shell,
    })

    local Terminal = require("toggleterm.terminal").Terminal

    -- Define a horizontal terminal
    local horiz_term = Terminal:new({ direction = "horizontal", hidden = true })

    -- Toggle with <leader>h
    vim.keymap.set("n", "<leader>h", function()
      horiz_term:toggle()
    end, { noremap = true, silent = true })

    -- Optional: Better movement between terminal and normal buffers
    -- Use <C-\> then <C-n> to go to normal mode
    -- Then use <C-w>h/j/k/l to move between windows

    -- Quick exit from terminal to normal mode
    vim.cmd([[tnoremap <Esc> <C-\><C-n>]])
    vim.cmd([[tnoremap <C-h> <C-\><C-n><C-w>h]])
    vim.cmd([[tnoremap <C-j> <C-\><C-n><C-w>j]])
    vim.cmd([[tnoremap <C-k> <C-\><C-n><C-w>k]])
    vim.cmd([[tnoremap <C-l> <C-\><C-n><C-w>l]])
  end,
}

