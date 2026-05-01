local SINO_VERSION = "0.1.5"

--
-- findself
--

local function normalize_path(path)
  return (path:gsub("\\", "/"))
end

local function current_script_dir()
  local source = debug.getinfo(1, "S").source

  -- Normal Lua script mode:
  -- lua main.lua ...
  if source:sub(1, 1) == "@" then
    local path = normalize_path(source:sub(2))
    return path:match("^(.*)/") or "."
  end

  -- Bundled executable mode:
  -- sino.exe ...
  if arg and arg[0] then
    local path = normalize_path(arg[0])
    local dir = path:match("^(.*)/")
    if dir then
      return dir
    end
  end

  return "."
end

--
-- locate compiler + load modules
--

local compiler_dir = current_script_dir()

local sep = package.config:sub(1, 1)
package.path = compiler_dir .. sep .. "?.lua" .. ";" .. package.path

local ok, lexer_mod = pcall(require, "lexer")
if not ok then
  print("require failed:")
  print(lexer_mod)
  os.exit(1)
end

local ok, parser_mod = pcall(require, "parser")
if not ok then
  print("require failed:")
  print(parser_mod)
  os.exit(1)
end

local ok, validator_mod = pcall(require, "validator")
if not ok then
  print("require failed:")
  print(validator_mod)
  os.exit(1)
end

local ok, codegen_mod = pcall(require, "codegen")
if not ok then
  print("require failed:")
  print(codegen_mod)
  os.exit(1)
end

--
-- helpers
--

local function read_file(path)
  local file, err = io.open(path, "rb")
  if not file then
    error("failed to open file '" .. path .. "': " .. tostring(err))
  end

  local content = file:read("*a")
  file:close()
  return content
end

local function write_file(path, content)
  local file, err = io.open(path, "w")
  if not file then
    error("failed to open file '" .. path .. "': " .. tostring(err))
  end

  file:write(content)
  file:close()
end

