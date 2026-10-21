local M = {}

function M.check()
  vim.health.start("neocore")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim version is supported.")
  else
    vim.health.error("Neovim 0.10 or newer is required.")
  end

  local scheme = vim.g.colors_name
  if scheme and scheme ~= "" then
    vim.health.ok("Colorscheme: " .. scheme)
  else
    vim.health.warn("No colorscheme is active, the auto palette falls back to built in colours.")
  end

  local ok, core = pcall(require, "neocore")
  if not ok then
    vim.health.error("Could not load neocore: " .. tostring(core))
    return
  end

  local colors = core.colors()
  vim.health.ok("Palette source: " .. tostring(core.get().theme))
  vim.health.info("Background: " .. tostring(colors.bg) .. "  Text: " .. tostring(colors.text))
  vim.health.info("Accent: " .. tostring(colors.accent) .. "  Border: " .. tostring(colors.border))

  local registered = core.hl.registered()
  vim.health.info("Registered highlight groups: " .. tostring(#registered))
end

return M
