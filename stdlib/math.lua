local Math = {}
Math.__name = "Math"
Math.__class = Math
Math.__fields = {}
Math.__methods = {}

function Math.__methods.abs(self, x)
  return math.abs(x)
end

function Math.__methods.sqrt(self, x)
  return math.sqrt(x)
end

function Math.__methods.pow(self, x, y)
  return x ^ y
end

function Math.__methods.max(self, x, y)
  return math.max(x, y)
end

function Math.__methods.min(self, x, y)
  return math.min(x, y)
end

function Math.__methods.floor(self, x)
  return math.floor(x)
end

function Math.__methods.ceil(self, x)
  return math.ceil(x)
end

function Math.__methods.round(self, x)
  if x >= 0 then
    return math.floor(x + 0.5)
  else
    return math.ceil(x - 0.5)
  end
end

function Math.__methods.clamp(self, x, min, max)
  return math.max(min, math.min(max, x))
end

function Math.__methods.sign(self, x)
  if x > 0 then
    return 1
  elseif x < 0 then
    return -1
  else
    return 0
  end
end

function Math.__methods.sin(self, x)
  return math.sin(x)
end

function Math.__methods.cos(self, x)
  return math.cos(x)
end

function Math.__methods.tan(self, x)
  return math.tan(x)
end

function Math.__methods.asin(self, x)
  return math.asin(x)
end

function Math.__methods.acos(self, x)
  return math.acos(x)
end

function Math.__methods.atan(self, x)
  return math.atan(x)
end

function Math.__methods.atan2(self, y, x)
  return math.atan(y, x)
end

function Math.__methods.random(self, min, max)
  if min and max then
    return math.random(min, max)
  elseif min then
    return math.random(min)
  else
    return math.random()
  end
end

function Math.__methods.lerp(self, a, b, t)
  return a + (b - a) * t
end

Math.__fields.PI = math.pi
Math.__fields.E = math.exp(1)
Math.__fields.INFINITY = math.huge
Math.__fields.NAN = 0 / 0

return Math