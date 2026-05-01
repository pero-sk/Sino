local TokenKind = require("lexer").TokenKind

local Validator = {}
Validator.__index = Validator

local DIRECTIVES = {
  allow = true,
  deprecated = true,
}

local ALLOWED_PERMISSIONS = {
  Internal = true,
  RefCursing = true,
  RawLua = true,
}

local ATTACHABLE_DECLS = {
  ClassDecl = true,
  MethodDecl = true,
  VarDecl = true,
  ImportDecl = true,
  ExportDecl = true,
}

local INTERNAL_NAMES = {
  __sino = true,
}

local INTERNAL_FIELDS = {
  __fields = true,
  __methods = true,
  __class = true,
  __ref = true,
}

local BUILTIN_TYPES = {
  any = true,
  int = true,
  number = true,
  string = true,
  bool = true,
  ["nil"] = true,
  table = true,
}

local function source_error(kind, node, filename, message)
  error({
    kind = kind or "CompileError",
    filename = filename,
    start = node and node.start or { line = 1, column = 1 },
    finish = node and node.finish,
    message = message,
  })
end

local function make_type(name)
  return {
    name = name or "unknown",
  }
end

local function type_name(t)
  if not t then
    return "unknown"
  end

  return t.name or tostring(t)
end

local function is_numeric_type(t)
  local name = t and t.name or "unknown"
  return name == "unknown" or name == "int" or name == "number"
end

local function is_assignable(expected, actual)
  expected = expected and expected.name or "unknown"
  actual = actual and actual.name or "unknown"

  if expected == "any" then
    return true
  end

  if actual == "unknown" then
    return true
  end

  if expected == actual then
    return true
  end

  if expected == "number" and actual == "int" then
    return true
  end

  return false
end

local function new(filename)
  return setmetatable({
    filename = filename or "<stdin>",
    allows = {},
    pendingDirectives = {},
    currentReturnType = nil,
    currentClassName = nil,
    warnings = {},
    scopes = { {} },
  }, Validator)
end

function Validator:has(permission)
  return self.allows[permission] == true
end

