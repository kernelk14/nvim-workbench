local root = vim.fn.getcwd()
package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  root .. "/?.lua",
  package.path,
}, ";")
vim.opt.rtp:append(root)

local t = require("tests.helper")

local workbench = require("neoworkbench")
local pane = require("neoworkbench.pane")
local config = require("neoworkbench.config")
local apply = require("neoworkbench.apply")
local spec = require("neoworkbench.spec")
local geometry = require("neoworkbench.geometry")

vim.o.columns = 120
vim.o.lines = 40
vim.o.cmdheight = 1
vim.o.laststatus = 2

workbench.setup({ session = { enabled = false } })

T_group("opening the workbench")

-- The layout is built inside the window that was open, so the expected sizes
-- follow that window.
local root_width = vim.api.nvim_win_get_width(0)
local root_height = vim.api.nvim_win_get_height(0)

local before_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(before_buf, 0, -1, false, { "hello" })
vim.api.nvim_set_current_buf(before_buf)

workbench.open()

T_check("the workbench is open", workbench.is_open())
T_check("the editor pane exists", pane.win("editor") ~= nil)
T_check("the explorer pane exists", pane.win("explorer") ~= nil)
T_check("the panel pane exists", pane.win("panel") ~= nil)
T_eq("the editor keeps the buffer", pane.buf("editor"), before_buf)
T_eq("the cursor is in the editor", pane.pane_of(vim.api.nvim_get_current_win()), "editor")

T_group("the window layout")

local layout = vim.fn.winlayout()
T_eq("the layout has two levels", layout[1], "col")
T_eq("the top level has two children", #layout[2], 2)
T_eq("the top of the layout is a row", layout[2][1][1], "row")
T_eq("the row has two children", #layout[2][1][2], 2)
T_eq("the bottom of the layout is a leaf", layout[2][2][1], "leaf")

local explorer = pane.win("explorer")
local editor = pane.win("editor")
local panel = pane.win("panel")

T_eq("the explorer is a quarter wide", vim.api.nvim_win_get_width(explorer), math.floor((root_width - 1) * 0.25) + 1)
T_eq(
  "the editor takes the rest",
  vim.api.nvim_win_get_width(editor),
  root_width - vim.api.nvim_win_get_width(explorer) - 1
)
T_eq("the panel spans the full width", vim.api.nvim_win_get_width(panel), root_width)
T_eq(
  "the explorer and the editor share a height",
  vim.api.nvim_win_get_height(explorer),
  vim.api.nvim_win_get_height(editor)
)
T_check(
  "the panel is shorter than the editor",
  vim.api.nvim_win_get_height(panel) < vim.api.nvim_win_get_height(editor),
  vim.api.nvim_win_get_height(panel) .. " vs " .. vim.api.nvim_win_get_height(editor)
)
T_eq(
  "the panes fill the height of the root window",
  vim.api.nvim_win_get_height(panel) + vim.api.nvim_win_get_height(editor) + 1,
  root_height
)

T_group("the panes")

T_check("the explorer shows a buffer", pane.buf("explorer") ~= nil)
T_check("the panel shows a buffer", pane.buf("panel") ~= nil)
T_eq("the panel shows the problems provider", vim.bo[pane.buf("panel")].filetype, "neoworkbench-problems")
T_check("the explorer shows a buffer", vim.bo[pane.buf("explorer")].filetype == "neoworkbench-explorer")
T_check("the pane titles are set", (vim.wo[panel].winbar or ""):find("Problems", 1, true) ~= nil, vim.wo[panel].winbar)

T_group("moving the focus")

vim.api.nvim_set_current_win(editor)
T_check("the focus moves left", workbench.move("left"))
T_eq("the explorer is focused", pane.pane_of(vim.api.nvim_get_current_win()), "explorer")

T_check("the focus moves right", workbench.move("right"))
T_eq("the editor is focused", pane.pane_of(vim.api.nvim_get_current_win()), "editor")

T_check("the focus moves down", workbench.move("down"))
T_eq("the panel is focused", pane.pane_of(vim.api.nvim_get_current_win()), "panel")

T_check("the focus moves up", workbench.move("up"))
T_eq("the editor is focused again", pane.pane_of(vim.api.nvim_get_current_win()), "editor")

T_group("the panel provider")

workbench.set_panel("quickfix")
T_eq("the panel switches provider", vim.bo[pane.buf("panel")].filetype, "neoworkbench-quickfix")
workbench.cycle_panel()
T_check("the panel cycles to another provider", vim.bo[pane.buf("panel")].filetype ~= "neoworkbench-quickfix")
T_check("an unknown provider is rejected", workbench.set_panel("does-not-exist") == false)

T_group("switching the layout")

workbench.set_layout("focus")
T_check("the focus layout has one pane", #pane.names() == 1, table.concat(pane.names(), ","))
T_eq("the editor is still there", pane.win("editor") ~= nil, true)
T_check("the explorer is gone", pane.win("explorer") == nil)

workbench.set_layout("default")
T_check("the default layout comes back", pane.win("explorer") ~= nil)

T_group("closing the workbench")

local root_win = pane.state.root_win
workbench.close()
T_check("the workbench is closed", not workbench.is_open())
T_eq("a single window is left", #vim.api.nvim_tabpage_list_wins(0), 1)
T_eq("the editor buffer survives", vim.api.nvim_get_current_buf(), before_buf)
T_eq("the window is the original one", vim.api.nvim_get_current_win(), root_win)

T_group("the edges")

workbench.close()
T_check("closing a closed workbench is harmless", not workbench.is_open())
T_check("moving the focus without a workbench is harmless", workbench.move("right") == false)
T_check("focusing a pane without a workbench is harmless", workbench.focus_pane("editor") == false)
T_check("refreshing without a workbench is harmless", workbench.refresh() == nil)
T_check("relayout without a workbench is harmless", workbench.relayout() == nil)

T_group("opening twice")

workbench.open()
T_check("the workbench opens", workbench.is_open())
T_check("opening it twice does nothing", workbench.open() == false)
T_eq("the panes are still there", #pane.names(), 3)

T_group("relayout")

workbench.relayout()
T_check("the panes survive a relayout", pane.win("editor") ~= nil)

local cols, lines = apply.extent()
T_check("the extent is measured", cols > 0 and lines > 0, cols .. "x" .. lines)

-- After a relayout every pane matches the geometry of the area it covers.
local tree = spec.normalize_layout(config.layout_spec(pane.state.layout))
local rects = geometry.compute(tree, cols, lines)
T_eq("the geometry has a rectangle for every pane", #rects, 3)
for _, rect in ipairs(rects) do
  local winid = pane.win(rect.pane)
  T_eq("the " .. rect.pane .. " keeps its width", vim.api.nvim_win_get_width(winid), rect.w)
  T_eq("the " .. rect.pane .. " keeps its height", vim.api.nvim_win_get_height(winid), rect.h)
end

workbench.close()

T_finish("workbench")
