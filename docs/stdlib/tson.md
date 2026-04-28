# sino.tson

Utilities for working with Table to JSON data.

TSON is a lightweight structured data format similar to JSON, with support for arrays, objects, strings, numbers, booleans, and null.

Import:

```sin
import Tson from "sino.tson"
```

## Sort Modes

Available sort modes:

```sin
    Tson.sort.NONE
    Tson.sort.ALPHABETICAL
    Tson.sort.REVERSE_ALPHABETICAL
```

Used when stringifying objects.

## Tson:stringify(value, sort?)

Converts a value into compact TSON text.

If sort is omitted, no key sorting is used.

```sin
    Tson:stringify({name = "John", age = 20})

    -- {"name": "John", "age": 20}

    Tson:stringify(
        {b = 2, a = 1},
        Tson.sort.ALPHABETICAL
    )

    -- {"a": 1, "b": 2}
```

## Tson:stringify_pretty(value, indent?, sort?)

Converts a value into formatted TSON text.

If indent is omitted, 2 is used.

```sin
    Tson:stringify_pretty(
        {name = "John", age = 20}
    )

    -- {
    --   "name": "John",
    --   "age": 20
    -- }
```

## Tson:parse(text)

Parses TSON text into values.

Objects and arrays are returned as Sino-style tables.

```sin
    Tson:parse('{"name": "John"}')

    Tson:parse('[1, 2, 3]')
```

# Supported Values

- strings
- numbers
- booleans
- nil
- arrays
- objects

# Example

```sin
let data = {
    name = "John",
    age = 20,
    tags = {"dev", "lua"}
}

let text = Tson:stringify_pretty(data)

print(text)
```