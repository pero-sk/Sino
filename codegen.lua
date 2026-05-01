local Codegen = {}
Codegen.__index = Codegen

local function indent(level)
  return string.rep("  ", level)
end

local function quote_string(value)
  return string.format("%q", value)
end

local function dedent_block(source)
  source = source:gsub("\r\n", "\n")

  -- trim leading/trailing blank lines
  source = source:gsub("^%s*\n", "")
  source = source:gsub("\n%s*$", "")

  local min_indent = nil

  for line in (source .. "\n"):gmatch("(.-)\n") do
    if line:match("%S") then
      local indent = line:match("^(%s*)")
      local count = #indent

      if min_indent == nil or count < min_indent then
        min_indent = count
      end
    end
  end

  if not min_indent or min_indent == 0 then
    return source
  end

  local out = {}

  for line in (source .. "\n"):gmatch("(.-)\n") do
    if #line >= min_indent then
      out[#out + 1] = line:sub(min_indent + 1)
    else
      out[#out + 1] = line
    end
  end

  return table.concat(out, "\n")
end

function Codegen.new()
  local self = setmetatable({}, Codegen)
  self.lines = {}
  self.indent_level = 0
  self.current_class = nil
  self.used_runtime = {}
  return self
end

function Codegen:use_runtime(name)
  self.used_runtime[name] = true
end

function Codegen:emit(line)
  if line == nil or line == "" then
    self.lines[#self.lines + 1] = ""
  else
    self.lines[#self.lines + 1] = indent(self.indent_level) .. line
  end
end

function Codegen:push_indent()
  self.indent_level = self.indent_level + 1
end

function Codegen:pop_indent()
  self.indent_level = self.indent_level - 1
  if self.indent_level < 0 then
    self.indent_level = 0
  end
end

function Codegen.generate(ast)
  local gen = Codegen.new()
  gen:gen_program(ast)
  return table.concat(gen.lines, "\n"), gen.used_runtime
end

function Codegen:gen_program(ast)
  if ast.kind ~= "Program" then
    error("codegen expected Program node, got " .. tostring(ast.kind))
  end

  self:use_runtime("keyhelper")

  if self.used_runtime.keyhelper then
    self:emit('local __sino = require("sino.keyhelper")')
    self:emit("")
  end

  for i, stmt in ipairs(ast.body or {}) do
    self:gen_top_level(stmt)
    if i < #(ast.body or {}) then
      self:emit("")
    end
  end
end

function Codegen:gen_top_level(stmt)
  if stmt.kind == "ClassDecl" then
    self:gen_class_decl(stmt)
  elseif stmt.kind == "VarDecl" then
    self:gen_var_decl(stmt)
  elseif stmt.kind == "MethodDecl" then
    self:gen_function_decl(stmt)
  elseif stmt.kind == "ImportDecl" then
    self:gen_import_decl(stmt)
  elseif stmt.kind == "ExprStmt"
      or stmt.kind == "AssignStmt"
      or stmt.kind == "RefAssignStmt"
      or stmt.kind == "LuaBlockStmt"
      or stmt.kind == "IfStmt"
      or stmt.kind == "WhileStmt"
      or stmt.kind == "ForStmt"
      or stmt.kind == "ReturnStmt" then
    self:gen_statement(stmt)
  elseif stmt.kind == "ExportDecl" then
    self:gen_export_decl(stmt)
  elseif stmt.kind == "DebugScriptStmt" then
    return
  elseif stmt.kind == "CompoundAssignStmt" then
    self:emit_compound_assign(stmt)
  else
    error("unsupported top-level node: " .. tostring(stmt.kind))
  end
end

function Codegen:emit_compound_assign(stmt)
  local target = self:gen_expr(stmt.target)
  local value = self:gen_expr(stmt.value)
  local op = self:lua_binary_op(stmt.op)

  self:emit(target .. " = " .. target .. " " .. op .. " (" .. value .. ")")
end

function Codegen:gen_import_decl(stmt)
  local require_path = stmt.resolvedRequire or stmt.path

  if stmt.runtimeModule then
    self:use_runtime(stmt.runtimeModule)
  end

  self:emit("local " .. stmt.name .. " = require(" .. quote_string(require_path) .. ")")
end

function Codegen:gen_export_decl(stmt)
  if stmt.value.kind == "TableLiteral" then
    self:emit("return {")
    self:push_indent()
    self:emit("__fields = " .. self:gen_table_literal(stmt.value) .. ",")
    self:pop_indent()
    self:emit("}")
    return
  end

  self:emit("return " .. self:gen_expr(stmt.value))
end

function Codegen:gen_class_decl(class)
  local previous_class = self.current_class
  self.current_class = class

  local class_name = class.name
  local base_name = class.base and class.base.name or nil

  self:emit("local " .. class_name .. " = {}")
  self:emit(class_name .. ".__name = " .. quote_string(class_name))
  self:emit(class_name .. ".__class = " .. class_name)
  self:gen_class_fields_metadata(class)
  self:emit(class_name .. ".__methods = {__static={}}")

  if base_name then
    self:emit(class_name .. ".__super = " .. base_name)
  end

  self:emit("")

  local constructor = nil

  for _, member in ipairs(class.members or {}) do
    if member.kind == "MethodDecl"
        and member.receiverKind == "self_class"
        and member.name == "new" then
      constructor = member
      break
    end
  end

  for _, member in ipairs(class.members or {}) do
    if member.kind == "FieldDecl" then
      -- Fields are emitted as metadata and initialized into instance.__fields.
    elseif member.kind == "MethodDecl" then
      self:gen_class_method(class, member)
      self:emit("")
    elseif member.kind == "MetaDecl" then
      self:gen_meta_method(class, member)
      self:emit("")
    else
      error("unsupported class member: " .. tostring(member.kind))
    end
  end

  self:gen_class_call_ctor(class, constructor)
  self:emit("")
  self:gen_class_init_fields(class)
  self:emit("")
  self:gen_class_metatable(class, base_name)

  self.current_class = previous_class
end

function Codegen:gen_class_fields_metadata(class)
  self:emit(class.name .. ".__fields = {")
  self:push_indent()

  for _, member in ipairs(class.members or {}) do
    if member.kind == "FieldDecl" then
      local default = "nil"
      if member.defaultValue then
        default = self:gen_expr(member.defaultValue)
      end

      self:emit(member.name .. " = { default = " .. default .. " },")
    end
  end

  self:pop_indent()
  self:emit("}")
end

function Codegen:gen_class_method(class, method)
  local previous_method = self.current_method
  self.current_method = method

  local class_name = class.name

  local params, prologue = self:gen_param_list_with_prologue(method.params)

  local receiver_param

  if method.receiverKind == "self_class" and method.name ~= "new" then
    receiver_param = "Self"
  else
    receiver_param = "self"
  end

  if params ~= "" then
    params = receiver_param .. ", " .. params
  else
    params = receiver_param
  end

  local method_table = class_name .. ".__methods"

  if method.isStatic then
    method_table = method_table .. ".__static"
  end

  self:emit("function " .. method_table .. "." .. method.name .. "(" .. params .. ")")

  self:push_indent()
  for _, line in ipairs(prologue) do
    self:emit(line)
  end
  self:gen_statements(method.body or {})
  self:pop_indent()

  self:emit("end")

  self.current_method = previous_method
end

function Codegen:gen_meta_method(class, method)
  local class_name = class.name
  local params, prologue = self:gen_param_list_with_prologue(method.params)

  if params ~= "" then
    params = "self, " .. params
  else
    params = "self"
  end

  self:emit("function " .. class_name .. ".__methods." .. method.name .. "(" .. params .. ")")
  self:push_indent()
  for _, line in ipairs(prologue) do
    self:emit(line)
  end
  self:gen_statements(method.body or {})
  self:pop_indent()
  self:emit("end")
end

function Codegen:gen_class_call_ctor(class, constructor)
  local class_name = class.name
  local base_name = class.base and class.base.name or nil

  self:emit("function " .. class_name .. ".__call_ctor(...)")
  self:push_indent()

  self:emit("local self = {")
  self:push_indent()
  self:emit("__class = " .. class_name .. ",")
  self:emit("__fields = {},")
  self:pop_indent()
  self:emit("}")

  self:emit(class_name .. ".__init_fields(self)")

  if constructor then
    self:emit(class_name .. ".__methods.__static.new(self, ...)")
  elseif base_name then
    self:emit('local base_new = __sino.get_method(' .. base_name .. ', "new")')
    self:emit("base_new(self, ...)")
  end

  self:emit("return self")
  self:pop_indent()
  self:emit("end")
end

function Codegen:gen_class_init_fields(class)
  local class_name = class.name
  local base_name = class.base and class.base.name or nil

  self:emit("function " .. class_name .. ".__init_fields(self)")
  self:push_indent()

  if base_name then
    self:emit("if " .. base_name .. ".__init_fields then")
    self:push_indent()
    self:emit(base_name .. ".__init_fields(self)")
    self:pop_indent()
    self:emit("end")
  end

  self:gen_field_defaults(class)

  self:pop_indent()
  self:emit("end")
end

function Codegen:gen_field_defaults(class)
  for _, member in ipairs(class.members or {}) do
    if member.kind == "FieldDecl" and member.defaultValue then
      self:emit("self.__fields." .. member.name .. " = " .. self:gen_expr(member.defaultValue))
    end
  end
end

function Codegen:gen_class_metatable(class, base_name)
  local class_name = class.name

  self:emit("setmetatable(" .. class_name .. ", {")
  self:push_indent()

  if base_name then
    self:emit("__index = " .. base_name .. ",")
  end

  self:emit("__call = function(_, ...)")
  self:push_indent()
  self:emit("return " .. class_name .. ".__call_ctor(...)")
  self:pop_indent()
  self:emit("end")

  self:pop_indent()
  self:emit("})")
end

function Codegen:gen_param_list(params)
  local out = {}

  for _, param in ipairs(params or {}) do
    if param.pattern and param.pattern.kind == "IdentifierPattern" then
      out[#out + 1] = param.pattern.name
    elseif param.pattern and param.pattern.kind == "ObjectPattern" then
      out[#out + 1] = self:fresh_temp("__param")
    else
      out[#out + 1] = param.name
    end
  end

  return table.concat(out, ", ")
end

function Codegen:gen_param_list_with_prologue(params)
  local names = {}
  local prologue = {}

  for _, param in ipairs(params or {}) do
    local pattern = param.pattern

    if pattern and pattern.kind == "IdentifierPattern" then
      names[#names + 1] = pattern.name

    elseif pattern and pattern.kind == "ObjectPattern" then
      local tmp = self:fresh_temp("__param")
      names[#names + 1] = tmp

      prologue[#prologue + 1] = "local " .. tmp .. "_fields = " .. tmp .. ".__fields or " .. tmp

      for _, field in ipairs(pattern.fields or {}) do
        prologue[#prologue + 1] =
          "local " .. field.name .. " = " .. tmp .. "_fields." .. field.key
      end

    else
      names[#names + 1] = param.name
    end
  end

  return table.concat(names, ", "), prologue
end

function Codegen:gen_statements(statements)
  for _, stmt in ipairs(statements or {}) do
    self:gen_statement(stmt)
  end
end

function Codegen:gen_statement(stmt)
  if stmt.kind == "AssignStmt" then
    self:emit(self:gen_expr(stmt.target) .. " = " .. self:gen_expr(stmt.value))
  elseif stmt.kind == "RefAssignStmt" then
    self:emit(self:gen_expr(stmt.target) .. ".value = " .. self:gen_expr(stmt.value))
  elseif stmt.kind == "ReturnStmt" then
    self:gen_return_stmt(stmt)
  elseif stmt.kind == "VarDecl" then
    self:gen_var_decl(stmt)
  elseif stmt.kind == "ExprStmt" then
    self:emit(self:gen_expr(stmt.expression))
  elseif stmt.kind == "LuaBlockStmt" then
    self:gen_lua_block(stmt)
  elseif stmt.kind == "IfStmt" then
    self:gen_if_stmt(stmt)
  elseif stmt.kind == "WhileStmt" then
    self:gen_while_stmt(stmt)
  elseif stmt.kind == "ForStmt" then
    self:gen_for_stmt(stmt)
  elseif stmt.kind == "ContinueStmt" then
    self:emit("goto __continue")
  elseif stmt.kind == "BreakStmt" then
    self:emit("break")
  else
    error("unsupported statement node: " .. tostring(stmt.kind))
  end
end

function Codegen:gen_var_decl(stmt)
  if stmt.pattern then
    return self:gen_var_pattern_decl(stmt)
  end

  -- old fallback
  if stmt.isRef then
    self:emit("local " .. stmt.name .. " = __sino.ref(" .. self:gen_expr(stmt.init) .. ")")
  else
    self:emit("local " .. stmt.name .. " = " .. self:gen_expr(stmt.init))
  end
end

function Codegen:gen_var_pattern_decl(stmt)
  if stmt.pattern.kind == "IdentifierPattern" then
    if stmt.isRef then
      self:emit("local " .. stmt.pattern.name .. " = __sino.ref(" .. self:gen_expr(stmt.init) .. ")")
    else
      self:emit("local " .. stmt.pattern.name .. " = " .. self:gen_expr(stmt.init))
    end
    return
  end

  if stmt.pattern.kind == "ObjectPattern" then
    if stmt.isRef then
      error("destructuring with ':=' refs is not supported yet")
    end

    local tmp = self:fresh_temp("__destructure")
    self:emit("local " .. tmp .. " = " .. self:gen_expr(stmt.init))
    self:emit(tmp .. " = " .. tmp .. ".__fields or " .. tmp)

    for _, field in ipairs(stmt.pattern.fields or {}) do
      self:emit("local " .. field.name .. " = " .. tmp .. "." .. field.key)
    end

    return
  end

  error("unsupported var pattern: " .. tostring(stmt.pattern.kind))
end

function Codegen:fresh_temp(prefix)
  self.temp_id = (self.temp_id or 0) + 1
  return prefix .. "_" .. tostring(self.temp_id)
end

function Codegen:gen_function_decl(method)
  local params, prologue = self:gen_param_list_with_prologue(method.params)

  self:emit("local function " .. method.name .. "(" .. params .. ")")
  self:push_indent()
  for _, line in ipairs(prologue) do
    self:emit(line)
  end
  self:gen_statements(method.body or {})
  self:pop_indent()
  self:emit("end")
end

function Codegen:gen_for_stmt(stmt)
  local var = stmt.variable
  local iterable = self:gen_expr(stmt.iterable)
  local iter_name = self:fresh_temp("__iter")

  self:emit("local " .. iter_name .. " = " .. iterable)
  self:emit("for __index, " .. var .. " in ipairs(" .. iter_name .. ".__fields or " .. iter_name .. ") do")
  self:push_indent()
  self:gen_statements(stmt.body or {})
  self:emit("::__continue::")
  self:pop_indent()
  self:emit("end")
end

function Codegen:gen_if_stmt(stmt)
  local condition = self:gen_expr(stmt.condition)
  self:emit("if " .. condition .. " then")
  self:push_indent()
  self:gen_statements(stmt.thenBranch or {})
  self:pop_indent()

  if stmt.elseifBranches then
    for _, elif in ipairs(stmt.elseifBranches) do
      local elseif_condition = self:gen_expr(elif.condition)
      self:emit("elseif " .. elseif_condition .. " then")
      self:push_indent()
      self:gen_statements(elif.branch or {})
      self:pop_indent()
    end
  end

  if stmt.elseBranch then
    self:emit("else")
    self:push_indent()
    self:gen_statements(stmt.elseBranch or {})
    self:pop_indent()
  end

  self:emit("end")
end

function Codegen:gen_while_stmt(stmt)
  local condition = self:gen_expr(stmt.condition)
  self:emit("while " .. condition .. " do")
  self:push_indent()
  self:gen_statements(stmt.body or {})
  self:emit("::__continue::")
  self:pop_indent()
  self:emit("end")
end

function Codegen:gen_lua_block(stmt)
  local source = dedent_block(stmt.source)
  local pad = string.rep("  ", self.indent_level)

  for line in (source .. "\n"):gmatch("(.-)\n") do
    self.lines[#self.lines + 1] = pad .. line
  end
end

function Codegen:gen_return_stmt(stmt)
  local values = {}

  for _, expr in ipairs(stmt.values or {}) do
    values[#values + 1] = self:gen_expr(expr)
  end

  if #values == 0 then
    self:emit("return")
  else
    self:emit("return " .. table.concat(values, ", "))
  end
end

function Codegen:gen_expr(expr)
  if expr.kind == "Identifier" then
    return expr.name
  elseif expr.kind == "SelfExpr" then
    if not self.current_class then
      error("Self used outside of class")
    end

    if self.current_method
        and self.current_method.receiverKind == "self_class"
        and self.current_method.name ~= "new" then
      return "Self"
    end

    return self.current_class.name
  elseif expr.kind == "SuperExpr" then
    if not self.current_class or not self.current_class.base then
      error("super used outside of subclass")
    end

    return self.current_class.base.name
  elseif expr.kind == "Literal" then
    return self:gen_literal(expr.value)
  elseif expr.kind == "TableLiteral" then
    return self:gen_table_literal(expr)
  elseif expr.kind == "MemberExpr" then
    return self:gen_member_expr(expr)
  elseif expr.kind == "MethodLookupExpr" then
    return self:gen_method_lookup_expr(expr)
  elseif expr.kind == "CallExpr" then
    return self:gen_call_expr(expr)
  elseif expr.kind == "DerefExpr" then
    return self:gen_expr(expr.target) .. ".value"
  elseif expr.kind == "UnaryExpr" then
    return self:gen_unary_expr(expr)
  elseif expr.kind == "BinaryExpr" then
    return self:gen_binary_expr(expr)
  elseif expr.kind == "LambdaExpr" then
    return self:gen_lambda_expr(expr)
  elseif expr.kind == "GroupExpr" then
    return "(" .. self:gen_expr(expr.expression) .. ")"
  elseif expr.kind == "PipeExpr" then
    return self:gen_pipe_expr(expr)
  else
    error("unsupported expression node: " .. tostring(expr.kind))
  end
end

function Codegen:gen_pipe_expr(expr)
  local piped = self:gen_expr(expr.left)
  local right = expr.right

  if right.kind == "CallExpr" then
    return self:gen_call_expr_with_leading_arg(right, piped)
  end

  return self:gen_expr(right) .. "(" .. piped .. ")"
end

function Codegen:gen_call_expr_with_leading_arg(expr, leading_arg)
  local args = { leading_arg }

  for _, arg in ipairs(expr.args or {}) do
    args[#args + 1] = self:gen_expr(arg)
  end

  if expr.callee.kind == "MethodLookupExpr" then
    local base = self:gen_expr(expr.callee.base)
    local method = expr.callee.name

    local call_args = { base }

    for _, arg in ipairs(args) do
      call_args[#call_args + 1] = arg
    end

    return "__sino.get_method(" .. base .. ".__class, "
        .. quote_string(method)
        .. ")("
        .. table.concat(call_args, ", ")
        .. ")"
  end

  return self:gen_expr(expr.callee) .. "(" .. table.concat(args, ", ") .. ")"
end

function Codegen:gen_member_expr(expr)
  local base = self:gen_expr(expr.base)

  -- In Sino, dot access means field access.
  -- person.name -> person.__fields.name
  return base .. ".__fields." .. expr.name
end

function Codegen:gen_method_lookup_expr(expr)
  local base = self:gen_expr(expr.base)
  return "__sino.get_method(" .. base .. ".__class, " .. quote_string(expr.name) .. ")"
end

function Codegen:gen_lambda_expr(expr)
  local params, prologue = self:gen_param_list_with_prologue(expr.params)

  if expr.expressionBody then
    if #prologue == 0 then
      return "function(" .. params .. ") return "
          .. self:gen_expr(expr.expressionBody)
          .. " end"
    end

    local previous_lines = self.lines
    local previous_indent = self.indent_level

    self.lines = {}
    self.indent_level = 0

    self:emit("function(" .. params .. ")")
    self:push_indent()

    for _, line in ipairs(prologue) do
      self:emit(line)
    end

    self:emit("return " .. self:gen_expr(expr.expressionBody))

    self:pop_indent()
    self:emit("end")

    local source = table.concat(self.lines, "\n")

    self.lines = previous_lines
    self.indent_level = previous_indent

    return source
  end

  local previous_lines = self.lines
  local previous_indent = self.indent_level

  self.lines = {}
  self.indent_level = 0

  self:emit("function(" .. params .. ")")
  self:push_indent()
  for _, line in ipairs(prologue) do
    self:emit(line)
  end
  self:gen_statements(expr.blockBody or {})
  self:pop_indent()
  self:emit("end")

  local source = table.concat(self.lines, "\n")

  self.lines = previous_lines
  self.indent_level = previous_indent

  return source
end

function Codegen:gen_literal(value)
  if type(value) == "string" then
    return quote_string(value)
  elseif type(value) == "number" then
    return tostring(value)
  elseif type(value) == "boolean" then
    return tostring(value)
  elseif value == nil then
    return "nil"
  else
    error("unsupported literal value: " .. tostring(value))
  end
end

function Codegen:gen_table_literal(expr)
  local parts = {}

  for _, entry in ipairs(expr.entries or {}) do
    if entry.kind == "TableFieldEntry" then
      parts[#parts + 1] = entry.key .. " = " .. self:gen_expr(entry.value)
    elseif entry.kind == "TableArrayEntry" then
      parts[#parts + 1] = self:gen_expr(entry.value)
    else
      error("unsupported table entry: " .. tostring(entry.kind))
    end
  end

  return "{" .. table.concat(parts, ", ") .. "}"
end

function Codegen:gen_call_expr(expr)
  local args = {}

  for _, arg in ipairs(expr.args or {}) do
    args[#args + 1] = self:gen_expr(arg)
  end

  if expr.callee.kind == "MethodLookupExpr" then
    local base = self:gen_expr(expr.callee.base)
    local method = expr.callee.name

    local call_args = { base }
    for _, arg in ipairs(args) do
      call_args[#call_args + 1] = arg
    end

    return "__sino.get_method(" .. base .. ".__class, "
        .. quote_string(method)
        .. ")("
        .. table.concat(call_args, ", ")
        .. ")"
  end

  return self:gen_expr(expr.callee) .. "(" .. table.concat(args, ", ") .. ")"
end

function Codegen:gen_unary_expr(expr)
  local op = expr.op

  if op == "MINUS" then
    return "-" .. self:gen_expr(expr.expression)
  elseif op == "KW_NOT" then
    return "not " .. self:gen_expr(expr.expression)
  end

  error("unsupported unary operator: " .. tostring(op))
end

function Codegen:gen_binary_expr(expr)
  local op = self:lua_binary_op(expr.op)
  return self:gen_expr(expr.left) .. " " .. op .. " " .. self:gen_expr(expr.right)
end

function Codegen:lua_binary_op(op)
  local ops = {
    PLUS = "+",
    MINUS = "-",
    STAR = "*",
    SLASH = "/",
    PERCENT = "%",
    CARET = "^",
    CONCAT = "..",
    EQ = "==",
    NE = "~=",
    LT = "<",
    LTE = "<=",
    GT = ">",
    GTE = ">=",
    KW_AND = "and",
    KW_OR = "or",
  }

  local result = ops[op]

  if not result then
    error("unsupported binary operator: " .. tostring(op))
  end

  return result
end

return {
  Codegen = Codegen,
}