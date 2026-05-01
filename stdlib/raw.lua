local Raw = {}

Raw.__name = "Raw"
Raw.__class = Raw
Raw.__fields = {}
Raw.__methods = { __static = {} }

function Raw.__methods.__static.get(Self, obj, key)
  return obj[key]
end

function Raw.__methods.__static.set(Self, obj, key, value)
  obj[key] = value
  return obj
end

function Raw.__methods.__static.call(Self, obj, key, ...)
  return obj[key](...)
end

function Raw.__methods.__static.method(Self, obj, key, ...)
  return obj[key](obj, ...)
end

function Raw.__methods.__static.has(Self, obj, key)
  return obj[key] ~= nil
end

return Raw