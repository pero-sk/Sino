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

local function source_error(kind, node, filename, message)
  error({
    kind = kind or "CompileError",
    filename = filename,
    start = node and node.start or { line = 1, column = 1 },
    finish = node and node.finish,
    message = message,
  })
end

local function new(filename)
  return setmetatable({
    filename = filename or "<stdin>",
    allows = {},
    pendingDirectives = {},
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

  self.scopes[#self.scopes][name] = info or {
    deprecated = false,
    message = nil,
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
    start = node.start,
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
        "CompileError",
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

  if node.kind == "MethodDecl" then
    self:declare(node.name, self:info_from_directives(node))

    self:push_scope()

    for _, param in ipairs(node.params or {}) do
      if param.name then
        self:declare(param.name)
      end
    end

    for _, stmt in ipairs(node.body or {}) do
      self:validate_stmt(stmt)
    end

    self:pop_scope()
    return
  end

  if node.kind == "ClassDecl" then
    self:declare(node.name, self:info_from_directives(node))

    self:push_scope()

    for _, member in ipairs(node.members or {}) do
      self:validate_stmt(member)
    end

    self:pop_scope()
    return
  end

  if node.kind == "VarDecl" then
    self:validate_node(node.init)

    if node.name then
      self:declare(node.name, self:info_from_directives(node))
    end

    return
  end

  if node.kind == "ImportDecl" then
    self:declare(node.name, self:info_from_directives(node))
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
      "CompileError",
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
      "CompileError",
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
        "CompileError",
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