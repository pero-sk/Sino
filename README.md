# Sino

Sino is a modern superset of Lua that compiles to plain Lua.

Write cleaner, more expressive code with features like classes, destructuring, and pipelines all while keeping Lua’s speed, portability, and simplicity.

Write `.sin` files. Compile to `.lua`. Run anywhere Lua runs.

---

# Installation

### Windows

1. Go to the [releases page](https://github.com/pero-sk/Sino/releases)
2. Download `win.zip`  
3. Extract the archive
4. Move extracted archive contents to a folder (e.g. `C:\sino`)
5. Add that folder to your PATH

Verify installation:

```bash
sino --version
```

# Why Sino?

Lua is excellent:

- fast
- lightweight
- embeddable
- portable
- simple

But everyday scripting can feel verbose or dated.

Sino improves that with:

- classes
- fields & methods
- lambdas
- pipe operator
- destructuring
- ref types
- compound assignment
- directives
- standard library helpers

All while staying compatible with the Lua ecosystem.

---

# Example

## Sino

```sin
import Arr from "sino.array"

class Person
    field name
    field age

    func Self:new(name, age)
        self.name = name
        self.age = age
    end
end

let people = {
    Person("Chloe", 20),
    Person("Adam", 25),
    Person("John", 19)
}

people
|> Arr:sort(func(a, b) => a.name < b.name)
|> Arr:each(func(person, i) => print(person.name))
```
## output

```plaintext
Adam

Chloe

John
```

---

# Features

## Variables

    let name = "John"
    const age = 20

## Functions

    func add(a, b)
        return a + b
    end

## Lambdas

    func(x) => x * 2

    func(x) do
        print(x)
    end

## Classes

    class Person
        field name

        func Self:new(name)
            self.name = name
        end

        func greet()
            print(self.name)
        end
    end

### Constructors

class constructors are made using this style

    func Self:X(y) => Self

which `return Self(...)`

the exception to these constructors is the `new` constructor, which is shown above


## Pipe Operator

    data
    |> transform()
    |> save()

## Destructuring

    let {name, age} = person
    let {name: forename} = person

## Ref Types

    let x := 10
    let y = x

    y := y^ + 5

    print(x^) -- 15

## Compound Assignment

    x += 1
    score *= 2

## Directives

    @deprecated("Use newFunc instead")
    func oldFunc()
        ...
    end

    @allow(RawLua)
    lua
        print("hello from lua")
    end

    @allow(RefCursing)
    let x = {__ref=true,value=...}

# Standard Library

Modules include:

- sino.array
- sino.string
- sino.iterable
- sino.tson
- sino.io
- sino.math
- sino.types

Example:

    import Str from "sino.string"

    "Hello, {name}!"
    |> Str:template({name="John"})
    |> print()

# Philosophy

Sino does not replace Lua.

Sino makes Lua nicer to write.

Modern syntax. Lua runtime.

# Goals

- Keep Lua lightweight
- Improve readability
- Stay practical
- Generate clean Lua
- Preserve Lua compatibility