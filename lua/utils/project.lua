-- lua/utils/project.lua
local M = {}

-- Project templates
local project_templates = {
  csharp = {
    console = "dotnet new console -n {name}",
    webapi = "dotnet new webapi -n {name}",
    mvc = "dotnet new mvc -n {name}",
    blazor = "dotnet new blazorserver -n {name}",
    classlib = "dotnet new classlib -n {name}",
  },
  rust = {
    binary = "cargo new {name}",
    library = "cargo new --lib {name}",
  },
  python = {
    basic = "mkdir {name} && cd {name} && python -m venv .venv && echo 'print(\"Hello, World!\")' > main.py",
    django = "mkdir {name} && cd {name} && python -m venv .venv && source .venv/bin/activate && pip install django && django-admin startproject {name} .",
    fastapi = "mkdir {name} && cd {name} && python -m venv .venv && source .venv/bin/activate && pip install fastapi uvicorn && echo 'from fastapi import FastAPI\napp = FastAPI()\n\n@app.get(\"/\")\ndef read_root():\n    return {\"Hello\": \"World\"}' > main.py",
  }
}

-- Detect project type based on current directory
function M.detect_project_type()
  local cwd = vim.fn.getcwd()
  local detectors = {
    {
      type = "C#",
      files = { "*.sln", "*.csproj", "global.json" },
      icon = "⚡"
    },
    {
      type = "Rust",
      files = { "Cargo.toml", "Cargo.lock" },
      icon = "🦀"
    },
    {
      type = "Python",
      files = { "requirements.txt", "pyproject.toml", "setup.py", "manage.py", "Pipfile" },
      icon = "🐍"
    },
    {
      type = "JavaScript/TypeScript",
      files = { "package.json", "tsconfig.json", "yarn.lock" },
      icon = "⚡"
    },
    {
      type = "Go",
      files = { "go.mod", "go.sum" },
      icon = "🐹"
    },
    {
      type = "Java",
      files = { "pom.xml", "build.gradle", "gradlew" },
      icon = "☕"
    }
  }
  
  for _, detector in ipairs(detectors) do
    for _, pattern in ipairs(detector.files) do
      if #vim.fn.glob(cwd .. "/" .. pattern, false, true) > 0 then
        return detector
      end
    end
  end
  
  return { type = "Unknown", icon = "📁" }
end

-- Show project information
function M.show_project_info()
  local project = M.detect_project_type()
  local cwd = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(cwd, ":t")
  
  local info = {
    string.format("%s %s Project: %s", project.icon, project.type, project_name),
    string.format("📂 Path: %s", cwd),
    "",
  }
  
  -- Add language-specific information
  if project.type == "C#" then
    local sln_files = vim.fn.glob(cwd .. "/*.sln", false, true)
    local csproj_files = vim.fn.glob(cwd .. "/**/*.csproj", false, true)
    
    if #sln_files > 0 then
      table.insert(info, "📋 Solution: " .. vim.fn.fnamemodify(sln_files[1], ":t"))
    end
    table.insert(info, string.format("📦 Projects: %d", #csproj_files))
    
    -- Check .NET version
    local dotnet_version = vim.fn.system("dotnet --version"):gsub("%s+", "")
    if vim.v.shell_error == 0 then
      table.insert(info, "🔧 .NET Version: " .. dotnet_version)
    end
    
  elseif project.type == "Rust" then
    local cargo_toml = cwd .. "/Cargo.toml"
    if vim.fn.filereadable(cargo_toml) == 1 then
      for line in io.lines(cargo_toml) do
        local name = line:match('^name%s*=%s*"([^"]+)"')
        if name then
          table.insert(info, "📦 Package: " .. name)
          break
        end
      end
      
      for line in io.lines(cargo_toml) do
        local version = line:match('^version%s*=%s*"([^"]+)"')
        if version then
          table.insert(info, "🏷️ Version: " .. version)
          break
        end
      end
    end
    
    -- Check Rust version
    local rust_version = vim.fn.system("rustc --version"):match("rustc ([%d%.]+)")
    if rust_version then
      table.insert(info, "🦀 Rust Version: " .. rust_version)
    end
    
  elseif project.type == "Python" then
    -- Check for virtual environment
    local venv_dirs = { ".venv", "venv", "env", ".env" }
    for _, venv_dir in ipairs(venv_dirs) do
      if vim.fn.isdirectory(cwd .. "/" .. venv_dir) == 1 then
        table.insert(info, "🐍 Virtual Environment: " .. venv_dir)
        break
      end
    end
    
    -- Check Python version
    local python_version = vim.fn.system("python --version 2>&1"):match("Python ([%d%.]+)")
    if python_version then
      table.insert(info, "🐍 Python Version: " .. python_version)
    end
    
    -- Detect framework
    if vim.fn.filereadable(cwd .. "/manage.py") == 1 then
      table.insert(info, "🌐 Framework: Django")
    elseif vim.fn.filereadable(cwd .. "/app.py") == 1 then
      table.insert(info, "⚡ Framework: Flask (detected)")
    end
  end
  
  -- Git information
  local git_branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("%s+", "")
  if vim.v.shell_error == 0 and git_branch ~= "" then
    table.insert(info, "🌿 Git Branch: " .. git_branch)
    
    local git_status = vim.fn.system("git status --porcelain 2>/dev/null")
    if git_status ~= "" then
      local changes = #vim.split(git_status, "\n", { trimempty = true })
      table.insert(info, string.format("📝 Uncommitted Changes: %d", changes))
    end
  end
  
  table.insert(info, "")
  table.insert(info, "Press 'q' or <Esc> to close")
  
  -- Show in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, info)
  vim.bo[buf].filetype = "markdown"
  
  local width = math.max(50, math.min(80, vim.o.columns - 10))
  local height = math.min(#info + 2, vim.o.lines - 10)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    style = "minimal",
    border = "rounded",
    title = " Project Information ",
    title_pos = "center",
  })
  
  -- Close keymaps
  local close_win = function() vim.api.nvim_win_close(win, true) end
  vim.keymap.set("n", "<Esc>", close_win, { buffer = buf })
  vim.keymap.set("n", "q", close_win, { buffer = buf })
