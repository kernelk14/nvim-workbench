-- Exercise every workbench function in the real configuration.
local failures = 0
local checks = 0

local function check(name, ok, extra)
  checks = checks + 1
  if ok then
    print("ok   - " .. name)
  else
    failures = failures + 1
    print("FAIL - " .. name .. (extra and ("  (" .. tostring(extra) .. ")") or ""))
  end
end

local workbench = require("neoworkbench")
local pane = require("neoworkbench.pane")

print("--- the keymaps ---")

local function has_map(lhs)
  for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
    if map.lhs == lhs then
      return true
    end
  end
  return false
end

for _, lhs in ipairs({ " W", " Wh", " Wj", " Wk", " Wl", " Wi", " Wp", " Wt", " Wx", " WL", " Ws", " Wq" }) do
  check("the keymap " .. lhs .. " exists", has_map(lhs))
end

print("--- the commands ---")
for _, name in ipairs({
  "Workbench",
  "WorkbenchToggle",
  "WorkbenchClose",
  "WorkbenchLayout",
  "WorkbenchFocus",
  "WorkbenchPanel",
  "WorkbenchRefresh",
  "WorkbenchSave",
}) do
  check("the command " .. name .. " exists", vim.fn.exists(":" .. name) == 2)
end

print("--- opening and closing ---")

workbench.close()
check("the workbench starts closed", not workbench.is_open())
check("open returns true", workbench.open() == true)
check("the workbench is open", workbench.is_open())
check("opening twice does nothing", workbench.open() == false)
check("the editor pane exists", pane.win("editor") ~= nil)
check("the explorer pane exists", pane.win("explorer") ~= nil)
check("the panel pane exists", pane.win("panel") ~= nil)
check("three windows", #vim.api.nvim_tabpage_list_wins(0) == 3, #vim.api.nvim_tabpage_list_wins(0))

print("--- the focus movement ---")

local function focus_of()
  return pane.pane_of(vim.api.nvim_get_current_win())
end

workbench.focus_pane("editor")
check("focus_pane editor", focus_of() == "editor", focus_of())
workbench.focus_pane("explorer")
check("focus_pane explorer", focus_of() == "explorer", focus_of())
workbench.focus_pane("panel")
check("focus_pane panel", focus_of() == "panel", focus_of())

workbench.focus_pane("editor")
check("move right from the editor does nothing", workbench.move("right") == false)
check("move left reaches the explorer", workbench.move("left") == true and focus_of() == "explorer", focus_of())
check("move right reaches the editor", workbench.move("right") == true and focus_of() == "editor", focus_of())
check("move down reaches the panel", workbench.move("down") == true and focus_of() == "panel", focus_of())
check("move up reaches the editor", workbench.move("up") == true and focus_of() == "editor", focus_of())

print("--- the panels ---")

workbench.set_panel("problems")
check("the problems panel", vim.bo[pane.buf("panel")].filetype == "neoworkbench-problems", vim.bo[pane.buf("panel")].filetype)
workbench.set_panel("quickfix")
check("the quickfix panel", vim.bo[pane.buf("panel")].filetype == "neoworkbench-quickfix", vim.bo[pane.buf("panel")].filetype)
workbench.set_panel("output")
check("the output panel", vim.bo[pane.buf("panel")].filetype == "neoworkbench-output", vim.bo[pane.buf("panel")].filetype)
check("an unknown panel is rejected", workbench.set_panel("nope") == false)

print("--- the terminal panel ---")

local editor_win = pane.win("editor")
workbench.focus_pane("editor")
workbench.set_panel("terminal")
check("the editor window survives", vim.api.nvim_win_is_valid(editor_win), editor_win)
check("the editor keeps its pane", pane.win("editor") == editor_win)
check("the terminal is in the panel", vim.bo[pane.buf("panel")].buftype == "terminal", vim.bo[pane.buf("panel")].buftype)
check("the editor is not a terminal", vim.bo[vim.api.nvim_win_get_buf(editor_win)].buftype == "")
check("the windows are still three", #vim.api.nvim_tabpage_list_wins(0) == 3)
workbench.set_panel("problems")

print("--- the explorer ---")

local explorer_buf = pane.buf("explorer")
local lines = vim.api.nvim_buf_get_lines(explorer_buf, 0, -1, false)
check("the explorer has content", #lines > 3, #lines)
check("the explorer shows the directory", (table.concat(lines, "\n")):find("lua", 1, true) ~= nil)

local function explorer_map(lhs)
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(explorer_buf, "n")) do
    if map.lhs == lhs then
      return map
    end
  end
end

for _, lhs in ipairs({ "<CR>", "<Tab>", "r", "q" }) do
  check("the explorer has the keymap " .. lhs, explorer_map(lhs) ~= nil)
end

print("--- the editor pane ---")

local file = vim.fn.tempname() .. ".txt"
vim.fn.writefile({ "hello" }, file)
local new_buf = vim.fn.bufadd(file)
vim.fn.bufload(new_buf)
vim.api.nvim_win_set_buf(pane.win("editor"), new_buf)
check("the editor shows the file", vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(pane.win("editor"))) == vim.fn.fnamemodify(file, ":p"))

print("--- refreshing and relayout ---")

check("refresh works", workbench.refresh() == nil)
check("relayout works", workbench.relayout() == nil)
check("the panes survive a relayout", pane.win("editor") ~= nil and pane.win("explorer") ~= nil)

print("--- the layout switch ---")

workbench.set_layout("focus")
check("the focus layout has one pane", #pane.names() == 1, table.concat(pane.names(), ","))
check("the editor is still there", pane.win("editor") ~= nil)
workbench.set_layout("default")
check("the default layout comes back", pane.win("explorer") ~= nil)

print("--- the session ---")

check("the session is saved", workbench.set_layout("default") ~= false)
vim.cmd("WorkbenchSave")
local session = require("neoworkbench.session")
local saved = session.load()
check("the session was written", saved ~= nil and saved.layout ~= nil, vim.inspect(saved))

print("--- closing ---")

local root_win = pane.state.root_win
workbench.close()
check("the workbench closed", not workbench.is_open())
check("one window is left", #vim.api.nvim_tabpage_list_wins(0) == 1)
check("the editor buffer survives", vim.api.nvim_get_current_buf() == new_buf)
check("the window is the original one", vim.api.nvim_get_current_win() == root_win, vim.api.nvim_get_current_win() .. " vs " .. tostring(root_win))

print(string.format("\n%d checks, %d failures", checks, failures))
if failures > 0 then
  vim.cmd("cquit 1")
end
