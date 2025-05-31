-- lua/user/keymaps.lua

local M = {}

-- Define your common options
local common_buf_opts = {
  noremap = true,
  silent = true,
  -- buffer = bufnr -- This should be passed dynamically as it's buffer-specific
}

--- Sets a buffer-local keymap with common options and a description.
--- @param mode string|table The mode(s) for the keymap (e.g., "n", {"n", "v"}).
--- @param lhs string The left-hand side (key sequence).
--- @param rhs string|fun The right-hand side (command or function).
--- @param desc string The description for the keymap (used by which-key, etc.).
--- @param bufnr number The buffer number to apply the mapping to.
M.buf_map = function(mode, lhs, rhs, desc, bufnr)
  local opts = vim.tbl_deep_extend("force", common_buf_opts, {
    buffer = bufnr,
    desc = desc,
  })
  vim.keymap.set(mode, lhs, rhs, opts)
end

--- Sets a global keymap with common options and a description.
--- (Does not include 'buffer' option)
--- @param mode string|table The mode(s) for the keymap.
--- @param lhs string The left-hand side (key sequence).
--- @param rhs string|fun The right-hand side (command or function).
--- @param desc string The description for the keymap.
M.global_map = function(mode, lhs, rhs, desc)
  local opts = vim.tbl_deep_extend("force", common_buf_opts, {
    desc = desc,
  })
  -- Remove the buffer option if it was accidentally included in common_buf_opts
  -- This is important for global maps.
  opts.buffer = nil 
  vim.keymap.set(mode, lhs, rhs, opts)
end

return M
