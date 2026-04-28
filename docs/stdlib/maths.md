# sino.math

Mathematical utilities and constants.

Import:

```sin
import Math from "sino.math"
```

# Constants

## Math.PI

The value of π.

## Math.E

The value of Euler's number.

## Math.INFINITY

Positive infinity.

## Math.NAN

Not-a-number value.

## Math:abs(number)

Returns the absolute value.

## Math:sqrt(number)

Returns the square root.

## Math:pow(base, exponent)

Raises a number to a power.

## Math:max(a, b)

Returns the larger value.

```sin
Math:max(4, 9)
-- 9
```

## Math:min(a, b)

Returns the smaller value.

```sin
Math:min(4, 9)
-- 4
```

## Math:floor(number)

Rounds down.

## Math:ceil(number)

Rounds up.

## Math:round(number)

Rounds to the nearest whole number.

## Math:clamp(value, min, max)

Limits a value to a range.

## Math:sign(number)

Returns:

- 1 if positive
- -1 if negative
- 0 if zero

```sin
Math:sign(-8)
-- -1
```

## Math:sin(radians)

Returns the sine of an angle.

## Math:cos(radians)

Returns the cosine of an angle.

## Math:tan(radians)

Returns the tangent of an angle.

## Math:asin(number)

Returns the inverse sine.

## Math:acos(number)

Returns the inverse cosine.

## Math:atan(number)

Returns the inverse tangent.

## Math:atan2(y, x)

Returns the angle from coordinates.

## Math:random(min?, max?)

Returns a random number.

Forms:

- Math:random()
- Math:random(max)
- Math:random(min, max)

## Math:lerp(a, b, t)

Linearly interpolates between two values.

t = 0 returns a

t = 1 returns b

```sin
Math:lerp(10, 20, 0.5)
-- 15
```