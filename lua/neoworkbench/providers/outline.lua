-- The outline pane, the symbols of the current document.

local providers = require("neoworkbench.providers")

local M = {}

M.name = "outline"
M.title = "Outline"
M.icon = "󰲡"

--- The document symbols of the current buffer.
---@param bufnr integer
---@return table[]
local function symbols(bufnr)
  local ok, result = pcall(vim.lsp.buf_request_all_sync, bufnr, "textDocument/documentSymbol", 0, 1000)
  if not ok or not result or not result[1] then
    return {}
  end

  local out = {}
  local function walk(items, depth)
    for _, item in ipairs(items) do
      local range = item.range or (item.location and item.location.range)
      local line = range and range[1] + 1 or 0
      out[#out + 1] = {
        name = item.name or "",
        kind = item.kind or 1,
        line = line,
        depth = depth,
      }
      if item.children then
        walk(item.children, depth + 1)
      end
    end
  end
  walk(result[1], 0)
  return out
end

--- Render the outline into the buffer.
---@param ctx table
---@param bufnr integer
function M.render(ctx, bufnr)
  local target = ctx.captured_buf or vim.api.nvim_get_current_buf()
  local items = symbols(target)
  local lines = {}

  if #items == 0 then
    lines[1] = "  No symbols, is a language server attached?"
  else
    for _, item in ipairs(items) do
      lines[#lines + 1] = string.format("%s%s", string.rep("  ", item.depth + 1), item.name)
    end
  end

  providers.set_lines(bufnr, lines)
end

---@param ctx table
---@return integer
function M.buffer(ctx)
  local bufnr = providers.scratch(M.name, "neoworkbench-outline")
  M.render(ctx, bufnr)
  return bufnr
end

return M
