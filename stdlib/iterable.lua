local Iter = {}
Iter.__name = "Iter"
Iter.__class = Iter
Iter.__fields = {}
Iter.__methods = {__static = {} }

function Iter.__methods.__static.values(self, xs)
  local out = {}

  for _, value in ipairs(xs) do
    out[#out + 1] = {__fields = {value = value}}
  end

  return {__fields=out}
end

function Iter.__methods.__static.value(self, x)
  return x.__fields.value
end

function Iter.__methods.__static.key(self, x)
  return x.__fields.key
end

function Iter.__methods.__static.enumerate(self, xs)
  local out = {}

  for index, value in ipairs(xs) do
    out[#out + 1] = {
      __fields = {
        key = index,
        value = value,
      }
    }
  end

  return {__fields=out}
end

function Iter.__methods.__static.pairs(self, obj)
  local source = obj.__fields or obj
  local out = {}

  for key, value in pairs(source) do
    out[#out + 1] = {
      __fields = {
        key = key,
        value = value,
      }
    }
  end

  return { __fields = out }
end

function Iter.__methods.__static.keys(self, obj)
  local out = {}

  for key, _ in pairs(obj) do
    out[#out + 1] = {
      __fields = {
        key = key,
      }
    }
  end

  return {__fields=out}
end

function Iter.__methods.__static.range(self, start_value, end_value, step)
  local out = {}
  step = step or 1

  if step == 0 then
    error("Iter.range step cannot be 0")
  end

  if step > 0 then
    for i = start_value, end_value, step do
      out[#out + 1] = i
    end
  else
    for i = start_value, end_value, step do
      out[#out + 1] = i
    end
  end

  return {__fields=out}
end

for k, v in pairs(Iter.__methods.__static) do
  Iter[k] = v
end

return Iter