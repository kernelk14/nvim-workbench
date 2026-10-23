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
local popup = require("neoworkbench.popup")

T_group("the popup module")

T_check("the popup module loads", popup ~= nil)
T_check("the popup is closed at the start", not popup.is_open())

T_group("opening a popup")

local items = {
  { icon = "󰘳", label = "First", key = "a", action = "first" },
  { icon = "󰘳", label = "Second", key = "b", action = "second" },
  { icon = "󰘳", label = "Third", key = "c", action = "third" },
}

T_check("a popup with no items does not open", popup.open({ items = {} }) == false)
T_check("a popup with items opens", popup.open({ title = "Test", items = items }) == true)
T_check("the popup is open", popup.is_open())

T_group("the buffer of the popup")

local buf = popup.state.bufnr
T_check("the popup has a buffer", buf ~= nil and vim.api.nvim_buf_is_valid(buf))
T_check("the buffer is not modifiable", vim.bo[buf].modifiable == false)
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
T_check("the buffer has a line per item", #lines == #items, #lines .. " vs " .. #items)

T_group("closing the popup")

popup.close()
T_check("the popup is closed", not popup.is_open())

T_group("the public api")

workbench.setup({ session = { enabled = false } })

T_check("the workbench exposes popup", type(workbench.popup) == "function")
T_check("the workbench exposes popup_open", type(workbench.popup_open) == "function")
T_check("the workbench exposes popup_close", type(workbench.popup_close) == "function")
T_check("the workbench exposes flutter_run", type(workbench.flutter_run) == "function")
T_check("the workbench exposes flutter_reload", type(workbench.flutter_reload) == "function")

T_group("opening a popup through the workbench")

local picked = nil
workbench.popup({
  title = "Test",
  items = items,
  on_select = function(item)
    picked = item
  end,
})
T_check("the popup is open", workbench.popup_open())

-- Close it without picking.
workbench.popup_close()
T_check("the popup is closed", not workbench.popup_open())

T_finish("popup")
