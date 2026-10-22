-- The panel pane, a bottom panel in the style of VS Code.
--
-- The panel is a bottom pane that shows one of several providers. The tabs at
-- the top of the pane switch between them, the way VS Code does it.
--
--   PROBLEMS  OUTPUT  TERMINAL  QUICKFIX
--   ─────────────────────────────────────
--   No problems
--
-- The keys are the ones of VS Code, adapted to the keyboard:
--
--   <leader>Wp    cycle the panel
--   <leader>Wt    the terminal
--   <leader>Wx    the problems
--   <leader>Wo    the output
--   <leader>Wq    the quickfix
--
-- The panel can be resized with the mouse or with the usual window commands.

local providers = require("neoworkbench.providers")

local M = {}

M.name = "panel"
M.title = "Panel"
M.icon = "󰅂"

--- The providers that can be shown in the panel, in the order of their tabs.
M.tabs = { "problems", "output", "terminal", "quickfix" }

--- The state of the panel.
M.state = {
  active = "problems",
}

--- The icon of a provider.
---@param name string
---@return string
local function provider_icon(name)
  local provider = providers.get(name)
  if provider and provider.icon then
    return provider.icon .. " "
  end
  return ""
end

--- The title of a provider.
---@param name string
---@return string
local function provider_title(name)
  local provider = providers.get(name)
  if provider and provider.title then
    return provider.title
  end
  return name:upper()
end

--- Build the tab bar of the panel.
---@param active string The active provider.
---@return table left, table right
local function tab_bar(active)
  local left = {}
  for _, name in ipairs(M.tabs) do
    local title = provider_title(name)
    local icon = provider_icon(name)
    if name == active then
      left[#left + 1] = { text = " " .. icon .. title .. " ", hl = "NeoworkbenchPanelActive" }
    else
      left[#left + 1] = { text = " " .. icon .. title .. " ", hl = "NeoworkbenchPanelInactive" }
    end
  end
  return left, nil
end

--- Render the tab bar into the winbar of the panel.
---@param winid integer
---@param active string
function M.set_tab_bar(winid, active)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  local left = tab_bar(active)
  -- A tab bar that is clickable.
  local parts = {}
  for i, seg in ipairs(left) do
    parts[#parts + 1] = "%#" .. seg.hl .. "#" .. seg.text .. "%*"
  end
  vim.wo[winid].winbar = table.concat(parts)
end

return M
