-- neocore: the shared core of the neo plugin family.
--
-- It owns two things:
--   * a palette derived from the active colorscheme
--   * a registry of highlight groups that plugins can define by full name
--
-- The module has no dependencies outside of Neovim itself.

local palette = require("neocore.palette")
local hl = require("neocore.hl")
local util = require("neocore.util")
local win = require("neocore.win")

local M = {}

M.util = util
M.win = win
M.hl = hl

M.defaults = {
  theme = "auto",
  transparent = false,
}

M.options = vim.deepcopy(M.defaults)

local cache = nil
local augroup = nil

--- Configure the core.
---@param opts table? `theme` and `transparent`.
---@return table options
function M.setup(opts)
  M.options = util.merge(M.defaults, opts or {})
  cache = nil
  M.apply()
  return M.options
end

--- The active options.
---@return table
function M.get()
  return M.options
end

--- Drop the cached palette, forcing the next read to resample the colorscheme.
function M.invalidate()
  cache = nil
end

--- The resolved palette currently in use.
---@return table
function M.colors()
  if not cache then
    cache = palette.palette(M.options.theme, M.options.transparent)
  end
  return cache
end

--- The names of the built in palettes, `auto` first.
---@return string[]
function M.palette_names()
  return palette.names()
end

--- Resample the colorscheme and re-apply every registered highlight group.
---@return table palette
function M.apply()
  M.invalidate()
  local pal = M.colors()
  hl.apply(pal)
  return pal
end

--- Register a highlight group and apply it immediately.
---@param name string
---@param spec table
function M.define(name, spec)
  hl.define(name, spec)
  hl.apply(M.colors())
end

--- Re-apply the registered groups whenever the colorscheme changes.
--- Safe to call more than once.
function M.attach()
  if augroup and vim.api.nvim_get_autocmds({ group = augroup }).callback then
    return
  end
  augroup = vim.api.nvim_create_augroup("NeoCore", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    callback = function()
      M.apply()
    end,
  })
end

return M
