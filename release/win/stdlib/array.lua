local Arr = {}
Arr.__name = "Arr"
Arr.__class = Arr
Arr.__fields = {}
Arr.__methods = {}

function Arr.__methods.len(self, xs)
  return #xs
end

function Arr.__methods.at(self, xs, index)
  return xs[index]
end

function Arr.__methods.push(self, xs, value)
  xs[#xs + 1] = value
  return xs
end

function Arr.__methods.pop(self, xs)
  local value = xs[#xs]
  xs[#xs] = nil
  return value
end

function Arr.__methods.first(self, xs)
  return xs[1]
end

function Arr.__methods.last(self, xs)
  return xs[#xs]
end

function Arr.__methods.join(self, xs, sep)
  return table.concat(xs, sep or "")
end

-- lambda array methods

function Arr.__methods.map(self, xs, fn)
  local out = {}

  for i, value in ipairs(xs) do
    out[#out + 1] = fn(value, i)
  end

  return out
end

function Arr.__methods.filter(self, xs, fn)
  local out = {}

  for i, value in ipairs(xs) do
    if fn(value, i) then
      out[#out + 1] = value
    end
  end

  return out
end

function Arr.__methods.each(self, xs, fn)
  local source = xs.__fields or xs

  for idx, value in ipairs(source) do
    fn(value, idx)
  end

  return xs
end

function Arr.__methods.find(self, xs, fn)
  for i, value in ipairs(xs) do
    if fn(value, i) then
      return value
    end
  end

  return nil
end

function Arr.__methods.reduce(self, xs, fn, initial)
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

function Arr.__methods.sort(self, xs, fn)
  local source = xs.__fields or xs
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

function Arr.__methods.shuffle(self, xs)
  local source = xs.__fields or xs
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

return Arr