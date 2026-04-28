# sino.string

String utilities.

Import:

```sin
import Str from "sino.string"
```

Most functions work well with the pipe operator.

text |> Str:upper()

is equivalent to:

Str:upper(text)

## Str:len(string)

Returns the length of the string.

    Str:len("hello")
    -- 5

## Str:upper(string)

Returns the string in uppercase.

    Str:upper("hello")
    -- "HELLO"

## Str:lower(string)

Returns the string in lowercase.

    Str:lower("HELLO")
    -- "hello"

## Str:trim(string)

Removes whitespace from the start and end.

    Str:trim("  hello  ")
    -- "hello"
## Str:join(array, separator?)

Joins values into a string.

If separator is omitted, an empty string is used.

    Str:join({1, 2, 3}, " - ")
    -- "1 - 2 - 3"

## Str:split(string, separator?)

Splits a string into an array.

If separator is omitted or empty, splits into characters.

Str:split("a,b,c", ",")
-- {"a", "b", "c"}

Str:split("abc")
-- {"a", "b", "c"}

## Str:template(string, values?)

Replaces placeholders using values from an object.

Unknown placeholders remain unchanged.

    let name = "John"

    Str:template("hello {name}", {name = name})
    -- "hello John"

    Str:template("hello {user}")
    -- "hello {user}"