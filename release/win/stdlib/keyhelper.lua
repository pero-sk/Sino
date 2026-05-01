local helper = {}

function helper.get_method(target, name)
  local class

  -- detect class vs instance
  if target.__class == target then
    -- class
    class = target
    while class do
      if class.__methods and class.__methods.__static and class.__methods.__static[name] then
        return class.__methods.__static[name]
      end
      class = class.__super
    end
  else
    -- instance
    class = target.__class
    while class do
      if class.__methods and class.__methods[name] then
        return class.__methods[name]
      end
      class = class.__super
    end
  end

  error("method not found: " .. tostring(name))
end

function helper.ref(value)
  return {
    __ref = true,
    value = value,
  }
end

return helper