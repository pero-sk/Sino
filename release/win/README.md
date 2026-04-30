# Sino (Windows)

**Modern syntax for Lua. Plain Lua output. No runtime cost.**

---

## What is Sino?

Sino is a **superset of Lua** that adds modern language features while compiling to standard Lua.

* No VM
* No runtime dependency
* Works anywhere Lua works

---

## Quick Start

```bat
sino run examples\03_pipelines.sin
```

That’s it.

---

## Usage

```bat
sino <file.sin>
sino build <file.sin>
sino run <file.sin>
sino clean <file.sin>
```

### Options

```txt
--silent     Suppress output
--progress   Generate debug files (.tokens, .ast)
--clean      Remove generated files
```

---

## Example

```sin
import Arr from "sino.array"

{1, 2, 3, 4}
|> Arr:map(func(x) do return x * 2 end)
|> Arr:each(func(x) do print(x) end)
```

---

## Output

Sino compiles `.sin` files into `.lua`:

```txt
input.sin  ->  input.lua
```

Run with Lua:

```bat
lua input.lua
```

---

## Stdlib

```sin
import Arr from "sino.array"
import Str from "sino.string"
import Iter from "sino.iterable"
```

Used modules are automatically copied into:

```txt
./sino/
```

---

## Project Structure

```txt
your-project/
  app.sin
  app.lua
  sino/
    array.lua
    string.lua
    iterable.lua
```

---

## Notes

* `run` requires Lua installed (`lua` in PATH)
* Output Lua is fully portable (keep the `sino/` folder)

---

## License

Apache License 2.0
