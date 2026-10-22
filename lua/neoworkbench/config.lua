-- Workbench configuration.

local util = require("neocore.util")

local M = {}

--- The default layout presets.
--- A node is one of:
---   { type = "leaf", pane = "<name>", size = <number>, options = {} }
---   { type = "row"|"col", children = { ... } }
--- Sizes with a fractional part are a fraction of the parent, integers are an
--- absolute number of cells.
M.presets = {
  default = {
    type = "col",
    children = {
      {
        type = "row",
        size = 0.7,
        children = {
          { type = "leaf", pane = "explorer", size = 0.25 },
          { type = "leaf", pane = "editor", size = 0.75 },
        },
      },
      { type = "leaf", pane = "panel", size = 0.3 },
    },
  },
  focus = {
    type = "leaf",
    pane = "editor",
  },
  ide = {
    type = "col",
    children = {
      {
        type = "row",
        size = 0.7,
        children = {
          { type = "leaf", pane = "explorer", size = 0.2 },
          { type = "leaf", pane = "editor", size = 0.6 },
          { type = "leaf", pane = "outline", size = 0.2 },
        },
      },
      { type = "leaf", pane = "panel", size = 0.3 },
    },
  },
}

M.defaults = {
  -- The layout preset that is used when the workbench opens.
  layout = "default",

  -- Extra layouts, merged over the built in presets.
  layouts = {},

  -- Draw a title bar on every pane.
  title = true,

  -- Automatically open the workbench on startup.
  auto_open = false,

  -- The panel providers that can be shown in the panel, in the order of
  -- their tabs.
  panels = { "problems", "output", "terminal", "quickfix" },

  -- The provider used for the bottom pane when the workbench opens.
  panel = "problems",

  -- Which implementation to use for each pane. `auto` prefers an installed
  -- plugin and falls back to the built in one, `builtin` forces the built in
  -- one and the name of a variant picks that one.
  providers = {
    explorer = "auto",
    terminal = "auto",
    problems = "auto",
    outline = "auto",
  },

  session = {
    enabled = true,
    autosave = true,
    restore = true,
  },

  keys = {
    toggle = "<leader>W",
    focus_left = "<leader>Wh",
    focus_down = "<leader>Wj",
    focus_up = "<leader>Wk",
    focus_right = "<leader>Wl",
    panel = "<leader>Wp",
    explorer = "<leader>Wi",
    terminal = "<leader>Wt",
    problems = "<leader>Wx",
    output = "<leader>Wo",
    quickfix = "<leader>Wq",
    layout = "<leader>WL",
    save = "<leader>Ws",
    close = "<leader>Wc",
  },
}

M.options = vim.deepcopy(M.defaults)

--- Configure the workbench.
---@param opts table?
---@return table options
function M.setup(opts)
  M.options = util.merge(M.defaults, opts or {})
  return M.options
end

--- The active options.
---@return table
function M.get()
  return M.options
end

--- The name of a layout preset, either built in or user defined.
---@param name string?
---@return string?
function M.layout_name(name)
  name = name or M.options.layout
  if M.options.layouts[name] then
    return name
  end
  if M.presets[name] then
    return name
  end
  return nil
end

--- The raw layout spec of a preset.
---@param name string?
---@return table?
function M.layout_spec(name)
  name = M.layout_name(name)
  if not name then
    return nil
  end
  return M.options.layouts[name] or M.presets[name]
end

--- The list of available layout names.
---@return string[]
function M.layout_names()
  local names = {}
  for name in pairs(M.presets) do
    names[#names + 1] = name
  end
  for name in pairs(M.options.layouts or {}) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

return M
