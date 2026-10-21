-- The problems pane, a list of the diagnostics of the whole workspace.

local providers = require("neoworkbench.providers")

local M = {}

M.name = "problems"
M.title = "Problems"
M.icon = "󰒡"

local severity_names = {
  [vim.diagnostic.severity.ERROR] = "error",
  [vim.diagnostic.severity.WARN] = "warn",
  [vim.diagnostic.severity.INFO] = "info",
  [vim.diagnostic.severity.HINT] = "hint",
}

--- The diagnostics of the workspace, grouped by file.
---@return table[]
local function collect()
  local ok, diagnostics = pcall(vim.diagnostic.get, nil)
  if not ok or not diagnostics then
    return {}
  end

  local by_file = {}
  local order = {}

  for _, diagnostic in ipairs(diagnostics) do
    local name = diagnostic.filename or ""
    if name == "" then
      name = "[No Name]"
    end
    if not by_file[name] then
      by_file[name] = {}
      order[#order + 1] = name
    end
    table.insert(by_file[name], diagnostic)
  end

  return order, by_file
end

--- Render the diagnostics into the buffer.
---@param ctx table
---@param bufnr integer
function M.render(ctx, bufnr)
  local order, by_file = collect()
  local lines = {}

  if #order == 0 then
    lines[1] = "  No problems"
    providers.set_lines(bufnr, lines)
    return
  end

  local total = 0
  for _, name in ipairs(order) do
    local group = by_file[name]
    total = total + #group
    lines[#lines + 1] = name
    for _, diagnostic in ipairs(group) do
      local severity = severity_names[diagnostic.severity] or "info"
      lines[#lines + 1] =
        string.format("  %d:%d  %s  %s", diagnostic.lnum + 1, diagnostic.col + 1, severity, diagnostic.message)
    end
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = string.format("  %d problems in %d files", total, #order)

  providers.set_lines(bufnr, lines)
end

---@param ctx table
---@return integer
function M.buffer(ctx)
  local bufnr = providers.scratch(M.name, "neoworkbench-problems")
  M.render(ctx, bufnr)

  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    local lnum = tonumber(line:match("^%s*(%d+):")) or 1
    local ok, diagnostics = pcall(vim.diagnostic.get, nil)
    if not ok then
      return
    end
    for _, diagnostic in ipairs(diagnostics) do
      if diagnostic.lnum + 1 == lnum then
        vim.api.nvim_set_current_buf(diagnostic.bufnr)
        vim.api.nvim_win_set_cursor(0, { diagnostic.lnum + 1, diagnostic.col })
        return
      end
    end
  end, { buffer = bufnr, desc = "Jump to the problem" })

  return bufnr
end

return M
