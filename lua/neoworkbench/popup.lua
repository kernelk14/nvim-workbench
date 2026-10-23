-- Popup modal: a floating window that shows a list of choices.
--
-- The popup is the thing the workbench uses for menus. A menu is a list of
-- items, every item has a label, an icon and a key. The user moves through
-- the items with j and k, runs one with Enter or its key, and closes the
-- popup with q or Escape. A mouse click on an item runs it as well.
--
--   ╭─ 󰘳 Run on ─────────────────────╮
--   │ 󰘳  Android emulator        a  │
--   │ 󰘳  iOS simulator            i  │
--   │ 󰘳  Web (Chrome)             w  │
--   │ 󰘳  Windows                  W  │
--   │ 󰘳  macOS                    m  │
--   │ 󰘳  Linux                    l  │
--   ╰────────────────────────────────╯
--
-- The popup is used for things like the Flutter run platform menu, the
-- layout picker and the panel picker. It is a normal floating window, so it
-- can be styled with the highlight groups of the workbench.

local neowin = require("neocore.win")
local util = require("neocore.util")

local M = {}

--- The state of the popup.
M.state = {
  winid = nil,
  bufnr = nil,
  items = {},
  selected = 1,
  on_select = nil,
  on_close = nil,
}

--- The highlight groups of the popup.
M.groups = {
  NeoworkbenchPopupNormal = { fg = "text", bg = "surface" },
  NeoworkbenchPopupBorder = { fg = "border", bg = "surface" },
  NeoworkbenchPopupTitle = { fg = "accent2", bg = "surface", bold = true },
  NeoworkbenchPopupIcon = { fg = "accent2", bg = "surface" },
  NeoworkbenchPopupText = { fg = "text", bg = "surface" },
  NeoworkbenchPopupKey = { fg = "text", bg = "surface_alt", bold = true },
  NeoworkbenchPopupSelected = { fg = "bg", bg = "accent", bold = true },
  NeoworkbenchPopupMuted = { fg = "muted", bg = "surface" },
}

--- Close the popup.
function M.close()
  local on_close = M.state.on_close
  if M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then
    vim.api.nvim_win_close(M.state.winid, true)
  end
  if M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
    vim.api.nvim_buf_delete(M.state.bufnr, { force = true })
  end
  M.state.winid = nil
  M.state.bufnr = nil
  M.state.items = {}
  M.state.on_select = nil
  M.state.on_close = nil
  if on_close then
    on_close()
  end
end

--- Whether the popup is open.
---@return boolean
function M.is_open()
  return M.state.winid ~= nil and vim.api.nvim_win_is_valid(M.state.winid)
end

--- The width of the content of the popup.
---@param items table[]
---@return integer
local function content_width(items)
  local widest = 0
  for _, item in ipairs(items) do
    local label = item.label or ""
    local key = item.key or ""
    local width = vim.fn.strdisplaywidth(label) + vim.fn.strdisplaywidth(key) + 6
    if width > widest then
      widest = width
    end
  end
  return widest
end

