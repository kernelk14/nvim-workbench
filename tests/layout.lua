local root = vim.fn.getcwd()
package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  root .. "/?.lua",
  package.path,
}, ";")
vim.opt.rtp:append(root)

local t = require("tests.helper")

local config = require("neoworkbench.config")
local spec = require("neoworkbench.spec")
local geometry = require("neoworkbench.geometry")
local focus = require("neoworkbench.focus")

T_group("spec normalisation")

local leaf = spec.normalize({ pane = "editor" })
T_eq("a pane becomes a leaf", leaf.type, "leaf")
T_eq("the pane keeps its name", leaf.pane, "editor")
T_eq("a leaf without a size has none", leaf.size, nil)

local sized = spec.normalize({ pane = "editor", size = 0.5 })
T_eq("a leaf keeps its size", sized.size, 0.5)

local row = spec.normalize({ type = "row", children = { { pane = "a" }, { pane = "b" } } })
T_eq("a row keeps its type", row.type, "row")
T_eq("a row keeps both children", #row.children, 2)

T_eq("the row shorthand works", spec.normalize({ row = { { pane = "a" }, { pane = "b" } } }).type, "row")
T_eq("the col shorthand works", spec.normalize({ col = { { pane = "a" }, { pane = "b" } } }).type, "col")

T_eq("invalid nodes are dropped", spec.normalize({ pane = "editor" }).type, "leaf")
T_eq("nil is not a node", spec.normalize(nil), nil)
T_eq("a number is not a node", spec.normalize(42), nil)
T_eq("an empty pane name is invalid", spec.normalize({ pane = "" }), nil)
T_eq("a container without children is invalid", spec.normalize({ type = "row", children = {} }), nil)
T_eq("a container with only invalid children is invalid", spec.normalize({ type = "row", children = { 1, 2 } }), nil)

local collapsed = spec.normalize({ type = "row", size = 0.4, children = { { pane = "only" } } })
T_eq("a single child container collapses", collapsed.type, "leaf")
T_eq("the collapsed child inherits the size", collapsed.size, 0.4)

T_eq(
  "panes are listed in order",
  spec.panes(spec.normalize({
    type = "col",
    children = {
      { pane = "a" },
      { type = "row", children = { { pane = "b" }, { pane = "c" } } },
    },
  })),
  { "a", "b", "c" }
)

T_eq("a pane is found by name", spec.find_pane(row, "b").pane, "b")
T_eq("a missing pane is nil", spec.find_pane(row, "zzz"), nil)
T_eq("leaves are counted", spec.leaf_count(row), 2)
T_eq("depth of a flat row", spec.depth(row), 2)
T_eq(
  "depth of a nested tree",
  spec.depth(spec.normalize({
    type = "col",
    children = {
      { type = "row", children = { { pane = "a" }, { pane = "b" } } },
      { pane = "c" },
    },
  })),
  3
)

T_group("geometry")

config.setup({})
local tree = spec.normalize_layout(config.layout_spec("default"))
T_check("the default layout normalises", tree ~= nil)

local rects = geometry.compute(tree, 120, 40)
T_eq("every pane has a rectangle", #rects, 3)

local explorer = geometry.by_pane(rects, "explorer")
local editor = geometry.by_pane(rects, "editor")
local panel = geometry.by_pane(rects, "panel")

T_eq("the explorer sits on the left", explorer.x, 0)
T_eq("the explorer is a quarter wide", explorer.w, 30)
T_eq("the editor starts after the separator", editor.x, 31)
T_eq("the editor fills the rest", editor.w, 89)
T_eq("the editor ends at the right edge", editor.x + editor.w, 120)
T_eq("the explorer is full height of the top area", explorer.h, 28)
T_eq("the panel spans the full width", panel.w, 120)
T_eq("the panel sits below the separator", panel.y, 29)
T_eq("the panel is a third of the height", panel.h, 11)
T_eq("the panel ends at the bottom", panel.y + panel.h, 40)

local area = 0
for _, rect in ipairs(rects) do
  area = area + rect.w * rect.h
end
T_eq("the panes leave room for the separators", area + 148, 120 * 40)

T_group("geometry shares the leftover space")

local unsized = spec.normalize_layout({
  type = "row",
  children = {
    { pane = "left", size = 0.25 },
    { pane = "right" },
  },
})
local unsized_rects = geometry.compute(unsized, 100, 10)
T_eq("a fraction is relative to the parent", geometry.by_pane(unsized_rects, "left").w, 24)
T_eq("the rest is given to the sibling", geometry.by_pane(unsized_rects, "right").w, 75)

local even = spec.normalize_layout({
  type = "row",
  children = { { pane = "a" }, { pane = "b" } },
})
local even_rects = geometry.compute(even, 101, 10)
T_eq(
  "children without a size split evenly",
  geometry.by_pane(even_rects, "a").w + geometry.by_pane(even_rects, "b").w,
  100
)

local overfull = spec.normalize_layout({
  type = "row",
  children = { { pane = "a", size = 0.8 }, { pane = "b", size = 0.8 } },
})
local overfull_rects = geometry.compute(overfull, 100, 10)
T_eq(
  "fractions above one are scaled down",
  geometry.by_pane(overfull_rects, "a").w + geometry.by_pane(overfull_rects, "b").w,
  99
)

local rounded = spec.normalize_layout({
  type = "row",
  children = { { pane = "a", size = 0.333 }, { pane = "b", size = 0.333 }, { pane = "c" } },
})
local rounded_rects = geometry.compute(rounded, 100, 10)
T_eq(
  "rounding never loses a cell",
  geometry.by_pane(rounded_rects, "a").w
    + geometry.by_pane(rounded_rects, "b").w
    + geometry.by_pane(rounded_rects, "c").w,
  98
)

T_group("focus")

T_eq("right from the explorer reaches the editor", focus.pick(rects, explorer, "right").pane, "editor")
T_eq("left from the editor reaches the explorer", focus.pick(rects, editor, "left").pane, "explorer")
T_eq("down from the editor reaches the panel", focus.pick(rects, editor, "down").pane, "panel")
T_eq("up from the panel reaches the editor", focus.pick(rects, panel, "up").pane, "editor")
T_eq("there is nothing to the left of the explorer", focus.pick(rects, explorer, "left"), nil)
T_eq("there is nothing above the editor", focus.pick(rects, editor, "up"), nil)

local ide_tree = spec.normalize_layout(config.layout_spec("ide"))
local ide_rects = geometry.compute(ide_tree, 120, 40)
local ide_left = geometry.by_pane(ide_rects, "explorer")
local ide_mid = geometry.by_pane(ide_rects, "editor")
local ide_right = geometry.by_pane(ide_rects, "outline")
T_eq("right from the editor reaches the outline", focus.pick(ide_rects, ide_mid, "right").pane, "outline")
T_eq("left from the outline reaches the editor", focus.pick(ide_rects, ide_right, "left").pane, "editor")
T_eq("right from the left column reaches the editor", focus.pick(ide_rects, ide_left, "right").pane, "editor")

T_eq("an unknown direction picks nothing", focus.pick(rects, editor, "sideways"), nil)
T_eq("a missing current picks nothing", focus.pick(rects, nil, "right"), nil)

T_finish("layout")
