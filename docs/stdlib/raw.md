# sino.raw

A way of accessing non-sino structured objects, made easy.

Import
```sin
import Raw from "sino.raw"
```

## Raw:get(obj, key)

Returns obj[key] which bypasses sino's strict usage of __fields and __methods.

## Raw:set(obj, key, value)

sets obj[key] to value

and returns obj.

## Raw:call(obj, key, ...args)

Calls obj[key] with (...args) as parameters.

## Raw:method(obj, key, ...args)

Calls obj[key] with (obj, ..args) as parameters.

## Raw:has(obj, key)

Returns whether obj[key] exists or not.