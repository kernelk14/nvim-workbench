-- The explorer pane, a dependency free file tree.
--
-- Directories can be collapsed, files are opened in the editor pane.

local providers = require("neoworkbench.providers")

local M = {}

M.name = "explorer"
M.title = "Explorer"
M.icon = "󰈞"

--- The icons used for the known file types.
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
}

--- The state of the tree.
M.state = {
  dir = nil,
  collapsed = {},
}

--- Alternative implementations of the explorer.
--- Both of them render into the window that is current when they are opened,
--- which is what makes it possible to host them in a pane.
M.variants = {
  oil = {
    module = "oil",
    priority = 20,
    open = function(ctx, winid)
      vim.api.nvim_set_current_win(winid)
      require("oil").open()
    end,
    close = function(ctx, winid)
      pcall(function()
        require("oil").close()
      end)
    end,
  },
  ["neo-tree"] = {
    module = "neo-tree.command",
    priority = 10,
    open = function(ctx, winid)
      vim.api.nvim_set_current_win(winid)
      require("neo-tree.command").execute({
        action = "focus",
        source = "filesystem",
        position = "current",
      })
    end,
    close = function(ctx, winid)
      pcall(function()
        require("neo-tree.command").execute({ action = "close" })
      end)
    end,
  },
}

--- The icon of a file.
---@param path string
---@return string
function M.icon_for(path)
  local extension = path:match("%.([%w_]+)$")
  if extension and M.icons[extension:lower()] then
    return M.icons[extension:lower()]
  end
  local name = path:match("([^/\\]+)$") or path
  if name:sub(1, 1) == "." then
    return "󰈙"
  end
  return "󰈙"
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

  table.sort(dirs)
  table.sort(files)
  return dirs, files
end

--- The path of the entry on a line, filled in while rendering.
M.paths = {}

--- Render the tree into the buffer.
---@param ctx table
---@param bufnr integer
function M.render(ctx, bufnr)
  local dir = M.state.dir or M.root_of(vim.fn.getcwd())
  M.state.dir = dir

  local lines = {}
  M.paths = {}

  local root = M.root_of(dir)
  if root ~= dir then
    lines[#lines + 1] = "  .."
    M.paths[#M.paths] = vim.fn.fnamemodify(dir, ":h")
  end

  local function walk(current, depth)
    local dirs, files = entries(current)
    for _, name in ipairs(dirs) do
      local path = current .. "/" .. name
      local collapsed = M.state.collapsed[path] == true
      lines[#lines + 1] = string.format("%s%s %s", string.rep("  ", depth), collapsed and "󰅉" or "󰐒", name)
      M.paths[#M.paths] = path
      if not collapsed then
        walk(path, depth + 1)
      end
    end
    for _, name in ipairs(files) do
      local path = current .. "/" .. name
      lines[#lines + 1] = string.format("%s%s %s", string.rep("  ", depth), M.icon_for(path), name)
      M.paths[#M.paths] = path
    end
  end

  walk(dir, 0)

  if #lines == 0 then
    lines[1] = "  The directory is empty"
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

  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    local path = M.paths[vim.api.nvim_get_current_line()]
    if not path then
      return
    end
    if vim.fn.isdirectory(path) == 1 then
      M.state.collapsed[path] = not M.state.collapsed[path]
      M.render(ctx, bufnr)
    else
      M.open(path)
    end
  end, { buffer = bufnr, desc = "Open the entry" })

  vim.keymap.set("n", "<Tab>", function()
    local path = M.paths[vim.api.nvim_get_current_line()]
    if path and vim.fn.isdirectory(path) == 1 then
      M.state.collapsed[path] = not M.state.collapsed[path]
      M.render(ctx, bufnr)
    end
  end, { buffer = bufnr, desc = "Collapse or expand the directory" })

  vim.keymap.set("n", "r", function()
    M.render(ctx, bufnr)
  end, { buffer = bufnr, desc = "Refresh the tree" })

  vim.keymap.set("n", "q", function()
    require("neoworkbench").close()
  end, { buffer = bufnr, desc = "Close the workbench" })

  return bufnr
end

return M
