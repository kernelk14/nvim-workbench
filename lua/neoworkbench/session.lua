-- Per project sessions.
--
-- The workbench remembers which layout was used, which panes were visible and
-- which panel was open, so reopening a project feels the same.

local M = {}

--- A stable hash of a string, used to name the session file.
---@param text string
---@return string
function M.hash(text)
  local ok, digest = pcall(vim.fn.sha256, text)
  if ok and type(digest) == "string" and #digest >= 12 then
    return digest:sub(1, 12)
  end
  -- Fall back to a simple checksum when sha256 is unavailable.
  local sum = 0
  for i = 1, #text do
    sum = (sum * 31 + text:byte(i)) % 4294967296
  end
  return string.format("%08x", sum)
end

--- The root of the project the editor is in.
---@return string
function M.root()
  local explorer = require("neoworkbench.providers.explorer")
  return explorer.root_of(vim.fn.getcwd())
end

--- The directory the sessions are stored in.
---@return string
function M.dir()
  return vim.fn.stdpath("data") .. "/neoworkbench/sessions"
end

--- The file a project session is stored in.
---@param root string?
---@return string
function M.path(root)
  root = root or M.root()
  return M.dir() .. "/" .. M.hash(root) .. ".json"
end

--- Encode a table as json.
---@param value any
---@return string
local function encode(value)
  if vim.json and vim.json.encode then
    return vim.json.encode(value)
  end
  return vim.fn.json_encode(value)
end

--- Decode a json string.
---@param text string
---@return any
local function decode(text)
  if vim.json and vim.json.decode then
    return vim.json.decode(text)
  end
  return vim.fn.json_decode(text)
end

--- Save the state of the workbench.
---@param state table
---@param root string?
---@return boolean ok
function M.save(state, root)
  local ok, err = pcall(function()
    local dir = M.dir()
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
    local payload = {
      root = root or M.root(),
      layout = state.layout,
      panel = state.panel,
      panes = state.panes or {},
      buffers = state.buffers or {},
    }
    local file = io.open(M.path(root), "w")
    if not file then
      error("could not open the session file")
    end
    file:write(encode(payload))
    file:close()
  end)
  if not ok then
    require("neoworkbench.providers.output").log("Could not save the session: " .. tostring(err))
  end
  return ok
end

--- Load the state of a project.
---@param root string?
---@return table?
function M.load(root)
  local file = io.open(M.path(root), "r")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()

  local ok, decoded = pcall(decode, text)
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

--- Remove the session of a project.
---@param root string?
---@return boolean ok
function M.clear(root)
  local path = M.path(root)
  if vim.fn.filereadable(path) == 0 then
    return false
  end
  return os.remove(path) ~= nil
end

return M
