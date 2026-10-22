-- neoworkbench: a declarative IDE layout for Neovim.
--
-- The workbench turns a layout tree into real windows, keeps the panes in
-- sync and gives the whole thing a colourscheme derived look.

local core = require("neocore")
local neowin = require("neocore.win")
local config = require("neoworkbench.config")
local spec = require("neoworkbench.spec")
local geometry = require("neoworkbench.geometry")
local focus = require("neoworkbench.focus")
local apply = require("neoworkbench.apply")
local pane = require("neoworkbench.pane")
local providers = require("neoworkbench.providers")
local session = require("neoworkbench.session")
local highlights = require("neoworkbench.highlights")

local M = {}

--- The active panel provider.
M.panel = nil

local augroup = nil

--- Whether the workbench was already opened by the startup.
local auto_opened = false

--- Open the workbench on startup.
--- A file on the command line wins, the workbench does not get in the way of
--- opening a file.
---@return boolean ok
function M.auto_open()
  if auto_opened then
    return false
  end
  if not config.get().auto_open then
    return false
  end
  if vim.fn.argc() > 0 then
    return false
  end
  auto_opened = true
  return M.open()
end

--- Configure the workbench.
---@param opts table?
---@return table options
function M.setup(opts)
  local options = config.setup(opts)

  core.setup({ theme = options.theme or "auto" })
  highlights.setup()
  core.attach()

  providers.load_defaults()

  M.panel = options.panel or "problems"
  M.create_commands()
  M.create_keymaps()
  M.create_autocmds()

  -- The editor may already be up when the plugin is loaded, a lazy plugin
  -- manager loads it when the VimEnter event fires.
  if options.auto_open and vim.v.vim_did_enter == 1 then
    vim.schedule(M.auto_open)
  end

  return options
end

--- The buffer of a provider, created once and reused.
---@param name string
---@param ctx table
---@return integer?
local function provider_buffer(name, ctx)
  local cached = pane.state.buffers and pane.state.buffers[name]
  if cached and vim.api.nvim_buf_is_valid(cached) then
    return cached
  end

  local provider = providers.get(name)
  if not provider then
    return nil
  end

  local bufnr = provider.buffer(ctx)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    pane.state.buffers = pane.state.buffers or {}
    pane.state.buffers[name] = bufnr
  end
  return bufnr
end

--- The buffer a pane should show.
---@param name string
---@param ctx table
---@return integer?
local function pane_buffer(name, ctx)
  if name == "panel" then
    return provider_buffer(M.panel, ctx)
  end
  return provider_buffer(name, ctx)
end

--- The title a pane shows.
---@param name string
---@return string, string?
local function pane_title(name)
  if name == "panel" then
    local provider = providers.get(M.panel)
    if provider then
      return provider.title, provider.icon
    end
    return "Panel", nil
  end
  local provider = providers.get(name)
  if provider then
    return provider.title, provider.icon
  end
  return name:upper(), nil
end

--- The buffer the editor pane should show.
---
--- The current buffer is preferred, but a buffer of a plugin or a scratch
--- buffer is skipped. The last file that was open is used instead, so opening
--- the workbench from a plugin keeps the file in the editor.
---@return integer bufnr
local function capture_buffer()
  local current = vim.api.nvim_get_current_buf()

  -- A normal buffer holds a file, a scratch buffer or a buffer of a plugin
  -- has a type of its own.
  local function is_normal(buf)
    if not vim.api.nvim_buf_is_loaded(buf) then
      return false
    end
    return vim.bo[buf].buftype == ""
  end

  if is_normal(current) then
    return current
  end

  local named = nil
  local unnamed = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_normal(buf) and vim.bo[buf].buflisted then
      if vim.api.nvim_buf_get_name(buf) ~= "" then
        named = buf
      else
        unnamed = buf
      end
    end
  end

  return named or unnamed or current
end

