-- lua/configs/lsp/rust.lua
local M = {}

-- Helper function to detect platform
local function get_platform()
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    return "windows"
  elseif vim.fn.has("macunix") == 1 then
    return "macos"
  else
    return "linux"
  end
end

-- Find rust-analyzer executable
local function find_rust_analyzer()
  local mason_path = vim.fn.stdpath("data") .. "/mason/bin"
  local paths = {
    mason_path,
    "/usr/local/bin",
    "/opt/homebrew/bin",
    os.getenv("HOME") .. "/.local/bin",
    os.getenv("HOME") .. "/.cargo/bin"
  }
  
  if get_platform() == "windows" then
    table.insert(paths, os.getenv("USERPROFILE") .. "\\.cargo\\bin")
    return vim.fn.exepath("rust-analyzer.exe") ~= "" and "rust-analyzer.exe" or nil
  else
    return vim.fn.exepath("rust-analyzer") ~= "" and "rust-analyzer" or nil
  end
end

-- Get Rust project information
local function get_rust_project_info()
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
    -- Get package name
    if line:match("^name%s*=%s*[\"']([^\"']+)[\"']") then
      project_name = line:match("^name%s*=%s*[\"']([^\"']+)[\"']")
    end
    
    -- Check if this is a workspace
    if line:match("^%[workspace%]") then
      is_workspace = true
    end
    
    -- Get workspace members
    if is_workspace and line:match("members%s*=") then
      -- This is a simplified parser - you might want to use a proper TOML parser
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
    workspace_members = workspace_members
  }
end

-- Setup Rust LSP
function M.setup_lsp(capabilities)
  local lspconfig = require("lspconfig")
  
  -- Check if rust-analyzer is available
  local rust_analyzer_cmd = find_rust_analyzer()
  if not rust_analyzer_cmd then
    vim.notify("rust-analyzer not found. Install via rustup or :MasonInstall rust-analyzer", vim.log.levels.ERROR)
    return
  end
  
  lspconfig.rust_analyzer.setup({
    capabilities = capabilities,
    cmd = { rust_analyzer_cmd },
    root_dir = lspconfig.util.root_pattern("Cargo.toml", "rust-project.json"),
    settings = {
      ["rust-analyzer"] = {
        imports = {
          granularity = {
            group = "module",
          },
          prefix = "self",
        },
        cargo = {
          buildScripts = {
            enable = true,
          },
          allFeatures = true,
          loadOutDirsFromCheck = true,
          runBuildScripts = true,
        },
        procMacro = {
          enable = true,
          ignored = {
            ["async-trait"] = { "async_trait" },
            ["napi-derive"] = { "napi" },
            ["async-recursion"] = { "async_recursion" },
          },
        },
        diagnostics = {
          enable = true,
          experimental = {
            enable = true,
          },
          disabled = {},
          remapPrefix = {},
          warningsAsInfo = {},
          warningsAsHint = {},
        },
        workspace = {
          symbol = {
            search = {
              scope = "workspace_and_dependencies",
              kind = "only_types",
            },
          },
        },
        completion = {
          callable = {
            snippets = "fill_arguments",
          },
          postfix = {
            enable = true,
          },
          autoimport = {
            enable = true,
          },
        },
        lens = {
          enable = true,
          methodReferences = true,
          references = true,
          run = true,
          debug = true,
          implementations = true,
        },
        hover = {
          actions = {
            enable = true,
            debug = true,
            gotoTypeDef = true,
            implementations = true,
            references = true,
            run = true,
          },
          documentation = true,
          links = true,
        },
        inlayHints = {
          bindingModeHints = {
            enable = false,
          },
          chainingHints = {
            enable = true,
          },
          closingBraceHints = {
            enable = true,
            minLines = 25,
          },
          closureReturnTypeHints = {
            enable = "never",
          },
          lifetimeElisionHints = {
            enable = "never",
            useParameterNames = false,
          },
          maxLength = 25,
          parameterHints = {
            enable = true,
          },
          reborrowHints = {
            enable = "never",
          },
          renderColons = true,
          typeHints = {
            enable = true,
            hideClosureInitialization = false,
            hideNamedConstructor = false,
          },
        },
        checkOnSave = {
          allFeatures = true,
          command = "clippy",
          extraArgs = { "--no-deps" },
        },
        rustfmt = {
          extraArgs = {},
          overrideCommand = nil,
        },
        runnables = {
          use_telescope = true,
        },
      },
    },
    on_attach = function(client, bufnr)
      -- Disable semantic tokens to avoid conflicts with treesitter
      client.server_capabilities.semanticTokensProvider = nil
      
      -- Rust-specific keymaps
      local opts = { buffer = bufnr, noremap = true, silent = true }
      
      vim.keymap.set("n", "<leader>rc", function()
        vim.cmd("!cargo check")
      end, vim.tbl_extend('force', opts, { desc = "Cargo check" }))
      
      vim.keymap.set("n", "<leader>rb", function()
        vim.cmd("!cargo build")
      end, vim.tbl_extend('force', opts, { desc = "Cargo build" }))
      
      vim.keymap.set("n", "<leader>rr", function()
        vim.cmd("!cargo run")
      end, vim.tbl_extend('force', opts, { desc = "Cargo run" }))
      
      vim.keymap.set("n", "<leader>rt", function()
        vim.cmd("!cargo test")
      end, vim.tbl_extend('force', opts, { desc = "Cargo test" }))
      
      vim.keymap.set("n", "<leader>rd", function()
        vim.cmd("!cargo doc --open")
      end, vim.tbl_extend('force', opts, { desc = "Cargo doc" }))
      
      vim.keymap.set("n", "<leader>rC", function()
        vim.cmd("!cargo clean")
      end, vim.tbl_extend('force', opts, { desc = "Cargo clean" }))
      
      vim.keymap.set("n", "<leader>ru", function()
        vim.cmd("!cargo update")
      end, vim.tbl_extend('force', opts, { desc = "Cargo update" }))
      
      vim.keymap.set("n", "<leader>rf", function()
        vim.cmd("!cargo fmt")
      end, vim.tbl_extend('force', opts, { desc = "Cargo format" }))
      
      vim.keymap.set("n", "<leader>rl", function()
        vim.cmd("!cargo clippy")
      end, vim.tbl_extend('force', opts, { desc = "Cargo clippy" }))
    end,
  })
end

-- Get project information helper
function M.get_project_info()
  return get_rust_project_info()
end

-- Build project helper
function M.build_project(callback)
  local project_info = get_rust_project_info()
  if not project_info then
    vim.notify("Not a Rust project (no Cargo.toml found)", vim.log.levels.ERROR)
    return
  end
  
  vim.notify("Building Rust project: " .. project_info.name, vim.log.levels.INFO)
  
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
  local project_info = get_rust_project_info()
  if not project_info then
    vim.notify("Not a Rust project (no Cargo.toml found)", vim.log.levels.ERROR)
    return
  end
  
  local cmd = { "cargo", "test" }
  if test_name then
    table.insert(cmd, test_name)
  end
  
  vim.notify("Running Rust tests...", vim.log.levels.INFO)
  
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
  local checks = {
    { cmd = "rustc", name = "Rust compiler" },
    { cmd = "cargo", name = "Cargo" },
    { cmd = "rust-analyzer", name = "rust-analyzer" },
    { cmd = "clippy", name = "Clippy (cargo clippy)" },
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
  
  if all_good then
    vim.notify("🦀 Rust toolchain is ready!", vim.log.levels.INFO)
  else
    vim.notify("Install missing tools with: rustup component add clippy rustfmt", vim.log.levels.WARN)
  end
end

return M
            