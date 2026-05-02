local helper = {}

-- cache so we don't re-expose classes twice
local exposed = setmetatable({}, { __mode = "k" })

function helper.get_method(target, name)
  local class

  if target.__class == target then
    class = target
    while class do
      local static = class.__methods and class.__methods.__static
      if static and static[name] then
        return static[name]
      end
      class = class.__super
    end
  else
    class = target.__class
    while class do
      local method = class.__methods and class.__methods[name]
      if method then
        return method
      end
      class = class.__super
    end
  end

  error("method not found: " .. tostring(name))
end

function helper.ref(value)
  return { __ref = true, value = value }
end

return helper