local Types = {}
Types.__name = "Types"
Types.__class = Types
Types.__fields = {}
Types.__methods = {__static = {} }

local function is_array(t)
  if type(t) ~= "table" then
    return false
  end

  local count = 0
  local max_key = 0

  for k, _ in pairs(t) do
    if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
      return false
    end

    count = count + 1
    if k > max_key then
      max_key = k
    end
  end

  return count == max_key
end

function Types.__methods.__static.of(self, x)
  local t = type(x)

  if t ~= "table" then
    return t
  end

  if x.__ref == true then
    return "ref"
  end

  if x.__methods and x.__name and x.__class == x then
    return "class"
  end

  if x.__class and x.__fields then
    return "instance"
  end

  if x.__fields then
    if is_array(x.__fields) then
      return "array"
    end

    return "object"
  end

  if is_array(x) then
    return "array"
  end

  return "object"
end

function Types.__methods.__static.name(self, x)
  if type(x) == "table" then
    if x.__name then
      return x.__name
    end

    if x.__class and x.__class.__name then
      return x.__class.__name
    end
  end

  return type(x)
end

function Types.__methods.__static.is(self, x, expected)
  return Types.__methods.__static.of(self, x) == expected
end

function Types.__methods.__static.is_array(self, x)
  return Types.__methods.__static.of(self, x) == "array"
end

function Types.__methods.__static.is_object(self, x)
  return Types.__methods.__static.of(self, x) == "object"
end

function Types.__methods.__static.is_ref(self, x)
  return Types.__methods.__static.of(self, x) == "ref"
end

function Types.__methods.__static.is_class(self, x)
  return Types.__methods.__static.of(self, x) == "class"
end

function Types.__methods.__static.is_instance(self, x)
  return Types.__methods.__static.of(self, x) == "instance"
end

function Types.__methods.__static.string(self, x)
  if x == nil then
    return "nil"
  end

  return tostring(x)
end

function Types.__methods.__static.number(self, x)
  return tonumber(x)
end

function Types.__methods.__static.boolean(self, x)
  if x == nil then
    return false
  end

  if type(x) == "boolean" then
    return x
  end

  if type(x) == "number" then
    return x ~= 0
  end

  if type(x) == "string" then
    local s = x:lower()

    if s == "true" or s == "yes" or s == "1" then
      return true
    end

    if s == "false" or s == "no" or s == "0" or s == "" then
      return false
    end
  end

  return true
end

function Types.__methods.__static.raw(self, x)
  if type(x) == "table" and x.__fields then
    return x.__fields
  end

  return x
end

function Types.__methods.__static.instanceof(self, x, class)
  if type(x) ~= "table" then
    return false
  end

  local c = x.__class

  while c do
    if c == class then
      return true
    end

    c = c.__super
  end

  return false
end

for k, v in pairs(Types.__methods.__static) do
  Types[k] = v
end

return Types