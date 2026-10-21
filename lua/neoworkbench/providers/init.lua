-- Provider registry.
--
-- A provider owns the content of a pane. Every provider exposes
--
--   name    the pane it serves
--   title   the title shown in the pane bar
--   icon    an optional nerd font glyph
--   buffer  returns the buffer the pane should show
--   attach  called once the window exists, may adjust window options
--   render  called when the buffer needs fresh content
--
-- Users can replace any provider with their own table, which is how the
-- workbench can be wired to a third party plugin.

local M = {}

M.registry = {}

--- Register a provider.
---@param provider table
function M.register(provider)
  if type(provider) ~= "table" or type(provider.name) ~= "string" then
    return
  end
  M.registry[provider.name] = provider
end

--- A provider by name.
---@param name string
---@return table?
function M.get(name)
  return M.registry[name]
end

--- The names of every registered provider.
---@return string[]
function M.names()
  local names = {}
  for name in pairs(M.registry) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

--- Create a scratch buffer for a pane.
---@param name string
---@param filetype string?
---@return integer
function M.scratch(name, filetype)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  if filetype then
    vim.bo[bufnr].filetype = filetype
  end
  pcall(vim.api.nvim_buf_set_name, bufnr, "neoworkbench://" .. name)
  return bufnr
end

--- Write lines into a buffer.
---@param bufnr integer
---@param lines string[]
function M.set_lines(bufnr, lines)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
end

--- Load the built in providers.
function M.load_defaults()
  M.register(require("neoworkbench.providers.editor"))
  M.register(require("neoworkbench.providers.explorer"))
  M.register(require("neoworkbench.providers.problems"))
  M.register(require("neoworkbench.providers.quickfix"))
  M.register(require("neoworkbench.providers.output"))
  M.register(require("neoworkbench.providers.terminal"))
  M.register(require("neoworkbench.providers.outline"))
end

return M
