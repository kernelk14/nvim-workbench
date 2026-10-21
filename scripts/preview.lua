-- Print the workbench layout as plain text.
--
--   nvim --clean --headless -l scripts/preview.lua

local root = vim.fn.getcwd()
package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  package.path,
}, ";")
vim.opt.rtp:append(root)

vim.o.columns = tonumber(os.getenv("NEO_COLS") or 100)
vim.o.lines = tonumber(os.getenv("NEO_ROWS") or 30)

local workbench = require("neoworkbench")
local pane = require("neoworkbench.pane")
local geometry = require("neoworkbench.geometry")

workbench.setup({ session = { enabled = false } })
workbench.open()

local cols, lines = require("neoworkbench.apply").extent()
local rects = geometry.compute(pane.state.tree, cols, lines)

print(string.format("workbench %dx%d", cols, lines))
print("")

for _, rect in ipairs(rects) do
  local winid = pane.win(rect.pane)
  local bar = vim.wo[winid].winbar or ""
  print(string.format("  %-10s x=%-3d y=%-3d %dx%d  %s", rect.pane, rect.x, rect.y, rect.w, rect.h, bar))
end

print("")
for _, name in ipairs(pane.names()) do
  local bufnr = pane.buf(name)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local content = vim.api.nvim_buf_get_lines(bufnr, 0, 6, false)
    print("  " .. name .. ":")
    for _, line in ipairs(content) do
      print("    " .. line)
    end
  end
end

workbench.close()
vim.cmd("qa!")