end

-- Quick project creation
function M.create_project()
  local language = vim.fn.input("Language (csharp/rust/python): ")
  if language == "" then return end
  
  if not project_templates[language] then
    vim.notify("❌ Unknown language: " .. language, vim.log.levels.ERROR)
    return
  end
  
  local template_options = {}
  for template_name, _ in pairs(project_templates[language]) do
    table.insert(template_options, template_name)
  end
  
  if #template_options == 1 then
    local template = template_options[1]
    M.create_project_from_template(language, template)
  else
    -- Show selection menu
    local choice = vim.fn.inputlist(vim.list_extend({"Select template:"}, template_options))
    if choice > 0 and choice <= #template_options then
      local template = template_options[choice]
      M.create_project_from_template(language, template)
    end
  end
end

function M.create_project_from_template(language, template)
  local project_name = vim.fn.input("Project name: ")
  if project_name == "" then return end
  
  local command = project_templates[language][template]:gsub("{name}", project_name)
  
  vim.notify("🚀 Creating " .. language .. " project: " .. project_name, vim.log.levels.INFO)
  
  vim.fn.jobstart(command, {
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("✅ Project created successfully!", vim.log.levels.INFO)
        
        -- Ask if user wants to open the new project
        local open_project = vim.fn.confirm("Open new project?", "&Yes\n&No", 1)
        if open_project == 1 then
          vim.cmd("cd " .. project_name)
          vim.cmd("edit .")
        end
      else
        vim.notify("❌ Failed to create project", vim.log.levels.ERROR)
      end
    end,
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            print(line)
          end
        end
      end
    end,
  })
end

-- Enhanced project switching with recent projects
function M.switch_project()
  local projects_file = vim.fn.stdpath("data") .. "/recent_projects.txt"
  local recent_projects = {}
  
  -- Load recent projects
  if vim.fn.filereadable(projects_file) == 1 then
    for line in io.lines(projects_file) do
      if vim.fn.isdirectory(line) == 1 then
        table.insert(recent_projects, line)
      end
    end
  end
  
  if #recent_projects == 0 then
    vim.notify("No recent projects found. Use :ProjectCreate to create one!", vim.log.levels.INFO)
    return
  end
  
  -- Use telescope to show recent projects
  local has_telescope, telescope = pcall(require, "telescope.builtin")
  if has_telescope then
    telescope.find_files({
      prompt_title = "Recent Projects",
      find_command = { "find", table.concat(recent_projects, " "), "-type", "f", "-name", "*" },
      cwd = recent_projects[1],
    })
  else
    -- Fallback to input selection
    local project_names = {}
    for _, path in ipairs(recent_projects) do
      table.insert(project_names, vim.fn.fnamemodify(path, ":t") .. " (" .. path .. ")")
    end
    
    local choice = vim.fn.inputlist(vim.list_extend({"Select project:"}, project_names))
    if choice > 0 and choice <= #recent_projects then
      vim.cmd("cd " .. recent_projects[choice])
      vim.cmd("edit .")
    end
  end
end

-- Save current project to recent projects
function M.save_current_project()
  local cwd = vim.fn.getcwd()
  local projects_file = vim.fn.stdpath("data") .. "/recent_projects.txt"
  
  -- Read existing projects
  local existing_projects = {}
  if vim.fn.filereadable(projects_file) == 1 then
    for line in io.lines(projects_file) do
      if line ~= cwd and vim.fn.isdirectory(line) == 1 then
        table.insert(existing_projects, line)
      end
    end
  end
  
  -- Add current project to the top and limit to 10 recent projects
  table.insert(existing_projects, 1, cwd)
  if #existing_projects > 10 then
    table.remove(existing_projects)
  end
  
  -- Write back to file
  local file = io.open(projects_file, "w")
  if file then
    for _, project in ipairs(existing_projects) do
      file:write(project .. "\n")
    end
    file:close()
  end
end

-- Setup project commands and autocommands
function M.setup()
  -- Save project when entering a new directory
  vim.api.nvim_create_autocmd("DirChanged", {
    callback = function()
      M.save_current_project()
    end,
  })
  
  -- Show project info on startup if it's a recognized project
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      local project = M.detect_project_type()
      if project.type ~= "Unknown" then
        vim.defer_fn(function()
          vim.notify(string.format("%s %s project detected! Press <leader>pi for details", project.icon, project.type), vim.log.levels.INFO)
        end, 1000)
      end
    end,
  })
  
  -- Create user commands
  vim.api.nvim_create_user_command("ProjectInfo", M.show_project_info, {})
  vim.api.nvim_create_user_command("ProjectCreate", M.create_project, {})
  vim.api.nvim_create_user_command("ProjectSwitch", M.switch_project, {})
  
  -- Keymaps
  vim.keymap.set("n", "<leader>pi", M.show_project_info, { desc = "Show project info" })
  vim.keymap.set("n", "<leader>pc", M.create_project, { desc = "Create new project" })
  vim.keymap.set("n", "<leader>ps", M.switch_project, { desc = "Switch project" })
end

return M
