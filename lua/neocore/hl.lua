-- Highlight group registry.
-- Groups are registered by their full name so several plugins can share the
-- same core without fighting over namespace prefixes.

local palette = require("neocore.palette")

local M = {}

local registry = {}
local order = {}

--- True when the value is a palette key rather than a literal colour.
---@param value any
---@param pal table
---@return boolean
local function is_token(value, pal)
  if type(value) ~= "string" then
    return false
  end
  if value:sub(1, 1) == "#" then
    return false
  end
  if value == "NONE" or value == "none" then
    return false
  end
  return pal[value] ~= nil
end

--- True when the value is a colour Neovim understands.
---@param value any
---@return boolean
local function is_color(value)
  if type(value) == "number" then
    return true
  end
  if type(value) ~= "string" or value == "" then
    return false
  end
  if value == "NONE" or value == "none" then
    return true
  end
  if value:sub(1, 1) == "#" then
    return true
  end
  return vim.api.nvim_get_color_by_name(value) ~= nil
end

--- Resolve a colour value against a palette.
--- Unknown values resolve to nil so the attribute is left unset.
---@param value any
---@param pal table
---@return any
function M.resolve(value, pal)
  if is_token(value, pal) then
    return pal[value]
  end
  if value == nil then
    return nil
  end
  if not is_color(value) then
    return nil
  end
  return value
end

--- Register a highlight group.
--- Colours may be literal (`"#ff0000"`, `"NONE"`) or a palette key (`"accent"`).
---@param name string Full highlight group name.
---@param spec table
function M.define(name, spec)
  if registry[name] then
    return
  end
  registry[name] = spec or {}
  order[#order + 1] = name
end

--- Register several groups at once.
---@param groups table<string, table>
function M.define_all(groups)
  for name, spec in pairs(groups or {}) do
    M.define(name, spec)
  end
end

--- Remove every registered group.
function M.reset()
  registry = {}
  order = {}
end

--- The registered group names, in registration order.
---@return string[]
function M.registered()
  return vim.deepcopy(order)
end

--- The raw spec registered for a group.
---@param name string
---@return table?
function M.get(name)
  return registry[name]
end

--- Define a group straight away, bypassing the registry.
---@param name string
---@param spec table
function M.set(name, spec)
  vim.api.nvim_set_hl(0, name, spec)
end

--- Resolve and apply every registered group.
---@param pal table? Palette to resolve against, defaults to the `auto` palette.
---@return table palette The palette that was used.
function M.apply(pal)
  pal = pal or palette.auto_palette()
  for _, name in ipairs(order) do
    local spec = registry[name]
    if spec then
      local resolved = {}
      for key, value in pairs(spec) do
        if key == "fg" or key == "bg" or key == "sp" then
          resolved[key] = M.resolve(value, pal)
        else
          resolved[key] = value
        end
      end
      pcall(vim.api.nvim_set_hl, 0, name, resolved)
    end
  end
  return pal
end
return M
