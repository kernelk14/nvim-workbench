-- Geometry: turns a layout tree into a set of rectangles.
-- The module is pure, it never touches the editor.

local util = require("neocore.util")

local M = {}

--- The size every child receives inside its parent.
---
--- A child may declare a `size` between zero and one, which is a fraction of
--- the parent. Children without a size share whatever is left. The sizes always
--- add up to the length of the parent so the layout tiles exactly.
---@param children table[]
---@param total integer
---@return integer[] sizes
function M.sizes(children, total)
  local count = #children
  local sizes = {}
  local fractions = {}
  local unsized = {}
  local sum = 0

  for i, child in ipairs(children) do
    local size = child.size
    if type(size) == "number" and size > 0 and size <= 1 then
      fractions[i] = size
      sum = sum + size
    else
      unsized[#unsized + 1] = i
    end
  end

  -- Fractions above one are scaled down so the children always fit.
  local scale = 1
  if sum > 1 then
    scale = 1 / sum
    sum = 1
  end

  local used = 0
  for i, fraction in pairs(fractions) do
    local size = math.floor(total * fraction * scale)
    sizes[i] = size
    used = used + size
  end

  local leftover = total - used
  if #unsized > 0 then
    local weights = {}
    for _ = 1, #unsized do
      weights[#weights + 1] = 1
    end
    local share = util.distribute(leftover, weights)
    for k, i in ipairs(unsized) do
      sizes[i] = share[k]
    end
  elseif count > 0 then
    local weights = {}
    for _ = 1, count do
      weights[#weights + 1] = 1
    end
    local share = util.distribute(leftover, weights)
    for i, size in ipairs(share) do
      sizes[i] = (sizes[i] or 0) + size
    end
  end

  return sizes
end

--- Lay a tree out inside a rectangle.
---
--- Neovim draws a one cell separator between the windows of a row or a column,
--- the space of those separators is taken out of the children so the panes end
--- up with exactly the size they asked for.
---@param node table
---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@param out table[] Collected rectangles.
local function place(node, x, y, w, h, out)
  if node.type == "leaf" then
    local rect = {
      pane = node.pane,
      x = x,
      y = y,
      w = w,
      h = h,
    }
    node.rect = rect
    out[#out + 1] = rect
    return
  end

  local horizontal = node.type == "row"
  local children = node.children or {}
  local count = #children
  local total = horizontal and w or h
  local available = math.max(1, total - (count - 1))
  local sizes = M.sizes(children, available)

  local offset = 0
  for i, child in ipairs(children) do
    local size = sizes[i]
    if horizontal then
      place(child, x + offset, y, size, h, out)
    else
      place(child, x, y + offset, w, size, out)
    end
    offset = offset + size + 1
  end
end

--- Compute the rectangles of a layout tree.
--- The tree is not modified, the rectangles are returned on their own.
---@param tree table?
---@param cols integer
---@param lines integer
---@return table[] rects
function M.compute(tree, cols, lines)
  local out = {}
  if not tree then
    return out
  end
  place(tree, 0, 0, cols, lines, out)
  return out
end

--- The centre of a rectangle.
---@param rect table
---@return number x, number y
function M.center(rect)
  return rect.x + rect.w / 2, rect.y + rect.h / 2
end

--- The rectangle of a pane.
---@param rects table[]
---@param pane string
---@return table?
function M.by_pane(rects, pane)
  for _, rect in ipairs(rects or {}) do
    if rect.pane == pane then
      return rect
    end
  end
  return nil
end

--- The rectangles that overlap a point.
---@param rects table[]
---@param x number
---@param y number
---@return table[]
function M.at(rects, x, y)
  local out = {}
  for _, rect in ipairs(rects or {}) do
    if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
      out[#out + 1] = rect
    end
  end
  return out
end

return M
