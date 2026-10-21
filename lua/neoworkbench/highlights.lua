-- The highlight groups of the workbench.
-- They are registered with neocore so they follow the colorscheme.

local core = require("neocore")

local M = {}

M.groups = {
  NeoworkbenchNormal = { fg = "text", bg = "bg" },
  NeoworkbenchTitle = { fg = "accent2", bg = "bg", bold = true },
  NeoworkbenchMuted = { fg = "muted", bg = "bg" },
  NeoworkbenchDim = { fg = "dim", bg = "bg" },
  NeoworkbenchAccent = { fg = "accent", bg = "bg" },
  NeoworkbenchAccent2 = { fg = "accent2", bg = "bg" },
  NeoworkbenchDirectory = { fg = "accent", bg = "bg" },
  NeoworkbenchFile = { fg = "text", bg = "bg" },
  NeoworkbenchSelected = { fg = "bg", bg = "accent", bold = true },
  NeoworkbenchError = { fg = "red", bg = "bg" },
  NeoworkbenchWarn = { fg = "yellow", bg = "bg" },
  NeoworkbenchInfo = { fg = "cyan", bg = "bg" },
  NeoworkbenchHint = { fg = "accent3", bg = "bg" },
  NeoworkbenchOk = { fg = "green", bg = "bg" },
}

--- Register the groups with neocore and apply them.
function M.setup()
  core.hl.define_all(M.groups)
  core.hl.apply(core.colors())
end

return M
