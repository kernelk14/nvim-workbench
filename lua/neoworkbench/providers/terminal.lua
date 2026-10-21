-- The terminal pane, a terminal running inside the pane window.

local providers = require("neoworkbench.providers")

local M = {}

M.name = "terminal"
M.title = "Terminal"
M.icon = "󰞊"

--- The command the terminal runs, an interactive shell when it is empty.
M.command = nil

--- Start the terminal inside a buffer.
---@param bufnr integer
---@return boolean ok
local function start(bufnr)
  local shell = vim.o.shell
  local args = { shell }
  if M.command and M.command ~= "" then
    args = { shell, "-c", M.command }
  end

  local ok = pcall(vim.fn.termopen, bufnr, args)
  if not ok then
    return false
  end
  vim.bo[bufnr].filetype = "terminal"
  return true
end

--- Render the terminal pane.
---@param ctx table
---@param bufnr integer
function M.render(ctx, bufnr)
  -- A terminal buffer is written by the terminal itself, nothing to do.
end

---@param ctx table
---@return integer
function M.buffer(ctx)
  local bufnr = providers.scratch(M.name, "neoworkbench-terminal")
  start(bufnr)
  return bufnr
end

return M
