-- Directional focus movement.
-- Pure geometry, the editor is never touched from here.

local geometry = require("neoworkbench.geometry")

local M = {}

M.directions = { "left", "right", "up", "down" }

--- True when a score beats another one.
---@param a number[]
---@param b number[]
---@return boolean
local function better(a, b)
  if a[1] ~= b[1] then
    return a[1] < b[1]
  end
  return a[2] < b[2]
end

--- True when two rectangles overlap on the axis perpendicular to the movement.
---@param rect table
---@param current table
---@param direction string
---@return boolean
local function overlaps(rect, current, direction)
  if direction == "left" or direction == "right" then
    return rect.y < current.y + current.h and current.y < rect.y + rect.h
  end
  return rect.x < current.x + current.w and current.x < rect.x + rect.w
end

--- Pick the pane that should be focused when moving in a direction.
--- Candidates that overlap on the perpendicular axis are preferred, the
--- closest one wins.
---@param rects table[]
---@param current table
---@param direction string
---@return table? rect
function M.pick(rects, current, direction)
  if not current or not M.directions or not vim.tbl_contains(M.directions, direction) then
    return nil
  end

  local cx, cy = geometry.center(current)
  local best, best_score
  local fallback, fallback_score

  for _, rect in ipairs(rects or {}) do
    if rect ~= current then
      local rx, ry = geometry.center(rect)
      local along, perp, ahead

      if direction == "right" then
        along = rect.x - (current.x + current.w)
        perp = math.abs(ry - cy)
        ahead = along >= 0
      elseif direction == "left" then
        along = current.x - (rect.x + rect.w)
        perp = math.abs(ry - cy)
        ahead = along >= 0
      elseif direction == "down" then
        along = rect.y - (current.y + current.h)
        perp = math.abs(rx - cx)
        ahead = along >= 0
      else
        along = current.y - (rect.y + rect.h)
        perp = math.abs(rx - cx)
        ahead = along >= 0
      end

      if ahead then
        local score = { along, perp }
        if not fallback or better(score, fallback_score) then
          fallback, fallback_score = rect, score
        end
        if overlaps(rect, current, direction) and (not best or better(score, best_score)) then
          best, best_score = rect, score
        end
      end
    end
  end

  return best or fallback
end

--- The pane that comes after the given one in a direction, wrapping around.
---@param rects table[]
---@param current table
---@param direction string
---@return table? rect
function M.cycle(rects, current, direction)
  local picked = M.pick(rects, current, direction)
  if picked then
    return picked
  end
  -- Nothing in that direction, wrap to the opposite side.
  local opposite = {
    left = "right",
    right = "left",
    up = "down",
    down = "up",
  }
  return M.pick(rects, current, opposite[direction] or direction)
end

return M
