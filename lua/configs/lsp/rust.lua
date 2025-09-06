-- lua/configs/lsp/rust.lua
-- Simplified Rust LSP configuration using platform_config

local M = {}
local platform_config = require('configs.lsp.platform_config')

-- Setup Rust LSP
function M.setup_lsp(capabilities)
  local lspconfig = require("lspconfig")

  -- Use the platform-specific setup
  local success = platform_config.setup_rust_lsp(lspconfig, capabilities)

  if success then
    -- Additional Rust-specific setup if needed
    vim.api.nvim_create_autocmd("BufReadPost", {
      pattern = { "*.rs", "Cargo.toml" },
      callback = function()
        -- Set Rust-specific options
        vim.opt_local.commentstring = '// %s'
        vim.opt_local.shiftwidth = 4
        vim.opt_local.tabstop = 4
        vim.opt_local.expandtab = true
      end,
    })
  end

  return success
end

-- Get Rust project information
function M.get_project_info()
  local cwd = vim.fn.getcwd()
  local cargo_toml = cwd .. '/Cargo.toml'

  if vim.fn.filereadable(cargo_toml) == 0 then
    return nil
  end

  local project_name = nil
  local is_workspace = false
  local workspace_members = {}

  -- Parse Cargo.toml
  for line in io.lines(cargo_toml) do
    if line:match("^name%s*=%s*[\"']([^\"']+)[\"']") then
      project_name = line:match("^name%s*=%s*[\"']([^\"']+)[\"']")
    end

    if line:match("^%[workspace%]") then
      is_workspace = true
    end

    if is_workspace and line:match("members%s*=") then
      local members_str = line:match("members%s*=%s*%[(.-)%]")
      if members_str then
        for member in members_str:gmatch('"([^"]+)"') do
          table.insert(workspace_members, member)
        end
      end
    end
  end

  return {
    name = project_name or vim.fn.fnamemodify(cwd, ":t"),
    directory = cwd,
    cargo_toml = cargo_toml,
    is_workspace = is_workspace,
    workspace_members = workspace_members,
    platform = platform_config.platform
  }
end

-- Build project helper
function M.build_project(callback)
  local project_info = M.get_project_info()
  if not project_info then
    vim.notify(string.format(
      "[%s] Not a Rust project (no Cargo.toml found)",
      platform_config.platform
    ), vim.log.levels.ERROR)
    return
  end

  vim.notify(string.format(
    "[%s] Building Rust project: %s",
    platform_config.platform,
    project_info.name
  ), vim.log.levels.INFO)

  vim.fn.jobstart({ "cargo", "build" }, {
    cwd = project_info.directory,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ Build successful!", vim.log.levels.INFO)
        if callback then callback(true) end
      else
        vim.notify("❌ Build failed with exit code: " .. code, vim.log.levels.ERROR)
        if callback then callback(false) end
      end
    end,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            print("Build: " .. line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            print("Build: " .. line)
          end
        end
      end
    end
  })
end

-- Test project helper
function M.test_project(test_name)
  local project_info = M.get_project_info()
  if not project_info then
    vim.notify(string.format(
      "[%s] Not a Rust project (no Cargo.toml found)",
      platform_config.platform
    ), vim.log.levels.ERROR)
    return
  end

  local cmd = { "cargo", "test" }
  if test_name then
    table.insert(cmd, test_name)
  end

  vim.notify(string.format(
    "[%s] Running Rust tests...",
    platform_config.platform
  ), vim.log.levels.INFO)

  vim.fn.jobstart(cmd, {
    cwd = project_info.directory,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ Tests passed!", vim.log.levels.INFO)
      else
        vim.notify("❌ Tests failed with exit code: " .. code, vim.log.levels.ERROR)
      end
    end
  })
end

-- Check if Rust toolchain is properly installed
function M.check_toolchain()
  vim.notify(string.format("=== Rust Toolchain Check [%s] ===", platform_config.platform), vim.log.levels.INFO)

  local checks = {
    { cmd = "rustc",   name = "Rust compiler" },
    { cmd = "cargo",   name = "Cargo" },
    { cmd = "clippy",  name = "Clippy (cargo clippy)" },
    { cmd = "rustfmt", name = "rustfmt (cargo fmt)" }
  }

  local all_good = true
  for _, check in ipairs(checks) do
    if vim.fn.executable(check.cmd) == 1 then
      vim.notify("✅ " .. check.name .. " found", vim.log.levels.INFO)
    else
      vim.notify("❌ " .. check.name .. " not found", vim.log.levels.WARN)
      all_good = false
    end
  end

  -- Check rust-analyzer specifically
  local rust_analyzer = platform_config.rust.find_rust_analyzer()
  if rust_analyzer then
    vim.notify("✅ rust-analyzer found at: " .. rust_analyzer, vim.log.levels.INFO)
  else
    vim.notify("❌ rust-analyzer not found", vim.log.levels.ERROR)
    all_good = false
  end

  if all_good then
    vim.notify(string.format("🦀 Rust toolchain is ready on %s!", platform_config.platform), vim.log.levels.INFO)
  else
    vim.notify("Install missing tools with: rustup component add clippy rustfmt rust-analyzer", vim.log.levels.WARN)
  end
end

-- Setup Rust-specific keymaps
function M.setup_keymaps(client, bufnr, desc_opts)
  -- For rust-analyzer, we might want to map some specific commands.
  -- For example:
  -- vim.keymap.set("n", "<leader>ra", function()
  --   vim.lsp.buf.execute_command({ command = "rust-analyzer.run", arguments = {} })
  -- end, desc_opts("Run rust-analyzer command"))
end

return M
