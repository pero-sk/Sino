local Str = {}
Str.__name = "Str"
Str.__class = Str
Str.__fields = {
}
Str.__methods = {__static = {} }


-- "hello" => "HELLO"
function Str.__methods.__static.upper(self, x)
  return string.upper(tostring(x))
end

-- "Hello" => "hello"
function Str.__methods.__static.lower(self, x)
  return string.lower(tostring(x))
end

-- "hello world" => 11
function Str.__methods.__static.len(self, x)
  return #tostring(x)
end

-- "  hello world " => "hello world"
function Str.__methods.__static.trim(self, x)
  return tostring(x):match("^%s*(.-)%s*$")
end

-- {1, 2, 3, 4}, " - " => "1 - 2 - 3 - 4"
function Str.__methods.__static.join(self, x, sep)
  sep = sep or ""

  local out = {}

  for i, v in ipairs(x) do
    out[i] = tostring(v)
  end

  return table.concat(out, sep)
end

-- "a,b,c", "," => {"a", "b", "c"}
function Str.__methods.__static.split(self, s, sep)
  s = tostring(s)
  sep = sep or ""

  local out = {}

  if sep == "" then
    for i = 1, #s do
      out[#out + 1] = s:sub(i, i)
    end
    return out
  end

  local start = 1

  while true do
    local i, j = s:find(sep, start, true)

    if not i then
      out[#out + 1] = s:sub(start)
      break
    end

    out[#out + 1] = s:sub(start, i - 1)
    start = j + 1
  end

  return out
end

-- let name = "John"
-- "hello {name}", {name = name} => "hello John"
function Str.__methods.__static.template(self, s, vars)
  vars = vars or {}

  return (s:gsub("{(.-)}", function(key)
    local value = vars[key]

    if value == nil then
      -- return as if {key} was not a placeholder, but as part of the string normally
      return "{" .. key .. "}"
    end

    return tostring(value)
  end))
end

return Str