--- Render the items into the buffer.
---@param bufnr integer
---@param items table[]
---@param selected integer
local function render(bufnr, items, selected)
  local lines = {}
  for i, item in ipairs(items) do
    local icon = item.icon or ""
    local label = item.label or ""
    local key = item.key or ""
    local hl = (i == selected) and "NeoworkbenchPopupSelected" or "NeoworkbenchPopupText"

    local left = icon .. "  " .. label
    local right = key ~= "" and ("  " .. key .. " ") or ""

    -- Pad the line so the key sits at the right edge.
    local padding = math.max(1, 40 - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(right))
    local line = left .. string.rep(" ", padding) .. right

    lines[#lines + 1] = line
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
end

--- Open the popup.
---@param opts table? `title`, `items`, `selected`, `on_select`, `on_close`, `width`, `height`, `border`
---@return boolean ok
function M.open(opts)
  opts = opts or {}
  M.close()

  local items = opts.items or {}
  if #items == 0 then
    return false
  end

  local width = opts.width or math.max(30, content_width(items) + 4)
  local height = opts.height or #items

  -- Centre the popup in the editor.
  local cols = vim.o.columns
  local lines = vim.o.lines
  local row = math.floor((lines - height) / 2)
  local col = math.floor((cols - width) / 2)

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "neoworkbench-popup"

  M.state.bufnr = bufnr
  M.state.items = items
  M.state.selected = opts.selected or 1
  M.state.on_select = opts.on_select
  M.state.on_close = opts.on_close

  render(bufnr, items, M.state.selected)

  local border = opts.border or "rounded"
  local title = opts.title or ""

  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = border,
    title = title ~= "" and (" " .. title .. " ") or nil,
    title_pos = "left",
    zindex = 50,
  })

  M.state.winid = winid

  -- The window keeps the options of a plain window.
  vim.wo[winid].cursorline = true
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = "no"
  vim.wo[winid].winblend = 0

  -- The keys of the popup.
  local function select_current()
    local item = M.state.items[M.state.selected]
    if item then
      local callback = M.state.on_select
      M.close()
      if callback then
        callback(item)
      end
    end
  end

  local function move(delta)
    local count = #M.state.items
    M.state.selected = M.state.selected + delta
    if M.state.selected < 1 then
      M.state.selected = count
    elseif M.state.selected > count then
      M.state.selected = 1
    end
    render(M.state.bufnr, M.state.items, M.state.selected)
    vim.api.nvim_win_set_cursor(M.state.winid, { M.state.selected, 0 })
  end

  -- Navigation.
  vim.keymap.set("n", "j", function()
    move(1)
  end, { buffer = bufnr, desc = "Next item" })
  vim.keymap.set("n", "k", function()
    move(-1)
  end, { buffer = bufnr, desc = "Previous item" })
  vim.keymap.set("n", "<Down>", function()
    move(1)
  end, { buffer = bufnr, desc = "Next item" })
  vim.keymap.set("n", "<Up>", function()
    move(-1)
  end, { buffer = bufnr, desc = "Previous item" })

  -- Selection.
  vim.keymap.set("n", "<CR>", select_current, { buffer = bufnr, desc = "Select the item" })
  vim.keymap.set("n", "<Space>", select_current, { buffer = bufnr, desc = "Select the item" })

  -- Closing.
  vim.keymap.set("n", "q", function()
    local callback = M.state.on_close
    M.close()
    if callback then
      callback()
    end
  end, { buffer = bufnr, desc = "Close the popup" })
  vim.keymap.set("n", "<Esc>", function()
    local callback = M.state.on_close
    M.close()
    if callback then
      callback()
    end
  end, { buffer = bufnr, desc = "Close the popup" })

  -- The keys of the items.
  for _, item in ipairs(items) do
    if item.key and item.key ~= "" then
      vim.keymap.set("n", item.key, function()
        local index = nil
        for i, it in ipairs(M.state.items) do
          if it == item then
            index = i
            break
          end
        end
        if index then
          M.state.selected = index
          select_current()
        end
      end, { buffer = bufnr, desc = item.label or "" })
    end
  end

  -- A click on a line selects it.
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    if mouse.winid == M.state.winid and mouse.line > 0 and mouse.line <= #items then
      M.state.selected = mouse.line
      render(M.state.bufnr, M.state.items, M.state.selected)
      select_current()
    end
  end, { buffer = bufnr, desc = "Select the item" })

  -- The cursor starts on the first item.
  vim.api.nvim_win_set_cursor(winid, { M.state.selected, 0 })

  return true
end

--- Open a popup and wait for the user to pick an item.
---@param opts table? `title`, `items`, `on_select`, `on_close`
---@return table? item The item that was picked, or nil.
function M.pick(opts)
  opts = opts or {}
  local result = nil
  local done = false

  opts.on_select = function(item)
    result = item
    done = true
  end
  opts.on_close = function()
    done = true
  end

  M.open(opts)

  vim.wait(300000, function()
    return done
  end, 10)

  return result
end

return M
