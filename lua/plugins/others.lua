return {
  {
    'nvim-pack/nvim-spectre',
    keys = {
      { '<leader>S', function() require('spectre').open() end, desc = 'Open Spectre (Search & Replace)' },
    },
    config = true,
  },

  -- Enhanced notifications
  -- {
  --   'rcarriga/nvim-notify',
  --   config = function()
  --     local notify = require('notify')
  --     notify.setup({
  --       background_colour = '#000000',
  --       stages = 'fade_in_slide_out',
  --       timeout = 3000,
  --     })
  --     vim.notify = notify
  --   end,
  -- },

  -- Better quickfix
  {
    'kevinhwang91/nvim-bqf',
    ft = 'qf',
    config = true,
  },

  -- Markdown preview
  {
    'iamcco/markdown-preview.nvim',
    cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
    ft = { 'markdown' },
    build = function() vim.fn['mkdp#util#install']() end,
    keys = {
      { '<leader>mp', '<cmd>MarkdownPreviewToggle<cr>', desc = 'Markdown Preview' },
    },
  },

  -- Better fold management
  {
    'kevinhwang91/nvim-ufo',
    dependencies = 'kevinhwang91/promise-async',
    config = function()
      require('ufo').setup({
        provider_selector = function()
          return { 'treesitter', 'indent' }
        end,
      })
    end,
  },
}
