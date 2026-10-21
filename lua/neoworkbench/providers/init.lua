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

local available_cache = {}

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

--- True when a module can be found on the runtime path.
--- The module is not loaded, so a plugin stays lazy until it is really used.
---@param module string
---@return boolean
function M.available(module)
  if type(module) ~= "string" or module == "" then
    return false
  end
  if available_cache[module] ~= nil then
    return available_cache[module]
  end

  local base = module:gsub("%.", "/")
  local found = false
  for _, rtp in ipairs(vim.api.nvim_list_runtime_paths()) do
    local root = rtp .. "/lua"
    if
      vim.fn.filereadable(root .. "/" .. base .. ".lua") == 1
      or vim.fn.filereadable(root .. "/" .. base .. "/init.lua") == 1
    then
      found = true
      break
    end
  end

  available_cache[module] = found
  return found
end

--- Forget the cached lookups, the runtime path changed.
function M.invalidate()
  available_cache = {}
end

--- Resolve a pane to the provider and the variant that should serve it.
---
--- A variant is an alternative implementation of a provider, usually a third
--- party plugin. The choice is the name of the variant, `auto` picks the
--- first one that is installed and `builtin` forces the built in one.
---@param name string
---@param choice string?
---@return table? provider, table? variant
function M.resolve(name, choice)
  local provider = M.get(name)
  if not provider then
    return nil, nil
  end

  local variants = provider.variants or {}

  if type(choice) == "string" and choice ~= "" and choice ~= "auto" and choice ~= "builtin" then
    local variant = variants[choice]
    if variant and M.available(variant.module) then
      return provider, variant
    end
    return provider, nil
  end

  if choice == "auto" or choice == nil or choice == "" then
    for _, variant_name in ipairs(M.variant_names(provider.name)) do
      local variant = variants[variant_name]
      if variant and M.available(variant.module) then
        return provider, variant
      end
    end
  end

  return provider, nil
end

--- The names of the variants of a provider.
--- The variants are ordered by their priority, the highest one comes first.
---@param name string
---@return string[]
function M.variant_names(name)
  local provider = M.get(name)
  local names = {}
  for variant_name in pairs((provider and provider.variants) or {}) do
    names[#names + 1] = variant_name
  end
  table.sort(names, function(a, b)
    local pa = (provider.variants[a] and provider.variants[a].priority) or 0
    local pb = (provider.variants[b] and provider.variants[b].priority) or 0
    if pa ~= pb then
      return pa > pb
    end
    return a < b
  end)
  return names
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
--- A provider that was registered before keeps its place, so a user can
--- replace one of the built in ones.
function M.load_defaults()
  local defaults = {
    require("neoworkbench.providers.editor"),
    require("neoworkbench.providers.explorer"),
    require("neoworkbench.providers.problems"),
    require("neoworkbench.providers.quickfix"),
    require("neoworkbench.providers.output"),
    require("neoworkbench.providers.terminal"),
    require("neoworkbench.providers.outline"),
  }
  for _, provider in ipairs(defaults) do
    if not M.registry[provider.name] then
      M.register(provider)
    end
  end
end

return M
