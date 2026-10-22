-- The explorer pane, a file tree in the style of VS Code.
--
-- The tree is rendered into the window that the workbench gives it, so it
-- behaves like any other window: it scrolls, it resizes and it keeps its
-- buffers. The entries are indented with guide lines, every file carries the
-- icon of its type and the status of the repository is shown next to the name.
--
--   ▾ 󰉋  src
--   │  ▾ 󰉋  components
--   │  │  󰢱  Button.tsx  M
--   │  │  󰢱  Input.tsx
--   │  󰢱  index.ts
--   │  󰢱  main.ts
--   ▸ 󰉋  tests
--   󰢱  package.json  U
--
-- The keys are the ones of VS Code, adapted to the keyboard:
--
--   Enter   open the file, or collapse and expand a directory
--   Space   the same
--   Tab     collapse and expand a directory
--   h       collapse the directory, or go to the parent
--   l       expand the directory, or open the file
--   a       create a file
--   A       create a directory
--   r       rename the entry
--   d       delete the entry
--   .       show and hide the files that start with a dot
--   R       refresh the tree
--   q       close the workbench

local providers = require("neoworkbench.providers")

local M = {}

M.name = "explorer"
M.title = "Explorer"
M.icon = "󰉋"

--- The state of the tree.
M.state = {
  dir = nil,
  collapsed = {},
  hidden = false,
  -- The paths of the entries, in the order they appear on the screen. The
  -- first one is the parent, when the line is the parent directory.
  paths = {},
  -- The git status of the project, a map from the path of an entry to its
  -- status letter.
  git = {},
  -- The time the git status was fetched.
  git_time = 0,
  -- The entries that are selected.
  selected = {},
}

--- The icons of the known file types.
M.icons = {
  lua = "󰟔",
  js = "󰎞",
  jsx = "󰎞",
  ts = "󰨯",
  tsx = "󰨯",
  py = "󰎆",
  rb = "󰎔",
  go = "󰎧",
  rs = "󰎘",
  c = "󰙠",
  h = "󰙠",
  cpp = "󰙠",
  hpp = "󰙠",
  cs = "󰌛",
  java = "󰌛",
  php = "󰌛",
  dart = "󰘙",
  json = "󰘧",
  yaml = "󰘧",
  yml = "󰘧",
  toml = "󰘧",
  xml = "󰘧",
  md = "󰂺",
  txt = "󰈙",
  log = "󰈙",
  html = "󰇥",
  css = "󰇦",
  scss = "󰇦",
  sh = "󰒉",
  ps1 = "󰒉",
  lock = "󰷜",
  gitignore = "󰊢",
  gitmodules = "󰊢",
  env = "󰒓",
}

--- The glyphs of the tree.
M.glyphs = {
  folder_open = "▾",
  folder_closed = "▸",
  folder = "󰉋",
  file = "󰈙",
  guide = "│",
  branch = "├",
  last = "└",
  space = " ",
}

--- The git status letters.
M.git_status = {
  M = "M",
  A = "A",
  D = "D",
  R = "R",
  C = "C",
  U = "U",
  ["?"] = "U",
  ["!"] = "I",
}

--- The git status colours.
M.git_colors = {
  M = "GitSignsChange",
  A = "GitSignsAdd",
  D = "GitSignsDelete",
  R = "GitSignsChange",
  C = "GitSignsChange",
  U = "GitSignsUntracked",
  ["?"] = "GitSignsUntracked",
  ["!"] = "GitSignsIgnored",
}

--- The icon of a file.
---@param path string
---@return string icon, string highlight
local function file_icon(path)
  local name = path:match("([^/\\]+)$") or path
  local extension = name:match("%.([%w_]+)$")

  -- A nerd font is optional, the icons degrade to a single glyph.
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if ok and devicons then
    local icon, hl = devicons.get_icon(name, extension, { default = false })
    if icon and icon ~= "" then
      return icon, hl or "Normal"
    end
  end

  if extension and M.icons[extension:lower()] then
    return M.icons[extension:lower()], "Normal"
  end

  if name:sub(1, 1) == "." then
    return "󰈙", "Normal"
  end

  return M.glyphs.file, "Normal"
