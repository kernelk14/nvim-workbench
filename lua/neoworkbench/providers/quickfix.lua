-- The quickfix pane, a list of the entries of the quickfix list.

local providers = require("neoworkbench.providers")

local M = {}

M.name = "quickfix"
M.title = "Quickfix"
M.icon = "󰄡"

--- Render the quickfix list into the buffer.
---@param ctx table
---@param bufnr integer
function M.render(ctx, bufnr)
  local list = vim.fn.getqflist()
  local lines = {}

  if #list == 0 then
    lines[1] = "  The quickfix list is empty"
    providers.set_lines(bufnr, lines)
    return
  end

  for _, item in ipairs(list) do
    local kind = item.type ~= "" and ("[" .. item.type .. "] ") or ""
    lines[#lines + 1] = string.format("  %s%s:%d  %s", kind, item.bufnr or 0, item.lnum or 0, item.text or "")
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = string.format("  %d entries", #list)

  providers.set_lines(bufnr, lines)
end

---@param ctx table
---@return integer
function M.buffer(ctx)
  local bufnr = providers.scratch(M.name, "neoworkbench-quickfix")
  M.render(ctx, bufnr)

  vim.keymap.set("n", "<CR>", function()
    vim.cmd("copen")
  end, { buffer = bufnr, desc = "Open the quickfix window" })

  return bufnr
end

return M
