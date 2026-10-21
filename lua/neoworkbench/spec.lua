-- Layout specification normalisation.
--
-- Turns the user facing spec into a canonical tree. A canonical node is one of
--
--   { type = "row"|"col", size = number?, children = { node } }
--   { type = "leaf", pane = "editor", size = number?, options = {} }
--
-- The module is pure, every function returns new tables.

local M = {}

--- True when the value is a usable size.
---@param value any
---@return boolean
function M.is_size(value)
  if type(value) ~= "number" then
    return false
  end
  if value <= 0 then
    return false
  end
  return true
end

--- Normalise a list of children, dropping the invalid ones.
---@param list any
---@return table[]
local function normalise_list(list)
  local out = {}
  if type(list) ~= "table" then
    return out
  end
  for _, child in ipairs(list) do
    local node = M.normalize(child)
    if node then
      out[#out + 1] = node
    end
  end
  return out
end

--- Normalise a single node.
---@param node any
---@return table? node
function M.normalize(node)
  if type(node) ~= "table" then
    return nil
  end

  -- A leaf, either { pane = "editor" } or { type = "leaf", pane = "editor" }.
  if type(node.pane) == "string" and node.pane ~= "" then
    local size = nil
    if M.is_size(node.size) then
      size = node.size
    end
    return {
      type = "leaf",
      pane = node.pane,
      size = size,
      options = type(node.options) == "table" and vim.deepcopy(node.options) or {},
    }
  end

  -- A row or a column, either { type = "row", children = {} } or the
  -- { row = {} } and { col = {} } shorthands.
  local kind = nil
  local children = nil

  if node.type == "row" or node.type == "col" then
    kind = node.type
    children = node.children
  elseif type(node.row) == "table" then
    kind = "row"
    children = node.row
  elseif type(node.col) == "table" then
    kind = "col"
    children = node.col
  end

  if not kind then
    return nil
  end

  local list = normalise_list(children)
  if #list == 0 then
    return nil
  end

  local size = nil
  if M.is_size(node.size) then
    size = node.size
  end

  -- A container with a single child is the same as that child, collapsing it
  -- keeps the tree flat and the window algorithm simple.
  if #list == 1 then
    if size ~= nil and list[1].size == nil then
      list[1].size = size
    end
    return list[1]
  end

  return {
    type = kind,
    size = size,
    children = list,
  }
end

--- Normalise a whole layout.
---@param spec any
---@return table? tree
function M.normalize_layout(spec)
  return M.normalize(spec)
end

--- The pane names of every leaf, in visual order.
---@param node table?
---@return string[]
function M.panes(node)
  local out = {}
  local function walk(n)
    if not n then
      return
    end
    if n.type == "leaf" then
      out[#out + 1] = n.pane
      return
    end
    for _, child in ipairs(n.children or {}) do
      walk(child)
    end
  end
  walk(node)
  return out
end

--- The leaf node carrying a pane name.
---@param node table?
---@param pane string
---@return table?
function M.find_pane(node, pane)
  if not node then
    return nil
  end
  if node.type == "leaf" then
    if node.pane == pane then
      return node
    end
    return nil
  end
  for _, child in ipairs(node.children or {}) do
    local found = M.find_pane(child, pane)
    if found then
      return found
    end
  end
  return nil
end

--- Count the leaves of a tree.
---@param node table?
---@return integer
function M.leaf_count(node)
  if not node then
    return 0
  end
  if node.type == "leaf" then
    return 1
  end
  local count = 0
  for _, child in ipairs(node.children or {}) do
    count = count + M.leaf_count(child)
  end
  return count
end

--- The maximum depth of a tree, a single leaf being depth one.
---@param node table?
---@return integer
function M.depth(node)
  if not node then
    return 0
  end
  if node.type == "leaf" then
    return 1
  end
  local deepest = 0
  for _, child in ipairs(node.children or {}) do
    deepest = math.max(deepest, M.depth(child))
  end
  return deepest + 1
end

return M
