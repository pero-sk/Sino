# sino.iterable

Utilities for working with iterable values, ranges, and key-value entries.

Import:

```sin
import Iter from "sino.iterable"
```

## Iter:values(array)

Wraps each array value as an iterable:

Each entry contains:

- value

Iter:values({"a", "b", "c"})
-- {"a", "b", "c"}, only really needed to wrap it as a sino object

## Iter:value(entry)

Returns the value from an entry.

    let item = Iter:values({10})

    Iter:value(item)
    -- 10

## Iter:key(entry)

Returns the key from an entry.

Used with entries created by enumerate, pairs, or keys.

    let item = Iter:enumerate({"a"})

    Iter:key(item)
    -- 1

    let item2 = Iter:pairs({a="b"})

    Iter:key(item2)
    -- a

## Iter:enumerate(array)

Creates entries containing index and value.

Each entry contains:

- key

- value

```sin
Iter:enumerate({"a", "b"})

-- {

-- {key = 1, value = "a"},

-- {key = 2, value = "b"}

-- }
```

## Iter:pairs(object)

Creates entries from key-value pairs in an object.

Each entry contains:

- key

- value

```sin
Iter:pairs({name = "Chloe", age = 20})
-- key=name, value="Chloe"
```

## Iter:keys(object)

Creates entries containing only keys.

Each entry contains:

- key

```sin
Iter:keys({name = "Chloe", age = 20})
```

## Iter:range(start, finish, step?)

Creates a numeric range.

If step is omitted, 1 is used.

    Iter:range(1, 5)
    -- {1, 2, 3, 4, 5}

    Iter:range(0, 10, 2)
    -- {0, 2, 4, 6, 8, 10}

    Iter:range(5, 1, -1)
    -- {5, 4, 3, 2, 1}

Step cannot be 0.