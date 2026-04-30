local Tson = {}
Tson.__name = "Tson"
Tson.__class = Tson
Tson.__fields = {}
Tson.__methods = {}

Tson.__fields.sort = {
  __fields = {
    NONE = 0,
    ALPHABETICAL = 1,
    REVERSE_ALPHABETICAL = 2,
  }
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
  local count = 0
  local max_key = 0

  for k, _ in pairs(t) do
    if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
      return false
    end

    count = count + 1
    if k > max_key then max_key = k end
  end

  return count == max_key
end

local function sorted_keys(source, sort_mode)
  sort_mode = sort_mode or Tson.__fields.sort.__fields.NONE
  local keys = {}

  for k, _ in pairs(source) do
    keys[#keys + 1] = k
  end

  if sort_mode == Tson.__fields.sort.__fields.ALPHABETICAL then
    table.sort(keys, function(a, b)
      return tostring(a) < tostring(b)
    end)
  elseif sort_mode == Tson.__fields.sort.__fields.REVERSE_ALPHABETICAL then
    table.sort(keys, function(a, b)
      return tostring(a) > tostring(b)
    end)
  end

  return keys
end

local function stringify_value(value, sort_mode)
  if type(value) == "table" then
    local source = value.__fields or value

    if is_array(source) then
      local parts = {}

      for i = 1, #source do
        parts[#parts + 1] = stringify_value(source[i], sort_mode)
      end

      return "[ " .. table.concat(parts, ", ") .. " ]"
    end

    local parts = {}

    for _, k in ipairs(sorted_keys(source, sort_mode)) do
      local key_str = stringify_value(tostring(k), sort_mode)
      local val_str = stringify_value(source[k], sort_mode)
      parts[#parts + 1] = key_str .. ": " .. val_str
    end

    return "{ " .. table.concat(parts, ", ") .. " }"
  elseif type(value) == "string" then
    return '"' .. escape_string(value) .. '"'
  elseif type(value) == "nil" then
    return "null"
  else
    return tostring(value)
  end
end

function Tson.__methods.stringify(self, x, sort_mode)
  sort_mode = sort_mode or Tson.__fields.sort.NONE
  return stringify_value(x, sort_mode)
end

function Tson.__methods.stringify_pretty(self, x, indent, sort_mode)
  indent = indent or 2
  sort_mode = sort_mode or Tson.__fields.sort.NONE

  local function pad(n)
    return string.rep(" ", n)
  end

  local function render(value, depth)
    if type(value) == "table" then
      local source = value.__fields or value

      if is_array(source) then
        if #source == 0 then
          return "[]"
        end

        local lines = {}

        for i = 1, #source do
          lines[#lines + 1] =
            pad((depth + 1) * indent) .. render(source[i], depth + 1)
        end

        return "[\n"
          .. table.concat(lines, ",\n")
          .. "\n"
          .. pad(depth * indent)
          .. "]"
      end

      local keys = sorted_keys(source, sort_mode)

      if #keys == 0 then
        return "{}"
      end

      local lines = {}

      for _, k in ipairs(keys) do
        local key = '"' .. escape_string(tostring(k)) .. '"'
        local val = render(source[k], depth + 1)

        lines[#lines + 1] =
          pad((depth + 1) * indent) .. key .. ": " .. val
      end

      return "{\n"
        .. table.concat(lines, ",\n")
        .. "\n"
        .. pad(depth * indent)
        .. "}"
    elseif type(value) == "string" then
      return '"' .. escape_string(value) .. '"'
    elseif type(value) == "nil" then
      return "null"
    else
      return tostring(value)
    end
  end

  return render(x, 0)
end

function Tson.__methods.parse(self, s)
  local i = 1

  local function skip()
    while s:sub(i,i):match("%s") do
      i = i + 1
    end
  end

  local parse_value

  local function parse_string()
    i = i + 1
    local out = ""

    while i <= #s do
      local c = s:sub(i,i)

      if c == '"' then
        i = i + 1
        return out
      elseif c == "\\" then
        i = i + 1
        out = out .. s:sub(i,i)
      else
        out = out .. c
      end

      i = i + 1
    end

    error("unterminated string")
  end

  local function parse_number()
    local start = i

    while s:sub(i,i):match("[%d%.%-]") do
      i = i + 1
    end

    return tonumber(s:sub(start, i - 1))
  end

  local function parse_array()
    i = i + 1
    local out = {}
    skip()

    if s:sub(i,i) == "]" then
      i = i + 1
      return { __fields = out }
    end

    while true do
      out[#out+1] = parse_value()
      skip()

      local c = s:sub(i,i)

      if c == "]" then
        i = i + 1
        return out
      end

      i = i + 1
    end
  end

  local function parse_object()
    i = i + 1
    local out = {}
    skip()

    if s:sub(i,i) == "}" then
      i = i + 1
      return { __fields = out }
    end

    while true do
      local key = parse_string()
      skip()
      i = i + 1 -- :
      skip()

      out[key] = parse_value()
      skip()

      local c = s:sub(i,i)

      if c == "}" then
        i = i + 1
        return { __fields = out }
      end

      i = i + 1
      skip()
    end
  end

  function parse_value()
    skip()
    local c = s:sub(i,i)

    if c == '"' then return parse_string() end
    if c == "{" then return parse_object() end
    if c == "[" then return parse_array() end
    if c:match("[%d%-]") then return parse_number() end

    if s:sub(i,i+3) == "true" then i=i+4 return true end
    if s:sub(i,i+4) == "false" then i=i+5 return false end
    if s:sub(i,i+3) == "null" then i=i+4 return nil end

    error("unexpected token at " .. i)
  end

  return parse_value()
end

return Tson