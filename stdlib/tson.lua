local Tson = {}
Tson.__name = "Tson"
Tson.__class = Tson
Tson.__fields = {}
Tson.__methods = { __static = {} }

Tson.__fields.sort = {
  NONE = 0,
  ALPHABETICAL = 1,
  REVERSE_ALPHABETICAL = 2,
}

local function escape_string(s)
  return s
    :gsub("\\", "\\\\")
    :gsub('"', '\\"')
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t")
end

local function is_array(t)
  local max = 0
  local count = 0

  for k, _ in pairs(t) do
    if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
      return false
    end
    count = count + 1
    if k > max then max = k end
  end

  return count == max
end

local function sorted_keys(t, mode)
  local keys = {}

  for k, _ in pairs(t) do
    keys[#keys + 1] = k
  end

  if mode == Tson.__fields.sort.ALPHABETICAL then
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  elseif mode == Tson.__fields.sort.REVERSE_ALPHABETICAL then
    table.sort(keys, function(a, b) return tostring(a) > tostring(b) end)
  end

  return keys
end

local function stringify(value, sort_mode)
  local t = type(value)

  if t == "table" then

    -- ARRAY
    if is_array(value) then
      local parts = {}

      for i = 1, #value do
        parts[#parts + 1] = stringify(value[i], sort_mode)
      end

      return "[ " .. table.concat(parts, ", ") .. " ]"
    end

    -- OBJECT
    local parts = {}

    for _, k in ipairs(sorted_keys(value, sort_mode)) do
      local key = stringify(tostring(k), sort_mode)
      local val = stringify(value[k], sort_mode)
      parts[#parts + 1] = key .. ": " .. val
    end

    return "{ " .. table.concat(parts, ", ") .. " }"
  end

  if t == "string" then
    return '"' .. escape_string(value) .. '"'
  end

  if value == nil then
    return "null"
  end

  return tostring(value)
end

local function render(value, indent, depth, sort_mode)
  local pad = string.rep(" ", depth * indent)
  local t = type(value)

  if t == "table" then

    if is_array(value) then
      if #value == 0 then return "[]" end

      local lines = {}

      for i = 1, #value do
        lines[#lines + 1] =
          pad .. string.rep(" ", indent) .. render(value[i], indent, depth + 1, sort_mode)
      end

      return "[\n"
        .. table.concat(lines, ",\n")
        .. "\n" .. pad .. "]"
    end

    local keys = sorted_keys(value, sort_mode)

    if #keys == 0 then return "{}" end

    local lines = {}

    for _, k in ipairs(keys) do
      local key = '"' .. escape_string(tostring(k)) .. '"'
      local val = render(value[k], indent, depth + 1, sort_mode)

      lines[#lines + 1] =
        pad .. string.rep(" ", indent) .. key .. ": " .. val
    end

    return "{\n"
      .. table.concat(lines, ",\n")
      .. "\n" .. pad .. "}"
  end

  if t == "string" then
    return '"' .. escape_string(value) .. '"'
  end

  if value == nil then
    return "null"
  end

  return tostring(value)
end

function Tson.__methods.__static.stringify(self, x, sort_mode)
  return stringify(x, sort_mode or Tson.__fields.sort.NONE)
end

function Tson.__methods.__static.stringify_pretty(self, x, indent, sort_mode)
  return render(x, indent or 2, 0, sort_mode or Tson.__fields.sort.NONE)
end

return Tson