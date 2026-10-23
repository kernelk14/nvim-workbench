local root = vim.fn.getcwd()
package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  root .. "/?.lua",
  package.path,
}, ";")
vim.opt.rtp:append(root)

local t = require("tests.helper")

T_group("every module loads")

local modules = {
  "neocore",
  "neocore.palette",
  "neocore.hl",
  "neocore.util",
  "neocore.win",
  "neocore.health",
  "neoworkbench",
  "neoworkbench.config",
  "neoworkbench.spec",
  "neoworkbench.geometry",
  "neoworkbench.focus",
  "neoworkbench.apply",
  "neoworkbench.pane",
  "neoworkbench.session",
  "neoworkbench.highlights",
  "neoworkbench.health",
  "neoworkbench.providers",
  "neoworkbench.providers.editor",
  "neoworkbench.providers.explorer",
  "neoworkbench.providers.problems",
  "neoworkbench.providers.quickfix",
  "neoworkbench.providers.output",
  "neoworkbench.providers.terminal",
  "neoworkbench.providers.outline",
  "neoworkbench.popup",
}

for _, name in ipairs(modules) do
  local ok, err = pcall(require, name)
  T_check("the module " .. name .. " loads", ok, err)
end

T_group("the public api")

local workbench = require("neoworkbench")

for _, name in ipairs({
  "setup",
  "open",
  "close",
  "toggle",
  "is_open",
  "set_layout",
  "focus_pane",
  "move",
  "set_panel",
  "cycle_panel",
  "refresh",
  "relayout",
  "create_commands",
  "create_keymaps",
  "create_autocmds",
}) do
  T_check("the workbench exposes " .. name .. "()", type(workbench[name]) == "function", type(workbench[name]))
end

local core = require("neocore")
for _, name in ipairs({ "setup", "colors", "palette_names", "apply", "define", "invalidate", "attach" }) do
  T_check("the core exposes " .. name .. "()", type(core[name]) == "function", type(core[name]))
end

T_group("the commands")

workbench.setup({ session = { enabled = false } })

for _, name in ipairs({
  "Workbench",
  "WorkbenchToggle",
  "WorkbenchClose",
  "WorkbenchLayout",
  "WorkbenchFocus",
  "WorkbenchPanel",
  "WorkbenchRefresh",
  "WorkbenchSave",
}) do
  T_check("the command " .. name .. " exists", vim.fn.exists(":" .. name) == 2, vim.fn.exists(":" .. name))
end

T_finish("modules")
