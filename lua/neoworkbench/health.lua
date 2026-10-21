local M = {}

function M.check()
  vim.health.start("neoworkbench")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim version is supported.")
  else
    vim.health.error("Neovim 0.10 or newer is required.")
  end

  local ok, workbench = pcall(require, "neoworkbench")
  if not ok then
    vim.health.error("Could not load neoworkbench: " .. tostring(workbench))
    return
  end

  local config = require("neoworkbench.config")
  local providers = require("neoworkbench.providers")
  local pane = require("neoworkbench.pane")

  local layout = config.get().layout
  if config.layout_name(layout) then
    vim.health.ok("Layout: " .. layout)
  else
    vim.health.error("The layout " .. tostring(layout) .. " does not exist.")
  end

  vim.health.info("Available layouts: " .. table.concat(config.layout_names(), ", "))
  vim.health.info("Available providers: " .. table.concat(providers.names(), ", "))

  if pane.is_open() then
    vim.health.ok("The workbench is open.")
    for _, name in ipairs(pane.names()) do
      local winid = pane.win(name)
      local width = winid and vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_width(winid) or 0
      vim.health.info(string.format("  %s, %d columns", name, width))
    end
  else
    vim.health.info("The workbench is closed.")
  end

  local session = require("neoworkbench.session")
  if vim.fn.isdirectory(session.dir()) == 1 then
    vim.health.ok("Sessions are stored in " .. session.dir())
  else
    vim.health.info("No session has been saved yet.")
  end
end

return M
