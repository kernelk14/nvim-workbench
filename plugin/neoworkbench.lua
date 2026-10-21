-- Entry point for the workbench.
-- The commands are created here so they work even when the plugin is installed
-- without a plugin manager.

if vim.g.loaded_neoworkbench then
  return
end
vim.g.loaded_neoworkbench = true

if vim.fn.has("nvim-0.10") == 1 then
  local ok, workbench = pcall(require, "neoworkbench")
  if ok then
    workbench.create_commands()
  end
end
