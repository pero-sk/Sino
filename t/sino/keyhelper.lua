local helper = {}

function helper.get_method(class, name)
  while class do
    if class.__methods and class.__methods[name] then
      return class.__methods[name]
    end

    class = class.__super
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