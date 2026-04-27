# sino.array

Array utilities for working with lists.

### warning

no method here mutates the original list, instead provides a new array.

Import:

```sin
import Arr from "sino.array"
```

Most functions work well with the pipe operator.

xs |> Arr:sort(fn)

is equivalent to:

Arr:sort(xs, fn)

## Arr:len(array)

Returns the number of items in the array.

    Arr:len({1, 2, 3})
    -- 3

## Arr:at(array, index)

Returns the value at the given index.

    Arr:at({10, 20, 30}, 2)
    -- 20

## Arr:first(array)

Returns the first value.

    Arr:first({5, 6, 7})
    -- 5

## Arr:last(array)

Returns the last value.

    Arr:last({5, 6, 7})
    -- 7

## Arr:push(array, value)

Appends a value to the array.

    let xs = {1, 2}

    Arr:push(xs, 3)

## Arr:pop(array)

Removes and returns the last value.

    let xs = {1, 2, 3}

    Arr:pop(xs)
    -- 3

## Arr:join(array, separator)

Joins all values into a string.

    Arr:join({"a", "b", "c"}, "-")
    -- "a-b-c"

## Arr:map(array, callback)

Creates a new array by transforming each value.

Callback receives:

- value
- index

    {1, 2, 3}
    |> Arr:map(func(v, i) => v * 2)

    -- {2, 4, 6}

## Arr:filter(array, callback)

Creates a new array containing only values where callback returns true.

    {1, 2, 3, 4}
    |> Arr:filter(func(v, i) => v % 2 == 0)

    -- {2, 4}

## Arr:each(array, callback)

Runs callback for each item.

Returns the original array.

    {"a", "b"}
    |> Arr:each(func(v, i)
        print(i, v)
    end)

## Arr:find(array, callback)

Returns the first matching value, or nil.

    {3, 7, 10}
    |> Arr:find(func(v, i) => v > 5)

    -- 7

## Arr:reduce(array, callback, initial?)

Combines array values into one result.

If initial is omitted, the first element is used.

    {1, 2, 3}
    |> Arr:reduce(func(acc, v, i) => acc + v, 0)

    -- 6

## Arr:sort(array, callback?)

Returns a sorted copy.

    {3, 1, 2}
    |> Arr:sort(func(a, b) => a < b)

    -- {1, 2, 3}

Without callback, default Lua sorting is used.

## Arr:shuffle(array)

Returns a shuffled copy.

Does not mutate the original array.

    {1, 2, 3, 4}
    |> Arr:shuffle()
    -- example: {3, 2, 4, 1}