-- Text, colour and table helpers shared by the neo plugins.
-- Pure functions, no state, no side effects.

local M = {}

--- Display width of a string, accounting for wide and combining characters.
---@param text string?
---@return integer
function M.swidth(text)
  return vim.fn.strdisplaywidth(text or "")
end

--- Truncate a string to a display width, appending an ellipsis when cut.
---@param text string?
---@param width integer
---@return string
function M.truncate(text, width)
  text = text or ""
  if width <= 0 then
    return ""
  end
  if M.swidth(text) <= width then
    return text
  end
  local ellipsis = "…"
  local budget = width - M.swidth(ellipsis)
  if budget <= 0 then
    return ellipsis
  end
  local chars = vim.fn.strchars(text)
  local out = {}
  local used = 0
  for i = 0, chars - 1 do
    local ch = vim.fn.strcharpart(text, i, 1)
    local w = M.swidth(ch)
    if used + w > budget then
      break
    end
    out[#out + 1] = ch
    used = used + w
  end
  return table.concat(out) .. ellipsis
end

--- Normalise a value into a list of segments.
--- Accepts a string, a single segment table, or a list of segments.
---@param value any
---@return table
function M.norm_segs(value)
  if value == nil then
    return {}
  end
  if type(value) == "string" then
    return { { text = value } }
  end
  if value.text ~= nil then
    return { value }
  end
  return value
end

--- Total display width of a list of segments.
---@param segs table?
---@return integer
function M.segs_width(segs)
  local width = 0
  for _, seg in ipairs(segs or {}) do
    width = width + M.swidth(seg.text or "")
  end
  return width
end

--- Total byte length of a list of segments.
---@param segs table?
---@return integer
function M.segs_bytes(segs)
  local bytes = 0
  for _, seg in ipairs(segs or {}) do
    bytes = bytes + #(seg.text or "")
  end
  return bytes
end

--- Clip a list of segments to a display width, truncating the last one.
---@param segs table?
---@param width integer
---@return table
function M.clip_segs(segs, width)
  local out = {}
  local used = 0
  for _, seg in ipairs(segs or {}) do
    if used >= width then
      break
    end
    local w = M.swidth(seg.text or "")
    if used + w <= width then
      out[#out + 1] = seg
      used = used + w
    else
      local text = M.truncate(seg.text or "", width - used)
      if text ~= "" then
        out[#out + 1] = { text = text, hl = seg.hl }
      end
      used = width
    end
  end
  return out
end

--- Build a row that pins `left` to the start and `right` to the end.
---@param left any
---@param right any
---@param width integer
---@param opts table? `clip = "right"` clips the right side first.
---@return table
function M.row(left, right, width, opts)
  opts = opts or {}
  local l = M.norm_segs(left)
  local r = M.norm_segs(right)
  local lw = M.segs_width(l)
  local rw = M.segs_width(r)
  local gap = width - lw - rw
  if gap < 1 then
    if opts.clip == "right" then
      r = M.clip_segs(r, math.max(0, rw + gap - 1))
      rw = M.segs_width(r)
      gap = width - lw - rw
      if gap < 1 then
        l = M.clip_segs(l, math.max(0, lw + gap - 1))
        lw = M.segs_width(l)
        gap = width - lw - rw
      end
    else
      l = M.clip_segs(l, math.max(0, lw + gap - 1))
      lw = M.segs_width(l)
      gap = width - lw - rw
      if gap < 0 then
        r = M.clip_segs(r, math.max(0, rw + gap))
        rw = M.segs_width(r)
        gap = width - lw - rw
      end
    end
  end
  local segs = {}
  for _, seg in ipairs(l) do
    segs[#segs + 1] = seg
  end
  if gap > 0 then
    segs[#segs + 1] = { text = string.rep(" ", gap) }
  end
  for _, seg in ipairs(r) do
    segs[#segs + 1] = seg
  end
  return segs
end

--- Centre a list of segments inside a width.
---@param segs table?
---@param width integer
---@return table
function M.center(segs, width)
  local used = M.segs_width(segs)
  local left = math.max(0, math.floor((width - used) / 2))
  local out = { { text = string.rep(" ", left) } }
  for _, seg in ipairs(segs or {}) do
    out[#out + 1] = seg
  end
  return out
end

--- Parse a hex colour into its r, g and b components.
---@param hex string
---@return integer, integer, integer
function M.parse_hex(hex)
  hex = tostring(hex):gsub("#", "")
  if #hex == 3 then
    hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
  end
  return tonumber(hex:sub(1, 2), 16) or 0, tonumber(hex:sub(3, 4), 16) or 0, tonumber(hex:sub(5, 6), 16) or 0
end

--- Format r, g and b components as a hex colour.
---@param color integer[]
---@return string
function M.fmt_hex(color)
  return string.format(
    "#%02x%02x%02x",
    math.floor(color[1] + 0.5),
    math.floor(color[2] + 0.5),
    math.floor(color[3] + 0.5)
  )
end

--- Blend two colours, `ratio` being the weight of `to`.
---@param from string
---@param to string
---@param ratio number
---@return string
function M.blend(from, to, ratio)
  local r1, g1, b1 = M.parse_hex(from)
  local r2, g2, b2 = M.parse_hex(to)
  return M.fmt_hex({
    r1 + (r2 - r1) * ratio,
    g1 + (g2 - g1) * ratio,
    b1 + (b2 - b1) * ratio,
  })
end

--- Sample a gradient of colour stops at a ratio between 0 and 1.
---@param stops string[]
---@param ratio number
---@return string
function M.mix(stops, ratio)
  if #stops == 0 then
    return "#000000"
  end
  if #stops == 1 then
    return stops[1]
  end
  local segments = #stops - 1
  local pos = math.max(0, math.min(1, ratio)) * segments
  if pos <= 0 then
    return stops[1]
  end
  if pos >= segments then
    return stops[#stops]
  end
  local index = math.floor(pos) + 1
  local frac = pos - (index - 1)
  return M.blend(stops[index], stops[index + 1], frac)
end

--- True when the table is a non empty list.
---@param value any
---@return boolean
function M.is_list(value)
  if type(value) ~= "table" then
    return false
  end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" then
      return false
    end
    count = count + 1
  end
  return count > 0
end

--- Deep merge two tables, `override` winning. Lists are replaced, not merged.
---@param base table
---@param override table?
---@return table
function M.merge(base, override)
  local out = {}
  for key, value in pairs(base) do
    out[key] = type(value) == "table" and vim.deepcopy(value) or value
  end
  for key, value in pairs(override or {}) do
    if type(value) == "table" and type(out[key]) == "table" and not M.is_list(value) and not M.is_list(out[key]) then
      out[key] = M.merge(out[key], value)
    else
      out[key] = type(value) == "table" and vim.deepcopy(value) or value
    end
  end
  return out
end

--- Clamp a number into a range.
---@param value number
---@param min number
---@param max number
---@return number
function M.clamp(value, min, max)
  if value < min then
    return min
  end
  if value > max then
    return max
  end
  return value
end

--- Divide and round, guaranteeing the parts sum to `total`.
--- Used to split a parent size across children without losing a single cell.
---@param total integer
---@param weights number[]
---@return integer[]
function M.distribute(total, weights)
  local count = #weights
  if count == 0 then
    return {}
  end
  local sum = 0
  for _, weight in ipairs(weights) do
    sum = sum + weight
  end
  if sum <= 0 then
    local even = math.floor(total / count)
    local sizes = {}
    local left = total
    for i = 1, count do
      local size = i == count and left or even
      sizes[i] = size
      left = left - size
    end
    return sizes
  end

  local sizes = {}
  local assigned = 0
  for i = 1, count do
    local size = math.floor(total * (weights[i] / sum))
    sizes[i] = size
    assigned = assigned + size
  end

  -- Hand the rounding remainder to the largest child, then to the first ones.
  local leftover = total - assigned
  if leftover > 0 then
    local best = 1
    for i = 2, count do
      if sizes[i] > sizes[best] then
        best = i
      end
    end
    sizes[best] = sizes[best] + leftover
  end

  return sizes
end

return M
