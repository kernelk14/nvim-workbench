-- Window helpers shared by the neo plugins.
--
-- Neovim splits cannot carry a border, only floats can, so pane chrome is
-- drawn with a winbar and the split separator acts as the divider.

local util = require("neocore.util")

local M = {}

--- The border styles the plugins understand.
M.border_styles = { "none", "single", "double", "rounded", "solid", "shadow" }

--- Build a border table with an optional title. Only valid for floats.
---@param style string? One of `M.border_styles`.
---@param title string?
---@param title_pos string? `left` or `right`, defaults to `left`.
---@return table|string
function M.border(style, title, title_pos)
  style = style or "rounded"
  if style == "none" then
    return "none"
  end
  local border = { "╭", "╮", "─", "╰", "╯", "│", "│" }
  if title and title ~= "" then
    border.title = title
    border.title_pos = title_pos or "left"
  end
  return border
end

--- Build a winbar string from segment lists.
---@param left any Segment list, a segment, or a plain string.
---@param right any? Optional right aligned segment list.
---@return string
function M.winbar(left, right)
  local parts = {}

  local function push(segs)
    for _, seg in ipairs(util.norm_segs(segs)) do
      parts[#parts + 1] = "%#" .. (seg.hl or "Normal") .. "#" .. (seg.text or "") .. "%*"
    end
  end

  push(left)
  if right ~= nil then
    parts[#parts + 1] = "%="
    push(right)
  end
  return table.concat(parts)
end

--- Set the winbar of a window.
---@param winid integer
---@param left any
---@param right any?
function M.set_title(winid, left, right)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  vim.wo[winid].winbar = M.winbar(left, right)
end

--- Clear the winbar of a window.
---@param winid integer
function M.clear_title(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  vim.wo[winid].winbar = ""
end

--- The options that M.plain changes.
M.plain_options = {
  "number",
  "relativenumber",
  "signcolumn",
  "cursorline",
  "cursorcolumn",
  "foldcolumn",
  "list",
  "spell",
  "wrap",
}

--- Make a window plain, without the decorations of an editing window.
--- A pane that shows a list of things has no use for line numbers and the
--- sign column of the editor.
---@param winid integer
function M.plain(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  local wo = vim.wo[winid]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.cursorline = false
  wo.cursorcolumn = false
  wo.foldcolumn = "0"
  wo.list = false
  wo.spell = false
  wo.wrap = false
end

--- Remember the options of a window that M.plain changes.
---@param winid integer
---@return table? snapshot
function M.snapshot(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return nil
  end
  local values = {}
  for _, name in ipairs(M.plain_options) do
    values[name] = vim.api.nvim_get_option_value(name, { win = winid })
  end
  return values
end

--- Put the options of a window back.
---@param winid integer
---@param snapshot table?
function M.restore(winid, snapshot)
  if not snapshot or not vim.api.nvim_win_is_valid(winid) then
    return
  end
  for name, value in pairs(snapshot) do
    pcall(vim.api.nvim_set_option_value, name, value, { win = winid })
  end
end

--- Open a window as a split of another window.
--- Splitting is the only way to build a layout that spans the full editor,
--- floats cannot be tiled.
--- The window keeps the options of the user, a pane that should be plain
--- says so with M.plain.
---@param bufnr integer
---@param opts table? `split`, `win`, `width`, `height`, `title`, `title_hl`, `noautocmd`
---@return integer winid
function M.open_split(bufnr, opts)
  opts = opts or {}
  local config = {
    split = opts.split or "below",
    win = opts.win or -1,
    width = opts.width,
    height = opts.height,
    noautocmd = opts.noautocmd or false,
  }

  local winid = vim.api.nvim_open_win(bufnr, opts.focus or false, config)

  if opts.title and opts.title ~= "" then
    M.set_title(winid, { { text = " " .. opts.title, hl = opts.title_hl or "Title" } })
  end

  return winid
end

--- Move the cursor to a window.
---@param winid integer
---@return boolean ok
function M.focus(winid)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  vim.api.nvim_set_current_win(winid)
  return true
end

--- Close a window without disturbing the others.
---@param winid integer
---@return boolean ok
function M.close(winid)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  pcall(vim.api.nvim_win_close, winid, true)
  return true
end

--- True when the window still exists.
---@param winid integer?
---@return boolean
function M.is_valid(winid)
  return winid ~= nil and vim.api.nvim_win_is_valid(winid)
end

--- The window id of the current window.
---@return integer
function M.current()
  return vim.api.nvim_get_current_win()
end

--- The split direction of a window, `left`, `right`, `above` or `below`.
---@param winid integer
---@return string?
function M.split_of(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return nil
  end
  return vim.api.nvim_win_get_config(winid).split
end

--- The number of rows the status line takes.
---@return integer
local function status_height()
  local laststatus = vim.o.laststatus
  if laststatus == 0 then
    return 0
  end
  if laststatus == 3 then
    return 2
  end
  if laststatus == 2 then
    -- The global status line only takes two rows once the window is split.
    return #vim.api.nvim_tabpage_list_wins(0) > 1 and 2 or 1
  end
  return 1
end

--- The size of the editor area, without the command line and the status line.
---@return integer cols, integer lines
function M.size()
  -- The columns and lines options always hold the size of the grid, which
  -- makes them reliable in a headless editor as well.
  return vim.o.columns, math.max(1, vim.o.lines - vim.o.cmdheight - status_height())
end

return M
