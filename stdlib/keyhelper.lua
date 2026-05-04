local helper = {}

function helper.get_method(target, name)
  local class

  -- detect class vs instance
  if target.__name ~= nil and target.__methods ~= nil then
    class = target
  else
    class = target.__class
  end

  while class do
    -- instance + static unified lookup
    local methods = class.__methods

    if methods then
      local method = methods[name] or (methods.__static and methods.__static[name])
      if method then
        return method
      end
    end

    class = class.__super
  end

  error("method not found: " .. tostring(name))
end

function helper.ref(value)
  return { __ref = true, value = value }
end

return helper