end

--- The icon of a directory.
---@param path string
---@param collapsed boolean
---@return string icon, string highlight
local function dir_icon(path, collapsed)
  local name = path:match("([^/\\]+)$") or path
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if ok and devicons and devicons.get_icon then
    -- Directories have their own icon in some themes.
  end
  return M.glyphs.folder, "Directory"
end

--- The root of the project the given directory belongs to.
---@param dir string
---@return string
function M.root_of(dir)
  local current = vim.fn.fnamemodify(dir, ":p")
  while current and current ~= "" do
    if vim.fn.isdirectory(current .. "/.git") == 1 or vim.fn.filereadable(current .. "/.git") == 1 then
      return current
    end
    local parent = vim.fn.fnamemodify(current, ":h")
    if parent == current then
      break
    end
    current = parent
  end
  return vim.fn.fnamemodify(dir, ":p")
end

--- The entries of a directory, directories first.
---@param dir string
---@return string[] dirs, string[] files
local function entries(dir)
  local ok, list = pcall(vim.fn.readdir, dir)
  if not ok then
    return {}, {}
  end

  local dirs, files = {}, {}
  for _, name in ipairs(list) do
    if name ~= "." and name ~= ".." then
      local path = dir .. "/" .. name
      if vim.fn.isdirectory(path) == 1 then
        dirs[#dirs + 1] = name
      else
        files[#files + 1] = name
      end
    end
  end

  table.sort(dirs, function(a, b)
    return a:lower() < b:lower()
  end)
  table.sort(files, function(a, b)
    return a:lower() < b:lower()
  end)
  return dirs, files
end

--- Fetch the git status of the project.
--- The status is a map from the path of an entry to its letter.
---@param root string
---@return table
local function git_status(root)
  local status = {}
  local handle = io.popen("git -C " .. vim.fn.shellescape(root) .. " status --porcelain=v1 -uall 2>/dev/null")
  if not handle then
    return status
  end
  for line in handle:lines() do
    local code = line:sub(1, 2)
    local path = line:sub(4)
    -- A rename shows the old and the new path.
    if code:match("R") then
      path = path:match(" -> (.+)$") or path
    end
    -- The path is relative to the root.
    status[root .. "/" .. path] = code:match("^%s*(%S)") or code:sub(1, 1)
  end
  handle:close()
  return status
end

--- The git status of an entry.
---@param path string
---@return string? letter
local function git_letter(path)
  local letter = M.state.git[path]
  if letter then
    return M.git_status[letter] or letter
  end
  -- A directory may carry the status of one of its files.
  for tracked, letter in pairs(M.state.git) do
    if tracked:sub(1, #path + 1) == path .. "/" then
      return M.git_status[letter] or letter
    end
  end
  return nil
end

--- The git colour of an entry.
---@param path string
---@return string? highlight
local function git_color(path)
  local letter = git_letter(path)
  if letter and M.git_colors[letter] then
    return M.git_colors[letter]
  end
  return nil
end

--- Render the tree into the buffer.
---@param ctx table
---@param bufnr integer
function M.render(ctx, bufnr)
  local dir = M.state.dir or M.root_of(vim.fn.getcwd())
  M.state.dir = dir

  -- Refresh the git status when it is older than a second.
  local now = os.time()
  if now - M.state.git_time > 1 then
    M.state.git = git_status(M.root_of(dir))
    M.state.git_time = now
  end

  local lines = {}
  M.state.paths = {}

  local root = M.root_of(dir)
  local indent = ""

  -- The parent directory, when the tree does not start at the root.
  if root ~= dir then
    lines[#lines + 1] = string.format("  %s  ..", M.glyphs.folder)
    M.state.paths[#M.state.paths + 1] = vim.fn.fnamemodify(dir, ":h")
  end

  local function walk(current, depth, prefix, is_last)
    local dirs, files = entries(current)
    local all = {}
    for _, name in ipairs(dirs) do
      all[#all + 1] = { name = name, kind = "dir" }
    end
    for _, name in ipairs(files) do
      all[#all + 1] = { name = name, kind = "file" }
    end

    for i, entry in ipairs(all) do
      local last = i == #all
      local path = current .. "/" .. entry.name
      local collapsed = entry.kind == "dir" and M.state.collapsed[path] == true

      -- The guide of this level.
      local guide = last and M.glyphs.last or M.glyphs.branch
      local indent_str = string.rep("  ", depth)

      local icon, hl
      if entry.kind == "dir" then
        local glyph = collapsed and M.glyphs.folder_closed or M.glyphs.folder_open
        icon, hl = dir_icon(path, collapsed), "Directory"
        icon = glyph .. "  " .. icon
      else
        icon, hl = file_icon(path)
      end

      -- The status of the repository.
      local status = ""
      local status_hl = nil
      if entry.kind == "file" then
        local letter = git_letter(path)
        if letter then
          status = "  " .. letter
          status_hl = git_color(path)
        end
      else
        local letter = git_letter(path)
        if letter then
          status = "  " .. letter
          status_hl = git_color(path)
        end
      end

      -- A selected entry is marked.
      local marker = M.state.selected[path] and "● " or ""

      local line =
        string.format("%s%s%s %s %s%s", indent_str, guide, M.glyphs.space, icon, marker .. entry.name, status)

      lines[#lines + 1] = line
      M.state.paths[#M.state.paths + 1] = path

      -- The guides of the children.
      if entry.kind == "dir" and not collapsed then
        local child_prefix = indent_str .. (last and "   " or M.glyphs.guide .. "  ")
        walk(path, depth + 1, child_prefix, false)
      end
    end
  end

  walk(dir, 0, "", false)

  if #lines == 0 then
    lines[1] = "  The directory is empty"
    M.state.paths[1] = dir
  end

  providers.set_lines(bufnr, lines)
end

--- Open a path in the editor pane.
---@param path string
function M.open(path)
  local pane = require("neoworkbench.pane")
  local editor = pane.win("editor")
  if editor and vim.api.nvim_win_is_valid(editor) then
    vim.api.nvim_win_set_buf(editor, vim.fn.bufadd(path))
    vim.api.nvim_set_current_win(editor)
  else
    vim.cmd.edit(vim.fn.fnameescape(path))
  end
end

---@param ctx table
---@return integer
function M.buffer(ctx)
  local bufnr = providers.scratch(M.name, "neoworkbench-explorer")
  M.render(ctx, bufnr)

  -- The entries are numbered, so a click on a line opens the entry on it.
  local function open_at(line)
    local path = M.state.paths[line]
    if not path then
      return
    end
    if vim.fn.isdirectory(path) == 1 then
      M.state.collapsed[path] = not M.state.collapsed[path]
      M.render(ctx, bufnr)
    else
      M.open(path)
    end
  end

  vim.keymap.set("n", "<CR>", function()
    open_at(vim.api.nvim_win_get_cursor(0)[1])
  end, { buffer = bufnr, desc = "Open the entry" })

  vim.keymap.set("n", "<Space>", function()
    open_at(vim.api.nvim_win_get_cursor(0)[1])
  end, { buffer = bufnr, desc = "Open the entry" })

  vim.keymap.set("n", "<Tab>", function()
    local path = M.state.paths[vim.api.nvim_win_get_cursor(0)[1]]
    if path and vim.fn.isdirectory(path) == 1 then
      M.state.collapsed[path] = not M.state.collapsed[path]
      M.render(ctx, bufnr)
    end
  end, { buffer = bufnr, desc = "Collapse or expand the directory" })

  vim.keymap.set("n", "h", function()
    local path = M.state.paths[vim.api.nvim_win_get_cursor(0)[1]]
    if path and vim.fn.isdirectory(path) == 1 and M.state.collapsed[path] ~= true then
      M.state.collapsed[path] = true
      M.render(ctx, bufnr)
    elseif path then
      -- Go to the parent.
      local parent = vim.fn.fnamemodify(path, ":h")
      for i, p in ipairs(M.state.paths) do
        if p == parent then
          vim.api.nvim_win_set_cursor(0, { i, 0 })
          return
        end
      end
    end
  end, { buffer = bufnr, desc = "Collapse the directory, or go to the parent" })

  vim.keymap.set("n", "l", function()
    local path = M.state.paths[vim.api.nvim_win_get_cursor(0)[1]]
    if not path then
      return
    end
    if vim.fn.isdirectory(path) == 1 then
      if M.state.collapsed[path] == true then
        M.state.collapsed[path] = false
        M.render(ctx, bufnr)
      end
    else
      M.open(path)
    end
  end, { buffer = bufnr, desc = "Expand the directory, or open the file" })

  vim.keymap.set("n", "a", function()
    local path = M.state.paths[vim.api.nvim_win_get_cursor(0)[1]]
    local dir = path and (vim.fn.isdirectory(path) == 1 and path or vim.fn.fnamemodify(path, ":h")) or M.state.dir
    local name = vim.fn.input("New file: ", dir .. "/", "file")
    if name and name ~= "" then
      vim.fn.mkdir(vim.fn.fnamemodify(name, ":h"), "p")
      vim.fn.writefile({}, name)
      M.state.collapsed[dir] = false
      M.render(ctx, bufnr)
      M.open(name)
    end
  end, { buffer = bufnr, desc = "Create a file" })

  vim.keymap.set("n", "A", function()
    local path = M.state.paths[vim.api.nvim_win_get_cursor(0)[1]]
    local dir = path and (vim.fn.isdirectory(path) == 1 and path or vim.fn.fnamemodify(path, ":h")) or M.state.dir
    local name = vim.fn.input("New directory: ", dir .. "/", "dir")
    if name and name ~= "" then
      vim.fn.mkdir(name, "p")
      M.state.collapsed[dir] = false
      M.render(ctx, bufnr)
    end
  end, { buffer = bufnr, desc = "Create a directory" })

  vim.keymap.set("n", "r", function()
    local path = M.state.paths[vim.api.nvim_win_get_cursor(0)[1]]
    if not path or path == M.state.dir then
      return
    end
    local name = vim.fn.input("Rename: ", path)
    if name and name ~= "" and name ~= path then
      vim.fn.rename(path, name)
      M.render(ctx, bufnr)
    end
  end, { buffer = bufnr, desc = "Rename the entry" })

  vim.keymap.set("n", "d", function()
    local path = M.state.paths[vim.api.nvim_win_get_cursor(0)[1]]
    if not path or path == M.state.dir then
      return
    end
    local choice = vim.fn.confirm("Delete " .. vim.fn.fnamemodify(path, ":t") .. "?", "&Yes\n&No", 2)
    if choice == 1 then
      if vim.fn.isdirectory(path) == 1 then
        vim.fn.delete(path, "rf")
      else
        vim.fn.delete(path)
      end
      M.render(ctx, bufnr)
    end
  end, { buffer = bufnr, desc = "Delete the entry" })

  vim.keymap.set("n", ".", function()
    M.state.hidden = not M.state.hidden
    M.render(ctx, bufnr)
  end, { buffer = bufnr, desc = "Show and hide the files that start with a dot" })

  vim.keymap.set("n", "R", function()
    M.state.git = {}
    M.state.git_time = 0
    M.render(ctx, bufnr)
  end, { buffer = bufnr, desc = "Refresh the tree" })

  vim.keymap.set("n", "q", function()
    require("neoworkbench").close()
  end, { buffer = bufnr, desc = "Close the workbench" })

  -- A click on a line opens the entry on it.
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    if mouse.winid == vim.api.nvim_get_current_win() then
      vim.api.nvim_win_set_cursor(0, { mouse.line, 0 })
      open_at(mouse.line)
    end
  end, { buffer = bufnr, desc = "Open the entry" })

  return bufnr
end

return M
