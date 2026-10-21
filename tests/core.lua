local root = vim.fn.getcwd()
package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  root .. "/?.lua",
  package.path,
}, ";")
vim.opt.rtp:append(root)

local t = require("tests.helper")

local core = require("neocore")
local palette = require("neocore.palette")
local util = require("neocore.util")
local win = require("neocore.win")

T_group("palette")

for _, name in ipairs(palette.names()) do
  local pal = palette.palette(name)
  local missing = {}
  for _, key in ipairs(palette.keys) do
    if pal[key] == nil then
      missing[#missing + 1] = key
    end
  end
  T_eq("theme " .. name .. " exposes every key", missing, {})
  T_check("theme " .. name .. " has a background", type(pal.bg) == "string", pal.bg)
end

T_check("auto is listed first", palette.names()[1] == "auto")
T_check("unknown theme falls back to aurora", palette.palette("does-not-exist").bg == palette.themes.aurora.bg)
T_check("unknown theme is not a theme", palette.is_theme("does-not-exist") == false)
T_check("auto is not a theme", palette.is_theme("auto") == false)
T_check("aurora is a theme", palette.is_theme("aurora") == true)

local transparent = palette.palette("aurora", true)
T_eq("transparent clears the background", transparent.bg, "NONE")
T_check("transparent keeps the text", transparent.text == palette.themes.aurora.text)

T_group("auto palette follows the colorscheme")

-- The highlight groups a colorscheme sets, defined here so the test does not
-- depend on the colorschemes that ship with Neovim, they differ between the
-- versions.
local function use_colors(fg, bg)
  for _, name in ipairs({
    "Normal",
    "Comment",
    "Function",
    "Statement",
    "Constant",
    "Type",
    "String",
    "DiagnosticError",
    "DiagnosticWarn",
    "DiagnosticInfo",
    "DiagnosticOk",
    "DiagnosticHint",
  }) do
    vim.api.nvim_set_hl(0, name, { fg = fg, bg = bg })
  end
end

use_colors("#c9d5f3", "#0b1020")
local dark = palette.auto_palette()
use_colors("#3f3a33", "#f6f3ec")
local light = palette.auto_palette()
T_check("auto palette reacts to the colorscheme", dark.bg ~= light.bg, dark.bg .. " vs " .. light.bg)
T_eq("auto palette takes the background of a dark scheme", dark.bg, "#0b1020")
T_eq("auto palette takes the background of a light scheme", light.bg, "#f6f3ec")
T_check("auto palette derives a surface", dark.surface ~= dark.bg, dark.surface)
T_check("auto palette makes a light surface darker", light.surface ~= light.bg, light.surface)

use_colors("#c9d5f3", "#0b1020")
local sampled = palette.auto_palette()
local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
T_eq("auto palette takes the background from Normal", sampled.bg, string.format("#%06x", normal.bg))
T_check("auto palette derives a surface", sampled.surface ~= sampled.bg, sampled.surface)

T_group("highlight registry")

core.hl.reset()
core.setup({ theme = "aurora" })
core.hl.define("NeotestAlpha", { fg = "accent", bg = "surface", bold = true })
core.hl.apply(core.colors())

local alpha = vim.api.nvim_get_hl(0, { name = "NeotestAlpha" })
local aurora = palette.themes.aurora
T_eq("palette token resolves the foreground", string.format("#%06x", alpha.fg), aurora.accent)
T_eq("palette token resolves the background", string.format("#%06x", alpha.bg), aurora.surface)
T_check("boolean attributes survive", alpha.bold == true, vim.inspect(alpha))

core.hl.define("NeotestBeta", { fg = "#ff0000", bg = "NONE" })
core.hl.apply(core.colors())
local beta = vim.api.nvim_get_hl(0, { name = "NeotestBeta" })
T_eq("literal hex is preserved", string.format("#%06x", beta.fg), "#ff0000")
T_check("NONE background is preserved", beta.bg == nil, vim.inspect(beta))

core.hl.define("NeotestGamma", { fg = "not-a-token", bg = "surface" })
core.hl.apply(core.colors())
local gamma = vim.api.nvim_get_hl(0, { name = "NeotestGamma" })
T_check("unknown tokens are left alone", gamma.fg == nil, vim.inspect(gamma))

T_check("registered groups are listed", vim.tbl_contains(core.hl.registered(), "NeotestAlpha"))
T_check(
  "define is idempotent",
  (function()
    local before = #core.hl.registered()
    core.hl.define("NeotestAlpha", { fg = "red" })
    return #core.hl.registered() == before
  end)()
)

core.hl.reset()
core.hl.apply(core.colors())
T_check("reset clears the registry", #core.hl.registered() == 0)

T_group("util")

T_eq("truncate keeps short text", util.truncate("abc", 10), "abc")
T_eq("truncate cuts long text", util.truncate("abcdefgh", 5), "abcd…")
T_eq("truncate handles zero width", util.truncate("abc", 0), "")
T_eq("segments normalise from a string", util.norm_segs("hi"), { { text = "hi" } })
T_eq("segments normalise from a table", util.norm_segs({ text = "hi" }), { { text = "hi" } })
T_eq("segment width", util.segs_width({ { text = "ab" }, { text = "cd" } }), 4)
T_eq("clipping keeps the width", util.segs_width(util.clip_segs({ { text = "abcdef" } }, 3)), 3)
T_eq("row pins both sides", util.segs_width(util.row({ { text = "ab" } }, { { text = "cd" } }, 10)), 10)
T_eq("blend mixes two colours", util.blend("#000000", "#ffffff", 0.5), "#808080")
T_eq("mix samples the first stop", util.mix({ "#ff0000", "#0000ff" }, 0), "#ff0000")
T_eq("mix samples the last stop", util.mix({ "#ff0000", "#0000ff" }, 1), "#0000ff")
T_eq("mix blends two stops", util.mix({ "#ff0000", "#0000ff" }, 0.5), "#800080")
T_eq("mix samples the middle stop of three", util.mix({ "#ff0000", "#00ff00", "#0000ff" }, 0.5), "#00ff00")
T_eq("mix interpolates between stops", util.mix({ "#ff0000", "#00ff00", "#0000ff" }, 0.25), "#808000")
T_eq("mix clamps out of range ratios", util.mix({ "#ff0000", "#0000ff" }, 2), "#0000ff")
T_eq("mix of a single stop", util.mix({ "#ff0000" }, 0.5), "#ff0000")
T_eq("merge is deep", util.merge({ a = { b = 1, c = 2 } }, { a = { c = 3 } }), { a = { b = 1, c = 3 } })
T_eq("merge replaces lists", util.merge({ a = { 1, 2, 3 } }, { a = { 9 } }), { a = { 9 } })

T_eq("distribute splits evenly", util.distribute(100, { 1, 1, 1 }), { 34, 33, 33 })
T_eq("distribute honours the weights", util.distribute(100, { 3, 1 }), { 75, 25 })
T_eq("distribute survives zero weights", util.distribute(10, { 0, 0 }), { 5, 5 })
T_eq("distribute of a single child", util.distribute(7, { 1 }), { 7 })
T_eq("distribute of nothing", util.distribute(7, {}), {})

T_group("window helpers")

vim.o.columns = 120
vim.o.lines = 40

local buf = vim.api.nvim_create_buf(false, true)
local opened = win.open_split(buf, { split = "below", win = -1, height = 8, title = "Panel" })
T_check("a split is created", win.is_valid(opened), tostring(opened))
T_eq("the split honours the height", vim.api.nvim_win_get_height(opened), 8)
T_check(
  "the split is registered in the layout",
  (function()
    local found = false
    local function scan(node)
      if node[1] == "leaf" then
        if node[2] == opened then
          found = true
        end
      else
        for _, child in ipairs(node[2]) do
          scan(child)
        end
      end
    end
    scan(vim.fn.winlayout())
    return found
  end)()
)

T_check(
  "the split carries a winbar title",
  (function()
    local bar = vim.wo[opened].winbar
    return type(bar) == "string" and bar:find("Panel", 1, true) ~= nil
  end)(),
  vim.wo[opened].winbar
)

win.focus(opened)
T_eq("focus moves the current window", vim.api.nvim_get_current_win(), opened)

win.close(opened)
T_check("closing removes the window", not win.is_valid(opened))

T_finish("neocore")
