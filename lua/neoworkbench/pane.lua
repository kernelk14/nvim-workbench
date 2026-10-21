-- Pane state.
-- Keeps track of which window and buffer belong to which pane.

local M = {}

M.state = {
  open = false,
  layout = nil,
  tree = nil,
  rects = {},
  panes = {},
  root_win = nil,
  captured_buf = nil,
}

--- Reset every bit of state.
function M.reset()
  M.state = {
    open = false,
    layout = nil,
    tree = nil,
    rects = {},
    panes = {},
    buffers = {},
    root_win = nil,
    captured_buf = nil,
  }
end

--- The window of a pane.
---@param name string
---@return integer?
function M.win(name)
  local entry = M.state.panes[name]
  return entry and entry.win or nil
end

--- The buffer of a pane.
---@param name string
---@return integer?
function M.buf(name)
  local entry = M.state.panes[name]
  return entry and entry.buf or nil
end

--- Register a pane.
---@param name string
---@param winid integer
---@param bufnr integer?
---@param variant table? The third party implementation serving the pane.
function M.set(name, winid, bufnr, variant)
  M.state.panes[name] = { win = winid, buf = bufnr, variant = variant }
end

--- Forget a pane.
---@param name string
function M.remove(name)
  M.state.panes[name] = nil
end

--- The variant that serves a pane.
---@param name string
---@return table?
function M.variant(name)
  local entry = M.state.panes[name]
  return entry and entry.variant or nil
end

--- The names of the registered panes.
---@return string[]
function M.names()
  local names = {}
  for name in pairs(M.state.panes) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

--- The pane a window belongs to.
---@param winid integer?
---@return string?
function M.pane_of(winid)
  if not winid then
    return nil
  end
  for name, entry in pairs(M.state.panes) do
    if entry.win == winid then
      return name
    end
  end
  return nil
end

--- True when the workbench is open.
---@return boolean
function M.is_open()
  return M.state.open == true
end

return M
