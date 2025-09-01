-- lua/configs/lsp/csharp.lua

local M = {}

M.setup_csharp_ls = function(lspconfig, capabilities)
  lspconfig.csharp_ls.setup({
    capabilities = capabilities,
    -- Add any specific C# LSP settings here if needed
    settings = {
      ["csharp_ls"] = {
        -- Example settings (adjust as needed)
        -- enable_debug_lenses = false,
        -- enable_editor_config_support = true,
      },
    },
    on_attach = function(client, bufnr)
      -- if client.name == "csharp_ls" then
      --   client.server_capabilities.inlayHintProvider = false
      -- end
      -- Optional: Disable default formatting by csharp_ls if another formatter is preferred
      -- client.server_capabilities.documentFormattingProvider = false
      -- client.server_capabilities.documentRangeFormattingProvider = false

      -- You can add C# specific keymaps here if necessary
      -- local opts = { buffer = bufnr, noremap = true, silent = true }
      -- vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    end,
  })
end

M.setup_keymaps = function(client, bufnr, desc_opts)
  -- Add any C# specific keymaps here
  -- e.g., for `csharpls-extended-lsp.nvim` if you re-add it
  -- if client.name == "csharp_ls" then
  --   vim.keymap.set("n", "<leader>o", function()
  --     vim.cmd.OmniSharpCodeAction()
  --   end, desc_opts("OmniSharp Code Action"))
  -- end
end

return M
