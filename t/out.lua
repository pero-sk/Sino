local __sino = require("sino.keyhelper")

local Iter = require("sino.iterable")

local Arr = require("sino.array")

local function x()
  return {a = 1, b = 2}
end

local a = x()

local __destructure_1 = a
__destructure_1 = __destructure_1.__fields or __destructure_1
local x = __destructure_1.a
local y = __destructure_1.b

__sino.get_method(Arr.__class, "each")(Arr, __sino.get_method(Arr.__class, "sort")(Arr, {y, x}, function(a, b) return a < b end), function(val, idx) return print(val) end)

__sino.get_method(Arr.__class, "each")(Arr, __sino.get_method(Arr.__class, "sort")(Arr, {y, x}, function(a, b) return a < b end), function(val, idx) return print(val) end)

__sino.get_method(Arr.__class, "each")(Arr, __sino.get_method(Arr.__class, "sort")(Arr, {y, x}, function(a, b) return a < b end), function(val, dix) return print(val) end)