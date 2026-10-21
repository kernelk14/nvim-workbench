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
local providers = require("neoworkbench.providers")
local explorer = require("neoworkbench.providers.explorer")

T_group("the variant registry")

providers.load_defaults()

T_check("the explorer knows oil", explorer.variants.oil ~= nil)
T_check("the explorer knows neo-tree", explorer.variants["neo-tree"] ~= nil)
T_eq("the oil variant names its module", explorer.variants.oil.module, "oil")
T_eq("the neo-tree variant names its module", explorer.variants["neo-tree"].module, "neo-tree.command")

T_check("a missing module is not available", providers.available("definitely-not-a-real-module") == false)
T_check("an empty module is not available", providers.available("") == false)
T_check("a module on the runtime path is available", providers.available("neoworkbench.providers") == true)
T_check("a module inside a package is available", providers.available("neoworkbench.providers.explorer") == true)

T_group("resolving a provider")

local provider, variant = providers.resolve("explorer", "auto")
T_eq("the explorer resolves to its provider", provider.name, "explorer")
T_eq("without a plugin the built in implementation is used", variant, nil)

provider, variant = providers.resolve("explorer", "builtin")
T_eq("the built in implementation can be forced", variant, nil)

provider, variant = providers.resolve("explorer", "oil")
T_eq("a variant that is not installed is not used", variant, nil)

provider, variant = providers.resolve("does-not-exist", "auto")
T_eq("an unknown provider resolves to nothing", provider, nil)
T_check("the variant names are listed", vim.tbl_contains(providers.variant_names("explorer"), "oil"))

T_group("a third party plugin takes over the pane")

-- A stand in for a plugin that renders into the current window.
local calls = {}
local fake = {}

local function install_fake()
  package.loaded["fakeexplorer"] = {
    open = function()
      calls[#calls + 1] = "open"
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "from the fake plugin" })
      vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
    end,
    close = function()
      calls[#calls + 1] = "close"
    end,
  }
  -- Make the module look like it is installed.
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir .. "/lua/fakeexplorer", "p")
  local file = io.open(dir .. "/lua/fakeexplorer/init.lua", "w")
  file:write("return {}")
  file:close()
  vim.opt.rtp:append(dir)
  providers.invalidate()
  return dir
end

local dir = install_fake()
T_check("the fake plugin is available", providers.available("fakeexplorer") == true)

local fake_provider = {
  name = "explorer",
  title = "Explorer",
  icon = "󰈞",
  variants = {
    fake = {
      module = "fakeexplorer",
      open = function(ctx, winid)
        vim.api.nvim_set_current_win(winid)
        require("fakeexplorer").open()
      end,
      close = function(ctx, winid)
        require("fakeexplorer").close()
      end,
    },
  },
}
providers.register(fake_provider)

provider, variant = providers.resolve("explorer", "auto")
T_eq("the installed plugin is picked", variant and variant.module, "fakeexplorer")

provider, variant = providers.resolve("explorer", "fake")
T_eq("a variant can be picked by name", variant and variant.module, "fakeexplorer")

workbench.setup({ session = { enabled = false }, providers = { explorer = "auto" } })
workbench.open()

T_check("the workbench opened", workbench.is_open())
T_check("the plugin was asked to open", vim.tbl_contains(calls, "open"), vim.inspect(calls))
T_check("the pane is served by the plugin", pane.variant("explorer") ~= nil)
T_eq(
  "the pane shows the plugin buffer",
  vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(pane.win("explorer")), 0, 1, false)[1],
  "from the fake plugin"
)

workbench.close()
T_check("the plugin was asked to close", vim.tbl_contains(calls, "close"), vim.inspect(calls))
T_check("the pane has no plugin any more", pane.variant("explorer") == nil)

vim.fn.delete(dir, "rf")
providers.invalidate()

T_finish("delegation")
