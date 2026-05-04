local Arr = {}
Arr.__name = "Arr"
Arr.__class = Arr
Arr.__fields = {}
Arr.__methods = {__static = {}}

local function assert_array(xs, name)
  if xs.__arr == nil or xs.__arr ~= true then
    error("Arr:".. name .. " expects array, got object")
  end
end

function Arr.__methods.__static.len(self, xs)
  assert_array(xs, "len")
  return #xs
end

function Arr.__methods.__static.at(self, xs, index)
  assert_array(xs, "at")
  return xs[index]
end

function Arr.__methods.__static.push(self, xs, value)
  assert_array(xs, "push")
  xs[#xs + 1] = value
  return xs
end

function Arr.__methods.__static.pop(self, xs)
  assert_array(xs, "pop")
  local value = xs[#xs]
  xs[#xs] = nil
  return value
end

function Arr.__methods.__static.first(self, xs)
  assert_array(xs, "first")
  return xs[1]
end

function Arr.__methods.__static.last(self, xs)
  assert_array(xs, "last")
  return xs[#xs]
end

function Arr.__methods.__static.join(self, xs, sep)
  assert_array(xs, "join")
  return table.concat(xs, sep or "")
end

-- lambda array methods

function Arr.__methods.__static.map(self, xs, fn)
  assert_array(xs, "map")
  local out = {}

  for i, value in ipairs(xs) do
    out[#out + 1] = fn(value, i)
  end

  return out
end

function Arr.__methods.__static.filter(self, xs, fn)
  assert_array(xs, "filter")
  local out = {}

  for i, value in ipairs(xs) do
    if fn(value, i) then
      out[#out + 1] = value
    end
  end

  return out
end

function Arr.__methods.__static.each(self, xs, fn)
  assert_array(xs, "each")
  local source = xs

  for idx, value in ipairs(source) do
    fn(value, idx)
  end

  return xs
end

function Arr.__methods.__static.find(self, xs, fn)
  assert_array(xs, "find")
  for i, value in ipairs(xs) do
    if fn(value, i) then
      return value
    end
  end

  return nil
end

function Arr.__methods.__static.reduce(self, xs, fn, initial)
  assert_array(xs, "reduce")
  local acc = initial
  local start = 1

  if acc == nil then
    acc = xs[1]
    start = 2
  end

  for i = start, #xs do
    acc = fn(acc, xs[i], i)
  end

  return acc
end

function Arr.__methods.__static.sort(self, xs, fn)
  assert_array(xs, "sort")
  local source = xs
  local out = {}

  for i, v in ipairs(source) do
    out[i] = v
  end

  if fn then
    table.sort(out, fn)
  else
    table.sort(out)
  end

  return out
end

function Arr.__methods.__static.shuffle(self, xs)
  assert_array(xs, "shuffle")
  local source = xs
  local out = {}

  for i, v in ipairs(source) do
    out[i] = v
  end

  for i = #out, 2, -1 do
    local j = math.random(i)
    out[i], out[j] = out[j], out[i]
  end

  return out
end

for k, v in pairs(Arr.__methods.__static) do
  Arr[k] = v
end

return Arr