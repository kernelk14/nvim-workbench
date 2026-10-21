-- The output pane, a log the workbench writes to.

local providers = require("neoworkbench.providers")

local M = {}

M.name = "output"
M.title = "Output"
M.icon = "󰇦"

--- The lines that were logged.
M.lines = {}

--- Append a line to the log.
---@param text string
function M.log(text)
  M.lines[#M.lines + 1] = { text = text, time = os.time() }
  if #M.lines > 500 then
    table.remove(M.lines, 1)
  end
end

--- Clear the log.
function M.clear()
  M.lines = {}
end

--- Render the log into the buffer.
---@param ctx table
---@param bufnr integer
function M.render(ctx, bufnr)
  local lines = {}
  if #M.lines == 0 then
    lines[1] = "  Nothing has been logged yet"
  else
    for _, entry in ipairs(M.lines) do
      lines[#lines + 1] = "  " .. entry.text
    end
  end
  providers.set_lines(bufnr, lines)
end

---@param ctx table
---@return integer
function M.buffer(ctx)
  local bufnr = providers.scratch(M.name, "neoworkbench-output")
  M.render(ctx, bufnr)
  return bufnr
end

return M
