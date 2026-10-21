-- Turning a layout tree into real windows.
--
-- The algorithm walks the tree from the outside in. When a container is split
-- into children the original window keeps the first child and every following
-- child is carved out of it, from the last one backwards. Splitting a window
-- inserts the new one right next to it, so carving the children from the back
-- to the front keeps them in the order of the tree.

local neowin = require("neocore.win")
local pane = require("neoworkbench.pane")

local M = {}

--- Build the windows of a tree.
---@param tree table The normalised tree, its leaves carry a `rect`.
---@param root_win integer The window the tree is built in.
---@param scratch integer A scratch buffer used while the providers take over.
---@return table<string, integer> assignments The window of every pane.
function M.build(tree, root_win, scratch)
  local assignments = {}

  local function assign(node, winid)
    if node.type == "leaf" then
      assignments[node.pane] = winid
      return
    end

    local children = node.children or {}
    if #children == 0 then
      return
    end
    if #children == 1 then
      assign(children[1], winid)
      return
    end

    local horizontal = node.type == "row"
    local windows = { [1] = winid }

    -- Carve the children out of the first window, last one first.
    for i = #children, 2, -1 do
      local rect = children[i].rect
      local opts = {
        split = horizontal and "right" or "below",
        win = winid,
        focus = false,
      }
      if horizontal then
        opts.width = rect.w
      else
        opts.height = rect.h
      end

      local ok, created = pcall(neowin.open_split, scratch, opts)
      windows[i] = ok and created or nil
    end

    for i, child in ipairs(children) do
      if windows[i] then
        assign(child, windows[i])
      end
    end
  end

  assign(tree, root_win)
  return assignments
end

--- Hand the buffer that was being edited over to the editor pane.
---@param editor_win integer?
---@param captured_buf integer?
---@param root_win integer
function M.handoff(editor_win, captured_buf, root_win)
  if not editor_win or not captured_buf or editor_win == root_win then
    return
  end
  if not vim.api.nvim_buf_is_valid(captured_buf) then
    return
  end

  -- The buffer is still shown in the root window, free it first.
  local scratch = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_win_set_buf, root_win, scratch)
  pcall(vim.api.nvim_win_set_buf, editor_win, captured_buf)
end

--- The area the workbench occupies.
--- The root window is only one pane of the layout, so the extent is measured
--- from the panes themselves.
---@return integer cols, integer lines
function M.extent()
  local min_x, min_y, max_x, max_y

  for _, name in ipairs(pane.names()) do
    local winid = pane.win(name)
    if winid and neowin.is_valid(winid) then
      local position = vim.api.nvim_win_get_position(winid)
      local width = vim.api.nvim_win_get_width(winid)
      local height = vim.api.nvim_win_get_height(winid)
      local x, y = position[2], position[1]
      min_x = math.min(min_x or x, x)
      min_y = math.min(min_y or y, y)
      max_x = math.max(max_x or 0, x + width - 1)
      max_y = math.max(max_y or 0, y + height - 1)
    end
  end

  if not min_x then
    return 0, 0
  end
  return max_x - min_x + 1, max_y - min_y + 1
end

--- Resize the panes after the editor was resized.
---
--- A row splits its space horizontally, so the width of the leaves of a row is
--- what has to be set. A column splits its space vertically, so the height of
--- the leaves of a column is what has to be set. Neovim moves the split that
--- belongs to the window, the neighbours follow.
---@param tree table
function M.resize(tree)
  local function apply_sizes(node)
    if node.type == "leaf" then
      return
    end

    local children = node.children or {}
    if #children == 0 then
      return
    end

    local horizontal = node.type == "row"

    for i = #children, 1, -1 do
      local child = children[i]
      local rect = child.rect
      if child.type == "leaf" and rect then
        local winid = pane.win(child.pane)
        if winid and neowin.is_valid(winid) then
          if horizontal then
            pcall(vim.api.nvim_win_set_width, winid, rect.w)
          else
            pcall(vim.api.nvim_win_set_height, winid, rect.h)
          end
        end
      end
      apply_sizes(child)
    end
  end

  apply_sizes(tree)
end

--- Close every pane window but the root one.
--- The buffer of the editor pane is moved into the root window so the editor
--- is left exactly as it was before the workbench opened.
---@param keep_buf integer? The buffer that should survive in the root window.
---@return integer? root_win
function M.close(keep_buf)
  local root = pane.state.root_win

  for name, entry in pairs(pane.state.panes) do
    if entry.win and entry.win ~= root then
      neowin.close(entry.win)
    end
  end

  if root and neowin.is_valid(root) then
    if keep_buf and vim.api.nvim_buf_is_valid(keep_buf) then
      pcall(vim.api.nvim_win_set_buf, root, keep_buf)
    end
    neowin.focus(root)
  end

  pane.reset()
  return root
end

return M
