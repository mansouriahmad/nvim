-- lua/plugins/treesitter.lua (Updated to fix markdown highlighting issue)

return {
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',
  dependencies = {
    'nvim-treesitter/nvim-treesitter-textobjects',
    'nvim-treesitter/nvim-treesitter-context',
  },
  config = function()
    require('nvim-treesitter.configs').setup {
      ensure_installed = { 
        "c", "lua", "vim", "vimdoc", "javascript", "typescript", "html", "css", "python", "rust",
        "json", "yaml", "markdown", "markdown_inline", "bash", "sql", "go", "java", "cpp", "c_sharp", "php"
      },

      sync_install = false,
      auto_install = true,

      highlight = {
        enable = true,
        -- FIX 1: Disable Treesitter highlighting for markdown to avoid conflicts
        -- This is the most reliable fix for the markdown issue
        disable = { "markdown" },
        
        -- Alternative approach - keep treesitter but disable additional highlighting
        additional_vim_regex_highlighting = { "markdown" },
      },

      indent = { 
        enable = true,
        -- Also disable indent for markdown to avoid similar issues
        disable = { "markdown" }
      },

      textobjects = {
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            ['af'] = '@function.outer',
            ['if'] = '@function.inner',
            ['ac'] = '@class.outer',
            ['ic'] = '@class.inner',
            ['aa'] = '@parameter.outer',
            ['ia'] = '@parameter.inner',
            ['ab'] = '@block.outer',
            ['ib'] = '@block.inner',
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            [']m'] = '@function.outer',
            [']]'] = '@class.outer',
          },
          goto_next_end = {
            [']M'] = '@function.outer',
            [']['] = '@class.outer',
          },
          goto_previous_start = {
            ['[m'] = '@function.outer',
            ['[['] = '@class.outer',
          },
          goto_previous_end = {
            ['[M'] = '@function.outer',
            ['[]'] = '@class.outer',
          },
        },
      },

      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = '<CR>',
          node_incremental = '<CR>',
          node_decremental = '<BS>',
          scope_incremental = '<TAB>',
        },
      },
    }

    -- Setup treesitter-context with markdown disabled
    require('treesitter-context').setup({
      enable = true,
      max_lines = 0,
      trim_scope = 'outer',
      -- Disable context for markdown to avoid similar issues
      disable = { 'markdown' },
      patterns = {
        default = {
          'class',
          'function',
          'method',
          'for',
          'while',
          'if',
          'switch',
          'case',
        },
      },
    })

    -- FIX 2: Add autocmd to handle markdown files specifically
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = function()
        -- Disable treesitter highlighting for this buffer
        vim.treesitter.stop()
        
        -- Enable built-in markdown syntax highlighting instead
        vim.cmd("syntax on")
        vim.cmd("set syntax=markdown")
        
        -- Optional: Add markdown-specific settings
        vim.opt_local.wrap = true
        vim.opt_local.linebreak = true
        vim.opt_local.conceallevel = 2
      end,
    })
  end,
}

-- Alternative solution: Create a separate markdown configuration
-- If you want to keep trying treesitter for markdown, you can use this instead:

--[[
-- FIX 3: More granular markdown treesitter config
return {
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',
  dependencies = {
    'nvim-treesitter/nvim-treesitter-textobjects',
    'nvim-treesitter/nvim-treesitter-context',
  },
  config = function()
    require('nvim-treesitter.configs').setup {
      ensure_installed = { 
        "c", "lua", "vim", "vimdoc", "javascript", "typescript", "html", "css", "python", "rust",
        "json", "yaml", "markdown", "markdown_inline", "bash", "sql", "go", "java", "cpp", "c_sharp", "php"
      },

      sync_install = false,
      auto_install = true,

      highlight = {
        enable = true,
        -- Try keeping treesitter but with safer settings
        additional_vim_regex_highlighting = false,
        
        -- Custom function to disable highlighting for problematic cases
        disable = function(lang, buf)
          -- Check if this is a large file (>50KB) or has issues
          local max_filesize = 50 * 1024 -- 50 KB
          local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
          if ok and stats and stats.size > max_filesize then
            return true
          end
          
          -- Disable for markdown if we detect the problematic pattern
          if lang == "markdown" then
            local lines = vim.api.nvim_buf_line_count(buf)
            if lines > 1000 then  -- Large markdown files
              return true
            end
          end
          
          return false
        end,
      },

      indent = { enable = true },

      -- Rest of config...
    end
  end,
}
--]]