function Validator:push_scope()
  self.scopes[#self.scopes + 1] = {}
end

function Validator:pop_scope()
  self.scopes[#self.scopes] = nil
end

function Validator:declare(name, info)
  if not name then
    return
  end

  info = info or {}

  self.scopes[#self.scopes][name] = {
    deprecated = info.deprecated == true,
    message = info.message,
    type = info.type or make_type("unknown"),
    kind = info.kind,
  }
end

function Validator:resolve(name)
  for i = #self.scopes, 1, -1 do
    local found = self.scopes[i][name]
    if found then
      return found
    end
  end

  return nil
end

function Validator:warn(node, message)
  self.warnings[#self.warnings + 1] = {
    filename = self.filename,
    start = node and node.start or { line = 1, column = 1 },
    message = message,
  }
end

function Validator:info_from_directives(stmt)
  local info = {
    deprecated = false,
    message = nil,
  }

  if stmt.directives then
    for _, dir in ipairs(stmt.directives) do
      if dir.name == "deprecated" then
        info.deprecated = true
        info.message = dir.message
      end
    end
  end

  return info
end

function Validator:type_from_annotation(ann)
  if not ann then
    return make_type("unknown")
  end

  local name = ann.name

  if name == "Self" then
    if not self.currentClassName then
      source_error(
        "TypeError",
        ann,
        self.filename,
        "'Self' can only be used inside a class"
      )
    end

    return make_type(self.currentClassName)
  end

  if BUILTIN_TYPES[name] then
    return make_type(name)
  end

  if self:resolve(name) then
    return make_type(name)
  end

  source_error(
    "TypeError",
    ann,
    self.filename,
    "unknown type '" .. tostring(name) .. "'"
  )
end

function Validator:infer_expr_type(expr)
  if not expr then
    return make_type("unknown")
  end

  if expr.kind == "Literal" then
    local v = expr.value

    if type(v) == "number" then
      if math.type and math.type(v) == "integer" then
        return make_type("int")
      end

      return make_type("number")
    end

    if type(v) == "string" then
      return make_type("string")
    end

    if type(v) == "boolean" then
      return make_type("bool")
    end

    if v == nil then
      return make_type("nil")
    end
  end

  if expr.kind == "Identifier" then
    local resolved = self:resolve(expr.name)
    return resolved and resolved.type or make_type("unknown")
  end

  if expr.kind == "SelfExpr" then
    if self.currentClassName then
      return make_type(self.currentClassName)
    end

    return make_type("unknown")
  end

  if expr.kind == "GroupExpr" then
    return self:infer_expr_type(expr.expression)
  end

  if expr.kind == "UnaryExpr" then
    local inner = self:infer_expr_type(expr.expression)

    if expr.op == TokenKind.MINUS then
      if not is_numeric_type(inner) then
        source_error(
          "TypeError",
          expr,
          self.filename,
          "unary '-' expects number, got " .. type_name(inner)
        )
      end

      return inner
    end

    if expr.op == TokenKind.KW_NOT then
      return make_type("bool")
    end
  end

  if expr.kind == "BinaryExpr" then
    local left = self:infer_expr_type(expr.left)
    local right = self:infer_expr_type(expr.right)
    local op = expr.op

    if op == TokenKind.PLUS
        or op == TokenKind.MINUS
        or op == TokenKind.STAR
        or op == TokenKind.SLASH
        or op == TokenKind.PERCENT
        or op == TokenKind.CARET then
      if not is_numeric_type(left) then
        source_error(
          "TypeError",
          expr.left,
          self.filename,
          "left operand must be number, got " .. type_name(left)
        )
      end

      if not is_numeric_type(right) then
        source_error(
          "TypeError",
          expr.right,
          self.filename,
          "right operand must be number, got " .. type_name(right)
        )
      end

      if op == TokenKind.SLASH then
        return make_type("number")
      end

      if left.name == "number" or right.name == "number" then
        return make_type("number")
      end

      return make_type("int")
    end

    if op == TokenKind.CONCAT then
      return make_type("string")
    end

    if op == TokenKind.EQ
        or op == TokenKind.NE
        or op == TokenKind.LT
        or op == TokenKind.LTE
        or op == TokenKind.GT
        or op == TokenKind.GTE
        or op == TokenKind.KW_AND
        or op == TokenKind.KW_OR then
      return make_type("bool")
    end
  end

  if expr.kind == "CallExpr" then
    if expr.callee.kind == "Identifier" then
      local resolved = self:resolve(expr.callee.name)

      if resolved and resolved.kind == "class" then
        return make_type(expr.callee.name)
      end
    end

    if expr.callee.kind == "SelfExpr" then
      if self.currentClassName then
        return make_type(self.currentClassName)
      end
    end

    return make_type("unknown")
  end

  if expr.kind == "TableLiteral" then
    return make_type("table")
  end

  return make_type("unknown")
end

function Validator:validate_program(ast)
  for _, stmt in ipairs(ast.body or {}) do
    if stmt.kind == "DebugScriptStmt" then
      self:validate_debug_script(stmt)
    else
      self:attach_pending_directives(stmt)
      self:validate_stmt(stmt)
    end
  end

  if #self.pendingDirectives > 0 then
    local dir = self.pendingDirectives[#self.pendingDirectives]
    source_error(
      "CompileError",
      dir,
      self.filename,
      "directive @" .. tostring(dir.name) .. " must be placed before a declaration"
    )
  end
end

function Validator:validate_stmt(stmt)
  if type(stmt) ~= "table" then
    return
  end

  if stmt.kind == "LuaBlockStmt" then
    if not self:has("RawLua") then
      source_error(
        "SafetyError",
        stmt,
        self.filename,
        "raw Lua blocks require @allow(RawLua)"
      )
    end

    return
  end

  self:validate_node(stmt)
end

function Validator:attach_pending_directives(stmt)
  if #self.pendingDirectives == 0 then
    return
  end

  if not ATTACHABLE_DECLS[stmt.kind] then
    local dir = self.pendingDirectives[#self.pendingDirectives]

    source_error(
      "CompileError",
      dir,
      self.filename,
      "directive @" .. tostring(dir.name) .. " must be placed before a declaration"
    )
  end

  stmt.directives = stmt.directives or {}

  for _, dir in ipairs(self.pendingDirectives) do
    stmt.directives[#stmt.directives + 1] = dir
  end

  self.pendingDirectives = {}
end

function Validator:validate_debug_script(stmt)
  if not DIRECTIVES[stmt.name] then
    source_error(
      "CompileError",
      stmt,
      self.filename,
      "unknown directive '@" .. tostring(stmt.name) .. "'"
    )
  end

  if stmt.name == "allow" then
    return self:validate_allow_directive(stmt)
  end

  if stmt.name == "deprecated" then
    return self:validate_deprecated_directive(stmt)
  end
end

function Validator:validate_allow_directive(stmt)
  if #stmt.args ~= 1 then
    source_error(
      "CompileError",
      stmt,
      self.filename,
      "@allow expects exactly one permission"
    )
  end

  local arg = stmt.args[1]

  if arg.kind ~= "Identifier" then
    source_error(
      "CompileError",
      arg,
      self.filename,
      "argument to @allow must be an identifier"
    )
  end

  local permission = arg.name

  if not ALLOWED_PERMISSIONS[permission] then
    source_error(
      "CompileError",
      arg,
      self.filename,
      "unknown debug script permission '" .. tostring(permission) .. "'"
    )
  end

  self.allows[permission] = true
end

function Validator:validate_deprecated_directive(stmt)
  if #stmt.args ~= 1 then
    source_error(
      "CompileError",
      stmt,
      self.filename,
      "@deprecated expects exactly one message string"
    )
  end

  local arg = stmt.args[1]

  if arg.kind ~= "Literal" or type(arg.value) ~= "string" then
    source_error(
      "CompileError",
      arg,
      self.filename,
      "argument to @deprecated must be a string"
    )
  end

  stmt.message = arg.value
  self.pendingDirectives[#self.pendingDirectives + 1] = stmt
end

function Validator:validate_node(node)
  if type(node) ~= "table" then
    return
  end

  if node.kind == "Identifier" then
    self:validate_identifier(node)
    return
  end

  if node.kind == "MemberExpr" then
    self:validate_member_expr(node)
  elseif node.kind == "TableLiteral" then
    self:validate_table_literal(node)
  end

  if node.kind == "ClassDecl" then
    local info = self:info_from_directives(node)
    info.type = make_type("type")
    info.kind = "class"

    self:declare(node.name, info)

    local previous_class_name = self.currentClassName
    self.currentClassName = node.name

    self:push_scope()

    for _, member in ipairs(node.members or {}) do
      self:validate_stmt(member)
    end

    self:pop_scope()

    self.currentClassName = previous_class_name
    return
  end

  if node.kind == "MethodDecl" then
    local return_type = node.returnType
      and self:type_from_annotation(node.returnType)
      or make_type("unknown")

    local info = self:info_from_directives(node)
    info.kind = "function"
    info.type = return_type

    self:declare(node.name, info)

    local previous_return_type = self.currentReturnType
    self.currentReturnType = return_type

    self:push_scope()

    self:declare("self", {
      type = self.currentClassName and make_type(self.currentClassName) or make_type("unknown"),
    })

    for _, param in ipairs(node.params or {}) do
      if param.name then
        local param_type = param.typeAnnotation
          and self:type_from_annotation(param.typeAnnotation)
          or make_type("unknown")

        self:declare(param.name, {
          type = param_type,
        })
      end
    end

    for _, stmt in ipairs(node.body or {}) do
      self:validate_stmt(stmt)
    end

    self:pop_scope()

    self.currentReturnType = previous_return_type
    return
  end

  if node.kind == "VarDecl" then
    self:validate_node(node.init)

    local explicit_type = node.typeAnnotation
      and self:type_from_annotation(node.typeAnnotation)
      or nil

    local init_type = self:infer_expr_type(node.init)

    if explicit_type and not is_assignable(explicit_type, init_type) then
      source_error(
        "TypeError",
        node,
        self.filename,
        "cannot assign " .. type_name(init_type) .. " to variable of type " .. type_name(explicit_type)
      )
    end

    local declared_type = explicit_type or init_type

    if node.name then
      local info = self:info_from_directives(node)
      info.type = declared_type
      info.kind = "variable"

      self:declare(node.name, info)
    end

    return
  end

  if node.kind == "ImportDecl" then
    local info = self:info_from_directives(node)
    info.kind = "import"
    info.type = make_type("unknown")

    self:declare(node.name, info)
    return
  end

  if node.kind == "ReturnStmt" then
    for _, value in ipairs(node.values or {}) do
      self:validate_node(value)
    end

    if self.currentReturnType and self.currentReturnType.name ~= "unknown" then
      if #(node.values or {}) == 0 then
        source_error(
          "TypeError",
          node,
          self.filename,
          "expected return value of type " .. type_name(self.currentReturnType)
        )
      end

      local actual = self:infer_expr_type(node.values[1])

      if not is_assignable(self.currentReturnType, actual) then
        source_error(
          "TypeError",
          node,
          self.filename,
          "cannot return " .. type_name(actual) .. " from function returning " .. type_name(self.currentReturnType)
        )
      end
    end

    return
  end

  for k, v in pairs(node) do
    if k ~= "start"
      and k ~= "finish"
      and k ~= "token"
      and k ~= "firstToken"
      and k ~= "lastToken"
      and k ~= "nameToken"
      and k ~= "pathToken"
      and k ~= "opToken"
      and k ~= "keyToken"
      and k ~= "directives"
      and k ~= "typeAnnotation"
      and k ~= "returnType"
    then
      if type(v) == "table" then
        if v.kind then
          self:validate_stmt(v)
        else
          for _, item in ipairs(v) do
            self:validate_stmt(item)
          end
        end
      end
    end
  end
end

function Validator:validate_identifier(node)
  if INTERNAL_NAMES[node.name] and not self:has("Internal") then
    source_error(
      "SafetyError",
      node,
      self.filename,
      "identifier '" .. node.name .. "' is reserved; use @allow(Internal)"
    )
  end

  local resolved = self:resolve(node.name)

  if resolved and resolved.deprecated then
    self:warn(
      node,
      "'" .. node.name .. "' is deprecated: " .. resolved.message
    )
  end
end

function Validator:validate_member_expr(node)
  if INTERNAL_FIELDS[node.name] and not self:has("Internal") then
    source_error(
      "SafetyError",
      node,
      self.filename,
      "field '" .. node.name .. "' is reserved; use @allow(Internal)"
    )
  end
end

function Validator:validate_table_literal(node)
  for _, entry in ipairs(node.entries or {}) do
    if entry.kind == "TableFieldEntry"
        and entry.key == "__ref"
        and not self:has("RefCursing")
    then
      source_error(
        "SafetyError",
        entry,
        self.filename,
        "manual ref layout requires @allow(RefCursing)"
      )
    end
  end
end

function Validator.validate(ast, filename)
  local validator = new(filename)
  validator:validate_program(ast)

  for _, w in ipairs(validator.warnings) do
    io.stderr:write(string.format(
      "%s:%d:%d: Warning: %s\n",
      w.filename,
      w.start and w.start.line or 1,
      w.start and w.start.column or 1,
      w.message
    ))
  end

  return true
end

return {
  Validator = Validator,
}