local function split_lines(source)
  local lines = {}

  source = source:gsub("\r\n", "\n")

  for line in (source .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end

  return lines
end

local function indent_block(source)
  source = source:gsub("\r\n", "\n")

  local out = {}

  for line in (source .. "\n"):gmatch("(.-)\n") do
    if line == "" then
      out[#out + 1] = ""
    else
      out[#out + 1] = "  " .. line
    end
  end

  return table.concat(out, "\n")
end

local function print_source_error(err, fallback_file)
  local filename = err.filename or fallback_file or "<unknown>"
  local line = err.start and err.start.line or 1
  local column = err.start and err.start.column or 1
  local message = err.message or "unknown error"
  local kind = err.kind or "Error"

  io.stderr:write(string.format(
    "%s:%d:%d: %s: %s\n",
    filename,
    line,
    column,
    kind,
    message
  ))

  local ok, source = pcall(read_file, filename)
  if not ok then
    return
  end

  local lines = split_lines(source)
  local source_line = lines[line]

  if not source_line then
    return
  end

  io.stderr:write(string.format("%4d | %s\n", line, source_line))
  io.stderr:write("     | " .. string.rep(" ", math.max(column - 1, 0)) .. "^\n")
end

local function dirname(path)
  return path:match("^(.*)[/\\]") or "."
end

local function join_path(a, b)
  return a .. sep .. b
end

local function mkdir(path)
  if sep == "\\" then
    os.execute('mkdir "' .. path .. '" >nul 2>nul')
  else
    os.execute('mkdir -p "' .. path .. '" >/dev/null 2>/dev/null')
  end
end

local function remove_file(path)
  os.remove(path)
end

local function remove_dir(path)
  if sep == "\\" then
    os.execute('rmdir /s /q "' .. path .. '" >nul 2>nul')
  else
    os.execute('rm -rf "' .. path .. '" >/dev/null 2>/dev/null')
  end
end

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then
    f:close()
    return true
  end
  return false
end

local function module_to_path(module)
  return module:gsub("%.", sep)
end

local function copy_file(src, dst)
  write_file(dst, read_file(src))
end

local function copy_runtime_files(out_dir, compiler_dir, used_runtime)
  local runtime_dir = join_path(out_dir, "sino")
  local stdlib_dir = join_path(compiler_dir, "stdlib")

  mkdir(runtime_dir)

  for name, used in pairs(used_runtime or {}) do
    if used then
      local src = join_path(stdlib_dir, name .. ".lua")
      local dst = join_path(runtime_dir, name .. ".lua")
      copy_file(src, dst)
    end
  end
end

local function compact_lua_module(local_name, module_path, compiler_dir)
  local stdlib_dir = join_path(compiler_dir, "stdlib")

  local runtime_name = module_path:match("^sino%.(.+)$")
  local source_path

  if runtime_name then
    source_path = join_path(stdlib_dir, runtime_name .. ".lua")
  else
    error("compact mode can only inline stdlib modules for now: " .. module_path)
  end

  if not file_exists(source_path) then
    error("cannot compact missing module: " .. module_path)
  end

  local source = read_file(source_path)
  source = source:gsub("\r\n", "\n")

  local returned = source:match("return%s+([%w_]+)%s*$")

  if not returned then
    error("cannot compact module without final 'return X': " .. module_path)
  end

  source = source:gsub("%s*return%s+[%w_]+%s*$", "")

  return table.concat({
    "local " .. local_name .. " = (function()",
    indent_block(source),
    "  return " .. returned,
    "end)()",
  }, "\n")
end

local function compact_source(lua_source, ast, used_runtime, compiler_dir)
  local chunks = {}

  if used_runtime and used_runtime.keyhelper then
    chunks[#chunks + 1] = compact_lua_module("__sino", "sino.keyhelper", compiler_dir)
  end

  for _, stmt in ipairs(ast.body or {}) do
    if stmt.kind == "ImportDecl" then
      chunks[#chunks + 1] = compact_lua_module(
        stmt.name,
        stmt.resolvedRequire or stmt.path,
        compiler_dir
      )
    end
  end

  lua_source = lua_source:gsub('local __sino = require%("sino%.keyhelper"%)%s*\n?', "")

  for _, stmt in ipairs(ast.body or {}) do
    if stmt.kind == "ImportDecl" then
      local require_path = stmt.resolvedRequire or stmt.path
      local pattern = 'local%s+' .. stmt.name .. '%s+=%s+require%("' .. require_path:gsub("%.", "%%.") .. '"%)%s*\n?'
      lua_source = lua_source:gsub(pattern, "")
    end
  end

  chunks[#chunks + 1] = lua_source

  return table.concat(chunks, "\n\n")
end

local function format_ast(node, depth)
  depth = depth or 0
  local lines = {}
  local pad = string.rep("  ", depth)

  if type(node) ~= "table" then
    return pad .. tostring(node)
  end

  lines[#lines + 1] = pad .. tostring(node.kind or "<table>")

  for k, v in pairs(node) do
    if k ~= "kind"
      and k ~= "start"
      and k ~= "finish"
      and k ~= "token"
      and k ~= "nameToken"
      and k ~= "pathToken"
      and k ~= "opToken"
    then
      if type(v) == "table" then
        lines[#lines + 1] = pad .. "  " .. tostring(k) .. ":"
        lines[#lines + 1] = format_ast(v, depth + 2)
      else
        lines[#lines + 1] = pad .. "  " .. tostring(k) .. ": " .. tostring(v)
      end
    end
  end

  return table.concat(lines, "\n")
end

local function run_phase(name, filename, fn)
  local ok, a, b, c, d = pcall(fn)

  if ok then
    return a, b, c, d
  end

  local err = a

  if type(err) == "table" and err.kind then
    print_source_error(err, filename)
    os.exit(1)
  end

  io.stderr:write(name .. " failed: " .. tostring(err) .. "\n")
  os.exit(1)
end

--
-- forward decls
--

local compile_file
local resolve_imports

--
-- compile
--

compile_file = function(path, compiler_dir, seen, progress, compact)
  seen = seen or {}

  if seen[path] then
    return
  end
  seen[path] = true

  local source = read_file(path)

  local Lexer = lexer_mod.Lexer
  local lexer = Lexer.new(source, path)
  local tokens = run_phase("lexer", path, function()
    return lexer:tokenize()
  end)

  if progress then
    local token_lines = {}

    for _, token in ipairs(tokens) do
      local value = token.value
      if value == nil then
        value = ""
      end

      token_lines[#token_lines + 1] =
        token.kind .. " [" .. tostring(value) .. "]"
    end

    write_file(path:gsub("%.sin$", ".tokens"), table.concat(token_lines, "\n"))
  end

  local Parser = parser_mod.Parser
  local parser = Parser.new(tokens, path, source)
  local ast = run_phase("parser", path, function()
    return parser:parse()
  end)

  if progress then
    write_file(path:gsub("%.sin$", ".ast"), format_ast(ast))
  end

  local Validator = validator_mod.Validator
  run_phase("validator", path, function()
    return Validator.validate(ast, path)
  end)

  local out_file = path:gsub("%.sin$", ".lua")
  local out_dir = dirname(out_file)

  resolve_imports(ast, path, out_dir, compiler_dir, seen, progress, compact)
  
  local Codegen = codegen_mod.Codegen
  local result = { run_phase("codegen", path, function()
    return Codegen.generate(ast)
  end) }

  local lua_source = result[1]
  local used_runtime = result[2]
  
  if compact then
    lua_source = compact_source(lua_source, ast, used_runtime, compiler_dir)
  else
    copy_runtime_files(out_dir, compiler_dir, used_runtime)
  end

  write_file(out_file, lua_source)

  return out_file
end

resolve_imports = function(ast, current_file, out_dir, compiler_dir, seen, progress, compact)
  local current_dir = dirname(current_file)
  local stdlib_dir = join_path(compiler_dir, "stdlib")

  for _, stmt in ipairs(ast.body or {}) do
    if stmt.kind == "ImportDecl" then
      local import_path = stmt.path

      if import_path:match("^sino%.") then
        local runtime_name = import_path:match("^sino%.(.+)$")
        local std_src = join_path(stdlib_dir, runtime_name .. ".lua")

        if not file_exists(std_src) then
          error("stdlib module not found: " .. import_path)
        end

        stmt.resolvedRequire = import_path
        stmt.runtimeModule = runtime_name

      else
        local module_path = module_to_path(import_path)

        local sin_path = join_path(current_dir, module_path .. ".sin")
        local lua_path = join_path(current_dir, module_path .. ".lua")
        local std_path = join_path(stdlib_dir, import_path .. ".lua")

        if file_exists(sin_path) then
          compile_file(sin_path, compiler_dir, seen, progress, compact)
          stmt.resolvedRequire = import_path

        elseif file_exists(lua_path) then
          stmt.resolvedRequire = import_path

        elseif file_exists(std_path) then
          stmt.resolvedRequire = "sino." .. import_path
          stmt.runtimeModule = import_path

        else
          error("cannot resolve import '" .. import_path .. "' from " .. current_file)
        end
      end
    end
  end
end

--
-- collect imports
--

local function collect_imports(path, seen, out)
  seen = seen or {}
  out = out or {}

  if seen[path] then
    return out
  end

  seen[path] = true
  out[#out + 1] = path

  local source = read_file(path)

  local Lexer = lexer_mod.Lexer
  local lexer = Lexer.new(source, path)
  local tokens = run_phase("lexer", path, function()
    return lexer:tokenize()
  end)


  local Parser = parser_mod.Parser
  local parser = Parser.new(tokens, path, source)
  local ast = run_phase("parser", path, function()
    return parser:parse()
  end)

  local current_dir = dirname(path)

  for _, stmt in ipairs(ast.body or {}) do
    if stmt.kind == "ImportDecl" and not stmt.path:match("^sino%.") then
      local sin_path =
        join_path(current_dir, module_to_path(stmt.path) .. ".sin")

      if file_exists(sin_path) then
        collect_imports(sin_path, seen, out)
      end
    end
  end

  return out
end

--
-- clean parsing
--

local function parse_clean_arg(value)
  if value == "--clean" then
    return {
      lua = true,
      ast = true,
      tokens = true,
      runtime = true,
    }
  end

  local list = value and value:match("^%-%-clean=(.+)$")
  if not list then
    return nil
  end

  local out = {}

  for part in list:gmatch("[^,]+") do
    part = part:match("^%s*(.-)%s*$")

    if part == "lua" then
      out.lua = true
    elseif part == "ast" then
      out.ast = true
    elseif part == "tokens" then
      out.tokens = true
    elseif part == "runtime" or part == "sino" then
      out.runtime = true
    elseif part == "all" then
      out.lua = true
      out.ast = true
      out.tokens = true
      out.runtime = true
    else
      error("unknown clean target: " .. part)
    end
  end

  return out
end

--
-- args
--

--
-- cli args
--

local function print_usage()
  print([[
Sino - modern syntax for Lua

Usage:
  sino <file.sin>
  sino build <file.sin> [--progress] [--silent]
  sino run <file.sin> [--silent]
  sino clean <file.sin> [--silent]
  sino clean <file.sin> --clean=lua,ast,tokens,runtime

Options:
  --progress              Write .tokens and .ast debug files
  --silent                Suppress normal output
  --clean                 Remove lua, ast, tokens, and runtime output
  --clean=<targets>       Remove selected outputs
                           targets: lua, ast, tokens, runtime, all

Examples:
  sino hello.sin
  sino build hello.sin
  sino run hello.sin
  sino clean hello.sin
  sino clean hello.sin --clean=lua,tokens
]])
end

local function has_arg(name)
  for i = 1, #arg do
    if arg[i] == name then
      return true
    end
  end
  return false
end

local function find_clean_arg()
  for i = 1, #arg do
    local value = arg[i]
    if value == "--clean" or value:match("^%-%-clean=") then
      return value
    end
  end
  return nil
end

local function find_first_sin_arg(start_index)
  for i = start_index or 1, #arg do
    local value = arg[i]
    if value and value:match("%.sin$") then
      return value
    end
  end
  return nil
end

local command = arg[1]

if not command or command == "--help" or command == "-h" then
  print_usage()
  os.exit(command and 0 or 1)
end

local silent = has_arg("--silent")
local progress = has_arg("--progress")
local compact = has_arg("--compact")


if not silent then
  print("sino started")
end

local mode
local path

if command == "build" then
  mode = "build"
  path = find_first_sin_arg(2)

elseif command == "run" then
  mode = "run"
  path = find_first_sin_arg(2)

elseif command == "clean" then
  mode = "clean"
  path = find_first_sin_arg(2)

elseif command:match("%.sin$") then
  -- Backward-compatible:
  --   sino file.sin
  mode = "build"
  path = command

elseif command == "version" or command == "--version" or command == "-v" then
  print("Sino " .. SINO_VERSION)
  os.exit(0)

else
  io.stderr:write("unknown command: " .. tostring(command) .. "\n\n")
  print_usage()
  os.exit(1)
end

if not path then
  io.stderr:write("missing input file\n\n")
  print_usage()
  os.exit(1)
end

if not path:match("%.sin$") then
  io.stderr:write("input file must end with .sin\n")
  os.exit(1)
end

if path:match("main%.sin$") then
  io.stderr:write("warning: it is recommended not to name your entry file 'main.sin'\n")
end

if mode == "clean" then
  local clean = parse_clean_arg(find_clean_arg() or "--clean")

  if not clean then
    io.stderr:write("invalid clean argument\n")
    print_usage()
    os.exit(1)
  end

  local files = collect_imports(path, {}, {})
  local root_dir = dirname(path)

  if clean.runtime then
    local runtime_dir = join_path(root_dir, "sino")
    remove_dir(runtime_dir)
    if not silent then
      print("removed:", runtime_dir)
    end
  end

  for _, sin_file in ipairs(files) do
    if clean.lua then
      local file = sin_file:gsub("%.sin$", ".lua")
      if file_exists(file) then
        remove_file(file)
        if not silent then
          print("removed:", file)
        end
      end
    end

    if clean.ast then
      local file = sin_file:gsub("%.sin$", ".ast")
      if file_exists(file) then
        remove_file(file)
        if not silent then
          print("removed:", file)
        end
      end
    end

    if clean.tokens then
      local file = sin_file:gsub("%.sin$", ".tokens")
      if file_exists(file) then
        remove_file(file)
        if not silent then
          print("removed:", file)
        end
      end
    end
  end

  os.exit(0)
end

local out_file = compile_file(path, compiler_dir, {}, progress, compact)

if not silent then
  print("compiled:", out_file)
end

if mode == "run" then
  if not silent then
    print("running:", out_file)
  end

  local lua_cmd = os.getenv("SINO_LUA") or "lua"
  local cmd = lua_cmd .. ' "' .. out_file .. '"'

  local ok = os.execute(cmd)

  if ok ~= true and ok ~= 0 then
    os.exit(1)
  end
end