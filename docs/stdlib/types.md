# sino.types

Utilities for type checking, conversion, and runtime inspection.

Import:

```sin
import Types from "sino.types"
```

## Types:of(value)

Returns the detected Sino type.

Possible results include:

- nil
- number
- string
- boolean
- function
- table
- array
- object
- ref
- class
- instance

```sin
Types:of(123)
-- "number"

Types:of({1, 2, 3})
-- "array"
```

## Types:name(value)

Returns a readable name for the value.

For classes and instances, returns the class name when available.

```sin
Types:name("hello")
-- "string"
```

## Types:is(value, expected)

Returns true if the detected type matches the expected name.

```sin
Types:is({1, 2, 3}, "array")
-- true
```

## Types:is_array(value)

Returns true if the value is an array.

```sin
Types:is_array({1, 2, 3})
-- true
```

## Types:is_object(value)

Returns true if the value is an object.

```sin
Types:is_object({name = "John"})
-- true
```

## Types:is_ref(value)

Returns true if the value is a Sino ref.

## Types:is_class(value)

Returns true if the value is a class.

## Types:is_instance(value)

Returns true if the value is a class instance.

## Types:string(value)

Converts a value to a string.

nil becomes "nil".

```sin
Types:string(42)
-- "42"
```

## Types:boolean(value)

Converts a value to a boolean.

Rules include:

- nil => false
- false => false
- 0 => false
- "false" => false
- "no" => false
- "" => false

Most other values become true.

```sin
Types:boolean("yes")
-- true
```

## Types:raw(value)

Returns raw internal data.

If the value contains __fields (is a sino object), that table is returned.

```sin
Types:raw(obj)
```

## Types:instanceof(value, class)

Returns true if an instance belongs to a class or inherited class.

```sin
Types:instanceof(person, Person)
-- true
```