--- Open the workbench.
---@param layout_name string? The layout to open, defaults to the configured one.
---@return boolean ok
function M.open(layout_name)
  if pane.is_open() then
    return false
  end

  local options = config.get()
  local name = layout_name or options.layout

  local saved = nil
  if options.session and options.session.enabled and options.session.restore then
    saved = session.load()
    if saved and saved.layout and not layout_name then
      if config.layout_name(saved.layout) then
        name = saved.layout
      end
    end
  end

  local tree = spec.normalize_layout(config.layout_spec(name))
  if not tree then
    return false
  end

  local captured_buf = capture_buffer()
  local root_win = vim.api.nvim_get_current_win()

  -- A plugin may have been installed since the last time the workbench was
  -- opened, so the lookups are done again.
  providers.invalidate()

  -- The layout is built inside the current window, so it uses the size of
  -- that window and not the size of the whole grid.
  local cols = vim.api.nvim_win_get_width(root_win)
  local lines = vim.api.nvim_win_get_height(root_win)
  local rects = geometry.compute(tree, cols, lines)
  if #rects == 0 then
    return false
  end

  local scratch = vim.api.nvim_create_buf(false, true)
  local assignments = apply.build(tree, root_win, scratch)

  pane.reset()
  pane.state.open = true
  pane.state.layout = name
  pane.state.tree = tree
  pane.state.rects = rects
  pane.state.root_win = root_win
  pane.state.captured_buf = captured_buf

  local ctx = {
    cfg = options,
    captured_buf = captured_buf,
    panel = M.panel,
    core = core,
  }

  -- The editor pane takes over the buffer that was being edited.
  apply.handoff(assignments.editor, captured_buf, root_win)

  for pane_name, winid in pairs(assignments) do
    if neowin.is_valid(winid) then
      local provider_name = pane_name == "panel" and M.panel or pane_name
      local provider, variant = providers.resolve(provider_name, options.providers[provider_name])

      local bufnr
      if variant then
        -- A third party plugin takes over the window of the pane.
        pcall(variant.open, ctx, winid)
      else
        bufnr = pane_buffer(pane_name, ctx)
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
          pcall(vim.api.nvim_win_set_buf, winid, bufnr)
        end
        if provider and provider.attach then
          pcall(provider.attach, ctx, winid)
        end
      end

      if options.title then
        local title, icon = pane_title(pane_name)
        if title and title ~= "" then
          local left = { { text = " " .. (icon and (icon .. " ") or ""), hl = "NeoworkbenchAccent2" } }
          if title ~= "" then
            left[#left + 1] = { text = title, hl = "NeoworkbenchTitle" }
          end
          neowin.set_title(winid, left)
        end
      end

      pane.set(pane_name, winid, bufnr, variant)
    end
  end

  -- The editor is where the cursor belongs.
  local editor = pane.win("editor")
  if editor and neowin.is_valid(editor) then
    neowin.focus(editor)
  end

  M.refresh()
  return true
end

--- Close the workbench.
function M.close()
  if not pane.is_open() then
    return
  end

  local options = config.get()
  local editor_buf = pane.buf("editor")

  if options.session and options.session.enabled and options.session.autosave then
    session.save({
      layout = pane.state.layout,
      panel = M.panel,
      panes = pane.names(),
      buffers = pane.state.buffers or {},
    })
  end

  -- Give the windows back to the plugins that took them over.
  local ctx = {
    cfg = options,
    captured_buf = pane.state.captured_buf,
    panel = M.panel,
    core = core,
  }
  for _, name in ipairs(pane.names()) do
    local variant = pane.variant(name)
    if variant and variant.close then
      pcall(variant.close, ctx, pane.win(name))
    end
  end

  apply.close(editor_buf)
  pane.reset()
end

--- Open the workbench when it is closed, close it when it is open.
function M.toggle()
  if pane.is_open() then
    M.close()
  else
    M.open()
  end
end

--- True when the workbench is open.
---@return boolean
function M.is_open()
  return pane.is_open()
end

--- Switch to another layout, rebuilding the workbench.
---@param name string
---@return boolean ok
function M.set_layout(name)
  if not config.layout_name(name) then
    return false
  end
  local was_open = pane.is_open()
  if was_open then
    M.close()
  end
  config.get().layout = name
  if was_open then
    M.open(name)
  end
  return true
end

--- Focus a pane by name.
---@param name string
---@return boolean ok
function M.focus_pane(name)
  local winid = pane.win(name)
  if not winid then
    return false
  end
  return neowin.focus(winid)
end

--- Move the focus in a direction.
---@param direction string `left`, `right`, `up` or `down`.
---@return boolean ok
function M.move(direction)
  if not pane.is_open() then
    return false
  end

  local current_win = vim.api.nvim_get_current_win()
  local current_name = pane.pane_of(current_win)
  local current = current_name and geometry.by_pane(pane.state.rects, current_name) or nil
  if not current then
    return false
  end

  local target = focus.pick(pane.state.rects, current, direction)
  if not target then
    return false
  end

  local winid = pane.win(target.pane)
  if not winid then
    return false
  end
  return neowin.focus(winid)
end

--- Show a different provider in the panel pane.
---@param name string
---@return boolean ok
function M.set_panel(name)
  if not providers.get(name) then
    return false
  end

  M.panel = name
  local winid = pane.win("panel")
  if not winid then
    return true
  end

  local ctx = {
    cfg = config.get(),
    captured_buf = pane.state.captured_buf,
    panel = M.panel,
    core = core,
  }

  -- The panel that is replaced hands its window back first.
  local current = pane.variant("panel")
  if current and current.close then
    pcall(current.close, ctx, winid)
  end

  local options = config.get()
  local provider, variant = providers.resolve(name, options.providers[name])

  local bufnr
  if variant then
    pcall(variant.open, ctx, winid)
  else
    bufnr = provider_buffer(name, ctx)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_win_set_buf, winid, bufnr)
    end
  end
  pane.set("panel", winid, bufnr, variant)

  if config.get().title then
    local title, icon = pane_title("panel")
    neowin.set_title(winid, {
      { text = " " .. (icon and (icon .. " ") or ""), hl = "NeoworkbenchAccent2" },
      { text = title, hl = "NeoworkbenchTitle" },
    })
  end

  return true
