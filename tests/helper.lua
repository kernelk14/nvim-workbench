-- Shared bootstrap and assertions for the test suites.
-- Each test file starts with:
--
--   local root = vim.fn.getcwd()
--   package.path = table.concat({
--     root .. "/lua/?.lua",
--     root .. "/lua/?/init.lua",
--     root .. "/?.lua",
--     package.path,
--   }, ";")
--   vim.opt.rtp:append(root)
--   local t = require("tests.helper")

local M = {}

M.failures = 0
M.checks = 0

--- Print a section header.
---@param name string
function M.group(name)
  print("\n-- " .. name)
end

--- Assert a condition.
---@param name string
---@param ok any
---@param extra any? Extra context printed on failure.
function M.check(name, ok, extra)
  M.checks = M.checks + 1
  if ok then
    print("ok   - " .. name)
  else
    M.failures = M.failures + 1
    print("FAIL - " .. name .. (extra and ("  (" .. tostring(extra) .. ")") or ""))
  end
end

--- Assert that two values are deeply equal.
---@param name string
---@param got any
---@param want any
function T_eq(name, got, want)
  local same = vim.deep_equal(got, want)
  T_check(name, same, same and nil or ("got " .. vim.inspect(got) .. ", want " .. vim.inspect(want)))
end

--- Assert that two numbers are within a tolerance.
---@param name string
---@param got number
---@param want number
---@param tolerance number?
function T_approx(name, got, want, tolerance)
  tolerance = tolerance or 1e-6
  local ok = type(got) == "number" and math.abs(got - want) <= tolerance
  T_check(name, ok, ok and nil or ("got " .. tostring(got) .. ", want " .. tostring(want)))
end

--- Print the summary and exit with a non zero status when something failed.
---@param label string?
function T_finish(label)
  print(string.format("\n%d checks, %d failures", M.checks, M.failures))
  if M.failures > 0 then
    vim.cmd("cquit 1")
  end
  if label then
    print(label .. " ok")
  end
end

-- The assert helpers are globals inside the test files, they are exposed here
-- so every suite shares the exact same implementation.
_G.T_check = M.check
_G.T_eq = T_eq
_G.T_approx = T_approx
_G.T_finish = T_finish
_G.T_group = M.group
_G.T_failures = function()
  return M.failures
end

return M
