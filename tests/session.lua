local root = vim.fn.getcwd()
package.path = table.concat({
  root .. "/lua/?.lua",
  root .. "/lua/?/init.lua",
  root .. "/?.lua",
  package.path,
}, ";")
vim.opt.rtp:append(root)

local t = require("tests.helper")

local session = require("neoworkbench.session")
local explorer = require("neoworkbench.providers.explorer")

T_group("the session hash")

T_check("the hash is stable", session.hash("/tmp/project") == session.hash("/tmp/project"))
T_check("different paths hash differently", session.hash("/tmp/project") ~= session.hash("/tmp/other"))
T_check("the hash is short", #session.hash("/tmp/project") <= 16, session.hash("/tmp/project"))

T_group("the session file")

local sandbox = vim.fn.tempname()
vim.fn.mkdir(sandbox, "p")
local original = vim.env.XDG_DATA_HOME
vim.env.XDG_DATA_HOME = sandbox

T_check("the session directory is inside the data home", session.dir():find(sandbox, 1, true) == 1, session.dir())
T_check("a project without a session loads nothing", session.load("/tmp/project") == nil)

T_group("saving and loading")

local state = {
  layout = "default",
  panel = "problems",
  panes = { "editor", "explorer", "panel" },
  buffers = {},
}

T_check("a session is saved", session.save(state, "/tmp/project"))
T_check("the session file exists", vim.fn.filereadable(session.path("/tmp/project")) == 1, session.path("/tmp/project"))

local loaded = session.load("/tmp/project")
T_check("the session is loaded", loaded ~= nil)
T_eq("the layout survives", loaded.layout, "default")
T_eq("the panel survives", loaded.panel, "problems")
T_eq("the panes survive", loaded.panes, { "editor", "explorer", "panel" })
T_eq("the root survives", loaded.root, "/tmp/project")

T_group("clearing a session")

T_check("the session is cleared", session.clear("/tmp/project"))
T_check("a cleared session loads nothing", session.load("/tmp/project") == nil)
T_check("clearing a missing session is harmless", session.clear("/tmp/project") == false)

vim.env.XDG_DATA_HOME = original
vim.fn.delete(sandbox, "rf")

T_finish("session")