end

--- Move to the next panel provider.
function M.cycle_panel()
  local options = config.get()
  local panels = options.panels or {}
  if #panels == 0 then
    return
  end
  local index = 1
  for i, name in ipairs(panels) do
    if name == M.panel then
      index = i
      break
    end
  end
  local next = panels[(index % #panels) + 1]
  M.set_panel(next)
end

--- Refresh the content of every pane.
function M.refresh()
  if not pane.is_open() then
    return
  end

  local ctx = {
    cfg = config.get(),
    captured_buf = pane.state.captured_buf,
    panel = M.panel,
    core = core,
  }

  for _, name in ipairs(pane.names()) do
    -- A pane that is served by a third party plugin refreshes itself.
    if not pane.variant(name) then
      local provider = providers.get(name == "panel" and M.panel or name)
      if provider and provider.render then
        local bufnr = pane.buf(name)
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
          pcall(provider.render, ctx, bufnr)
        end
      end
    end
  end
end

--- Recompute the layout and resize the panes.
function M.relayout()
  if not pane.is_open() then
    return
  end

  local tree = spec.normalize_layout(config.layout_spec(pane.state.layout))
  if not tree then
    return
  end

  -- The workbench lives in the area its panes cover, not in the grid, so the
  -- extent is measured from the panes.
  local cols, lines = apply.extent()
  if cols == 0 or lines == 0 then
    return
  end

  local rects = geometry.compute(tree, cols, lines)
  pane.state.tree = tree
  pane.state.rects = rects
  apply.resize(tree)
end

--- Create the user commands.
function M.create_commands()
  vim.api.nvim_create_user_command("Workbench", function()
    M.open()
  end, { desc = "Open the workbench" })

  vim.api.nvim_create_user_command("WorkbenchToggle", function()
    M.toggle()
  end, { desc = "Toggle the workbench" })

  vim.api.nvim_create_user_command("WorkbenchClose", function()
    M.close()
  end, { desc = "Close the workbench" })

  vim.api.nvim_create_user_command("WorkbenchLayout", function(args)
    if args.args ~= "" then
      M.set_layout(args.args)
      return
    end

    local names = config.layout_names()
    if #names == 0 then
      return
    end

    -- A numbered list and not a fuzzy finder, the number of the layout is
    -- typed. A picker that filters would swallow it.
    local ok, choice = pcall(vim.fn.inputlist, names)
    if not ok or choice == nil or choice == "" then
      return
    end

    -- The windows are rebuilt, that cannot happen while the prompt is still
    -- open, the switch waits for it to be gone.
    vim.schedule(function()
      M.set_layout(choice)
    end)
  end, {
    desc = "Switch the workbench layout",
    nargs = "?",
    complete = function()
      return config.layout_names()
    end,
  })

  vim.api.nvim_create_user_command("WorkbenchFocus", function(args)
    M.focus_pane(args.args)
  end, {
    desc = "Focus a workbench pane",
    nargs = 1,
    complete = function()
      return { "editor", "explorer", "panel", "outline" }
    end,
  })

  vim.api.nvim_create_user_command("WorkbenchPanel", function(args)
    if args.args ~= "" then
      M.set_panel(args.args)
    else
      M.cycle_panel()
    end
  end, {
    desc = "Change the panel provider",
    nargs = "?",
    complete = function()
      return providers.names()
    end,
  })

  vim.api.nvim_create_user_command("WorkbenchRefresh", function()
    M.refresh()
  end, { desc = "Refresh the workbench panes" })

  vim.api.nvim_create_user_command("WorkbenchSave", function()
    session.save({
      layout = pane.state.layout,
      panel = M.panel,
      panes = pane.names(),
      buffers = pane.state.buffers or {},
    })
  end, { desc = "Save the workbench session" })
end

--- Create the keymaps.
--- Set `keys` to `false` in the options to keep the keymaps out of the way,
--- which is what a lazy plugin manager needs when it defines them itself.
function M.create_keymaps()
  local keys = config.get().keys
  if keys == false then
    return
  end
  if type(keys) ~= "table" then
    return
  end

  local function map(lhs, fn, desc)
    if type(lhs) ~= "string" or lhs == "" then
      return
    end
    vim.keymap.set("n", lhs, fn, { desc = desc })
  end

  map(keys.toggle, function()
    M.toggle()
  end, "Toggle the workbench")

  map(keys.focus_left, function()
    M.move("left")
  end, "Workbench focus left")
  map(keys.focus_down, function()
    M.move("down")
  end, "Workbench focus down")
  map(keys.focus_up, function()
    M.move("up")
  end, "Workbench focus up")
  map(keys.focus_right, function()
    M.move("right")
  end, "Workbench focus right")

  map(keys.panel, function()
    M.cycle_panel()
  end, "Cycle the workbench panel")
  map(keys.explorer, function()
    M.focus_pane("explorer")
  end, "Focus the explorer")
  map(keys.terminal, function()
    M.set_panel("terminal")
  end, "Open the terminal panel")
  map(keys.problems, function()
    M.set_panel("problems")
  end, "Open the problems panel")
  map(keys.layout, function()
    vim.cmd("WorkbenchLayout")
  end, "Change the workbench layout")
  map(keys.save, function()
    vim.cmd("WorkbenchSave")
  end, "Save the workbench session")
  map(keys.close, function()
    M.close()
  end, "Close the workbench")
end

--- Create the autocommands.
function M.create_autocmds()
  if augroup then
    vim.api.nvim_del_augroup_by_id(augroup)
  end
  augroup = vim.api.nvim_create_augroup("Neoworkbench", { clear = true })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = augroup,
    callback = function()
      M.auto_open()
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
      M.relayout()
    end,
  })

  vim.api.nvim_create_autocmd({ "DiagnosticChanged", "QuickFixCmdPost" }, {
    group = augroup,
    callback = function()
      M.refresh()
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function()
      if pane.is_open() then
        M.refresh()
      end
    end,
  })
end

return M
