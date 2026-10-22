-- The terminal pane, a terminal running inside the pane window.

local providers = require("neoworkbench.providers")

local M = {}

M.name = "terminal"
M.title = "Terminal"
M.icon = "󰞊"

--- The command the terminal runs, an interactive shell when it is empty.
M.command = nil

--- Start a terminal in the window of the pane.
--- A terminal always takes over the window that is current, so the window of
--- the pane has to be focused and hold the buffer first.
---@param winid integer
---@return boolean ok
local function start(winid)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(winid)
  if vim.bo[bufnr].buftype == "terminal" then
    return true
  end

  local cmd = { vim.o.shell }
  if M.command and M.command ~= "" then
    cmd = { vim.o.shell, "-c", M.command }
  end

  vim.api.nvim_set_current_win(winid)
  vim.api.nvim_win_set_buf(winid, bufnr)

  -- termopen works on every version of Neovim, the terminal option of
  -- jobstart is newer and does nothing before Neovim 0.11.
  local ok = pcall(vim.fn.termopen, cmd)
  if not ok then
    ok = pcall(vim.fn.jobstart, cmd, { term = true })
  end
  if not ok then
    return false
  end

  vim.bo[bufnr].filetype = "terminal"
  -- The terminal has to survive a switch to another panel.
  vim.bo[bufnr].bufhidden = "hide"
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
  -- The terminal is started in attach, it needs the window of the pane.
  return providers.scratch(M.name, "neoworkbench-terminal")
end

--- Start the terminal in the window of the pane.
---@param ctx table
---@param winid integer
function M.attach(ctx, winid)
  start(winid)
end

return M
