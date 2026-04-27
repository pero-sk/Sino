local lexer_mod = require("lexer")
local TokenKind = lexer_mod.TokenKind

local Parser = {}
Parser.__index = Parser

local COMPOUND_ASSIGN_OPS = {
  [TokenKind.PLUS_ASSIGN] = TokenKind.PLUS,
  [TokenKind.MINUS_ASSIGN] = TokenKind.MINUS,
  [TokenKind.STAR_ASSIGN] = TokenKind.STAR,
  [TokenKind.SLASH_ASSIGN] = TokenKind.SLASH,
  [TokenKind.PERCENT_ASSIGN] = TokenKind.PERCENT,
}

local function node(kind, fields)
  fields = fields or {}
  fields.kind = kind
  return fields
end

local function token_span(start_token, finish_token)
  return {
    start = start_token and start_token.start or nil,
    finish = finish_token and finish_token.finish or nil,
  }
end

function Parser.new(tokens, filename, source)
  local self = setmetatable({}, Parser)
  self.tokens = tokens or {}
  self.filename = filename or "<stdin>"
  self.source = source or ""
  self.index = 1
  return self
end

function Parser:current()
  return self.tokens[self.index]
end

function Parser:peek(offset)
  offset = offset or 0
  return self.tokens[self.index + offset]
end

function Parser:is_at_end()
  local tok = self:current()
  return not tok or tok.kind == TokenKind.EOF
end

function Parser:advance()
  local tok = self:current()
  if not self:is_at_end() then
    self.index = self.index + 1
  end
  return tok
end

function Parser:check(kind)
  local tok = self:current()
  return tok and tok.kind == kind
end

function Parser:match(...)
  local kinds = { ... }
  local tok = self:current()
  if not tok then
    return nil
  end

  for _, kind in ipairs(kinds) do
    if tok.kind == kind then
      self:advance()
      return tok
    end
  end

  return nil
end

function Parser:error_here(message, token)
  token = token or self:current() or self.tokens[#self.tokens]
  error({
    kind = "ParserError",
    message = message,
    filename = self.filename,
    start = token and token.start or nil,
    finish = token and token.finish or nil,
    token = token,
  })
end

function Parser:expect(kind, message)
  local tok = self:current()
  if tok and tok.kind == kind then
    self:advance()
    return tok
  end

  local got = tok and tok.kind or "<eof>"
  self:error_here((message or ("expected " .. kind)) .. ", got " .. got, tok)
end

function Parser:expect_ident(message)
  local tok = self:current()
  if tok and tok.kind == TokenKind.IDENT then
    self:advance()
    return tok
  end
  self:error_here(message or "expected identifier", tok)
end

function Parser:parse()
  local start_tok = self:current()
  local body = {}

  while not self:is_at_end() do
    body[#body + 1] = self:parse_decl()
  end

  local eof_tok = self:expect(TokenKind.EOF, "expected end of file")
  local span = token_span(start_tok, eof_tok)

  return node("Program", {
    body = body,
    start = span.start,
    finish = span.finish,
  })
end

function Parser:parse_decl()
  local tok = self:current()
  if not tok then
    self:error_here("unexpected end of input")
  end

  if tok.kind == TokenKind.KW_CLASS then
    return self:parse_class_decl()
  elseif tok.kind == TokenKind.KW_LET or tok.kind == TokenKind.KW_CONST then
    return self:parse_var_decl()
  elseif tok.kind == TokenKind.KW_FUNC then
    return self:parse_func_decl(false)
  elseif tok.kind == TokenKind.KW_IMPORT then
    return self:parse_import_decl()
  elseif tok.kind == TokenKind.KW_LUA then
    return self:parse_lua_block()
  elseif tok.kind == TokenKind.KW_EXPORT then
    return self:parse_export_decl()
  elseif tok.kind == TokenKind.KW_IF then
    return self:parse_if_statement()
  elseif tok.kind == TokenKind.KW_WHILE then
    return self:parse_while_statement()
  elseif tok.kind == TokenKind.KW_FOR then
    return self:parse_for_statement()
  elseif tok.kind == TokenKind.AT then
    return self:parse_debug_script()
  end

  return self:parse_statement()
end

function Parser:parse_class_decl()
  local class_tok = self:expect(TokenKind.KW_CLASS)
  local name_tok = self:expect_ident("expected class name")
  local base = nil

  if self:match(TokenKind.KW_EXTENDS) then
    local base_tok = self:expect_ident("expected base class name after extends")
    base = node("Identifier", {
      name = base_tok.lexeme,
      token = base_tok,
      start = base_tok.start,
      finish = base_tok.finish,
    })
  end

  local members = {}
  while not self:check(TokenKind.KW_END) and not self:is_at_end() do
    members[#members + 1] = self:parse_class_member()
  end

  local end_tok = self:expect(TokenKind.KW_END, "expected 'end' to close class")
  local span = token_span(class_tok, end_tok)

  return node("ClassDecl", {
    name = name_tok.lexeme,
    nameToken = name_tok,
    base = base,
    members = members,
    start = span.start,
    finish = span.finish,
  })
end

function Parser:parse_class_member()
  local tok = self:current()
  if not tok then
    self:error_here("unexpected end of input in class body")
  end

  if tok.kind == TokenKind.KW_FIELD then
    return self:parse_field_decl()
  elseif tok.kind == TokenKind.KW_STATIC then
    self:advance()
    self:expect(TokenKind.KW_FUNC, "expected 'func' after 'static'")
    return self:parse_func_decl(true)
  elseif tok.kind == TokenKind.KW_FUNC then
    return self:parse_func_decl(false)
  elseif tok.kind == TokenKind.KW_META then
    return self:parse_meta_decl()
  end

  self:error_here("unexpected token in class body: " .. tok.kind, tok)
end

function Parser:parse_field_decl()
  local field_tok = self:expect(TokenKind.KW_FIELD)
  local name_tok = self:expect_ident("expected field name")
  local default_value = nil

  if self:match(TokenKind.ASSIGN) then
    default_value = self:parse_expression()
  end

  local finish_tok = self:peek(-1) or name_tok
  local span = token_span(field_tok, finish_tok)

  return node("FieldDecl", {
    name = name_tok.lexeme,
    nameToken = name_tok,
    defaultValue = default_value,
    start = span.start,
    finish = span.finish,
  })
end

function Parser:parse_for_statement()
  local for_tok = self:expect(TokenKind.KW_FOR)
  local ident_tok = self:expect_ident("expected loop variable name after 'for'")
  self:expect(TokenKind.KW_IN, "expected 'in' after loop variable name")
  local iterable = self:parse_expression()
  self:expect(TokenKind.KW_DO, "expected 'do' after for loop iterable")
  local body = {}
    while not self:check(TokenKind.KW_END) and not self:is_at_end() do
      body[#body + 1] = self:parse_statement()
    end
    
  local end_tok = self:expect(TokenKind.KW_END, "expected 'end' to close for statement")
  local span = token_span(for_tok, end_tok)

  return node("ForStmt", {
    variable = ident_tok.lexeme,
    variableToken = ident_tok,
    iterable = iterable,
    body = body,
    start = span.start,
    finish = span.finish,
  })
end


function Parser:parse_debug_script()
  local at_tok = self:expect(TokenKind.AT)

  local name_tok = self:expect_ident("expected debug script directive name after '@'")

  self:expect(TokenKind.LPAREN, "expected '(' after debug script directive name")

  local args = self:parse_argument_list()

  local rparen_tok = self:expect(TokenKind.RPAREN, "expected ')' after debug script arguments")

  local span = token_span(at_tok, rparen_tok)

  return node("DebugScriptStmt", {
    name = name_tok.lexeme,
    nameToken = name_tok,
    args = args,
    start = span.start,
    finish = span.finish,
  })
end

function Parser:parse_while_statement()
  local while_tok = self:expect(TokenKind.KW_WHILE)
  local condition = self:parse_expression()
  self:expect(TokenKind.KW_DO, "expected 'do' after while condition")

  local body = {}
  while not self:check(TokenKind.KW_END) and not self:is_at_end() do
    body[#body + 1] = self:parse_statement()
  end

  local end_tok = self:expect(TokenKind.KW_END, "expected 'end' to close while statement")
  local span = token_span(while_tok, end_tok)

  return node("WhileStmt", {
    condition = condition,
    body = body,
    start = span.start,
    finish = span.finish,
  })
end

function Parser:parse_if_statement()
  local if_tok = self:expect(TokenKind.KW_IF)
  local condition = self:parse_expression()
  self:expect(TokenKind.KW_THEN, "expected 'then' after if condition")

  local then_branch = {}
  while not self:check(TokenKind.KW_ELSEIF)
      and not self:check(TokenKind.KW_ELSE)
      and not self:check(TokenKind.KW_END)
      and not self:is_at_end()
  do
    then_branch[#then_branch + 1] = self:parse_statement()
  end

  local elseif_branches = {}

  while self:match(TokenKind.KW_ELSEIF) do
    local elseif_condition = self:parse_expression()
    self:expect(TokenKind.KW_THEN, "expected 'then' after elseif condition")

    local elseif_branch = {}
    while not self:check(TokenKind.KW_ELSEIF)
        and not self:check(TokenKind.KW_ELSE)
        and not self:check(TokenKind.KW_END)
        and not self:is_at_end()
    do
      elseif_branch[#elseif_branch + 1] = self:parse_statement()
    end

    elseif_branches[#elseif_branches + 1] = {
      condition = elseif_condition,
      branch = elseif_branch,
    }
  end

  local else_branch = nil
  if self:match(TokenKind.KW_ELSE) then
    else_branch = {}
    while not self:check(TokenKind.KW_END) and not self:is_at_end() do
      else_branch[#else_branch + 1] = self:parse_statement()
    end
  end

  local end_tok = self:expect(TokenKind.KW_END, "expected 'end' to close if statement")
  local span = token_span(if_tok, end_tok)

  return node("IfStmt", {
    condition = condition,
    thenBranch = then_branch,
    elseifBranches = elseif_branches,
    elseBranch = else_branch,
    start = span.start,
    finish = span.finish,
  })
end

function Parser:parse_export_decl()
  local start_tok = self:expect(TokenKind.KW_EXPORT)
  local expr = self:parse_expression()

  return node("ExportDecl", {
    value = expr,
    start = start_tok.start,
    finish = expr.finish,
  })
end

function Parser:parse_func_decl(is_static)
  local func_tok = self:expect(TokenKind.KW_FUNC, "expected 'func'")
  local receiver_kind = "instance"
  local name_tok

  if self:check(TokenKind.SELF) and self:peek(1) and self:peek(1).kind == TokenKind.COLON then
    receiver_kind = "self_class"
    self:advance()
    self:advance()
    name_tok = self:expect_ident("expected method name after 'Self:'")
  else
    name_tok = self:expect_ident("expected function or method name")
  end

  self:expect(TokenKind.LPAREN, "expected '(' after function name")
  local params = self:parse_param_list()
  self:expect(TokenKind.RPAREN, "expected ')' after parameter list")

  local body = {}
  while not self:check(TokenKind.KW_END) and not self:is_at_end() do
    body[#body + 1] = self:parse_statement()
  end

  local end_tok = self:expect(TokenKind.KW_END, "expected 'end' to close function")
  local span = token_span(func_tok, end_tok)

  return node("MethodDecl", {
    name = name_tok.lexeme,
    nameToken = name_tok,
    params = params,
    body = body,
    isStatic = is_static,
    receiverKind = receiver_kind,
    start = span.start,
    finish = span.finish,
  })
end

function Parser:parse_meta_decl()
  local meta_tok = self:expect(TokenKind.KW_META)
  local name_tok = self:expect_ident("expected metamethod name")

  self:expect(TokenKind.LPAREN, "expected '(' after metamethod name")
  local params = self:parse_param_list()
  self:expect(TokenKind.RPAREN, "expected ')' after parameter list")

  local body = {}
  while not self:check(TokenKind.KW_END) and not self:is_at_end() do
    body[#body + 1] = self:parse_statement()
  end

  local end_tok = self:expect(TokenKind.KW_END, "expected 'end' to close metamethod")
  local span = token_span(meta_tok, end_tok)

  return node("MetaDecl", {
    name = name_tok.lexeme,
    nameToken = name_tok,
    params = params,
    body = body,
    start = span.start,
    finish = span.finish,
  })
end

function Parser:parse_import_decl()
  local import_tok = self:expect(TokenKind.KW_IMPORT)
  local name_tok = self:expect_ident("expected import name")

  self:expect(TokenKind.KW_FROM, "expected 'from' after import name")

  local path_tok = self:expect(TokenKind.STRING, "expected import path string")

  return node("ImportDecl", {
    name = name_tok.lexeme,
    path = path_tok.value,
    nameToken = name_tok,
    pathToken = path_tok,
    start = import_tok.start,
    finish = path_tok.finish,
  })
end

function Parser:parse_param_list()
  local params = {}

  if self:check(TokenKind.RPAREN) then
    return params
  end

  repeat
    local pattern = self:parse_pattern()

    params[#params + 1] = node("Param", {
      name = pattern.kind == "IdentifierPattern" and pattern.name or nil,
      token = pattern.token,
      pattern = pattern,
      start = pattern.start,
      finish = pattern.finish,
    })
  until not self:match(TokenKind.COMMA)

  return params
end

function Parser:parse_var_decl()
  local kind_tok = self:advance()
  local pattern = self:parse_pattern()

  local is_ref = false

  if self:match(TokenKind.ASSIGN) then
    is_ref = false
  elseif self:match(TokenKind.REF_ASSIGN) then
    is_ref = true
  else
    self:error_here("expected '=' or ':=' in variable declaration")
  end

  local init = self:parse_expression()
  local span = token_span(kind_tok, init.lastToken or pattern.token)

  return node("VarDecl", {
    declKind = kind_tok.kind == TokenKind.KW_CONST and "const" or "let",
    isRef = is_ref,
    pattern = pattern,

    -- backward compatibility
    name = pattern.kind == "IdentifierPattern" and pattern.name or nil,
    nameToken = pattern.kind == "IdentifierPattern" and pattern.token or nil,

    init = init,
    start = span.start,
    finish = span.finish,
  })
end

function Parser:parse_pattern()
  if self:check(TokenKind.IDENT) then
    local tok = self:advance()
    return node("IdentifierPattern", {
      name = tok.lexeme,
      token = tok,
      start = tok.start,
      finish = tok.finish,
    })
  end

  if self:check(TokenKind.LBRACE) then
    return self:parse_object_pattern()
  end

  self:error_here("expected variable name or destructuring pattern")
end

function Parser:parse_object_pattern()
  local lbrace = self:expect(TokenKind.LBRACE)
  local fields = {}

  if not self:check(TokenKind.RBRACE) then
    repeat
      local key_tok = self:expect_ident("expected field name in destructuring pattern")
      local local_name_tok = key_tok

      -- alias: {name: n}
      if self:match(TokenKind.COLON) then
        local_name_tok = self:expect_ident("expected alias name after ':' in destructuring pattern")
      end

      fields[#fields + 1] = {
        key = key_tok.lexeme,
        name = local_name_tok.lexeme,
        keyToken = key_tok,
        nameToken = local_name_tok,
        start = key_tok.start,
        finish = local_name_tok.finish,
      }
    until not self:match(TokenKind.COMMA)
  end

  local rbrace = self:expect(TokenKind.RBRACE, "expected '}' after destructuring pattern")

  return node("ObjectPattern", {
    fields = fields,
    firstToken = lbrace,
    lastToken = rbrace,
    start = lbrace.start,
    finish = rbrace.finish,
  })
end

function Parser:parse_statement()
  local tok = self:current()
  if not tok then
    self:error_here("unexpected end of input in statement")
  end

  if tok.kind == TokenKind.KW_RETURN then
    return self:parse_return_stmt()
  elseif tok.kind == TokenKind.KW_LET or tok.kind == TokenKind.KW_CONST then
    return self:parse_var_decl()
  elseif tok.kind == TokenKind.KW_LUA then
    return self:parse_lua_block()
  elseif tok.kind == TokenKind.KW_IF then
    return self:parse_if_statement()
  elseif tok.kind == TokenKind.KW_WHILE then
    return self:parse_while_statement()
  elseif tok.kind == TokenKind.KW_FOR then
    return self:parse_for_statement()
  elseif tok.kind == TokenKind.KW_CONTINUE then
    local continue_tok = self:advance()
    return node("ContinueStmt", {
      start = continue_tok.start,
      finish = continue_tok.finish,
    })
  elseif tok.kind == TokenKind.KW_BREAK then
    local break_tok = self:advance()
    return node("BreakStmt", {
      start = break_tok.start,
      finish = break_tok.finish,
    })
  end
  return self:parse_expr_or_assign_stmt()
end

function Parser:parse_return_stmt()
  local return_tok = self:expect(TokenKind.KW_RETURN)
  local values = {}

  if not self:check(TokenKind.KW_END) and not self:is_at_end() then
    values[#values + 1] = self:parse_expression()
    while self:match(TokenKind.COMMA) do
      values[#values + 1] = self:parse_expression()
    end
  end

  local finish_tok = (#values > 0 and values[#values].lastToken) or return_tok
  local span = token_span(return_tok, finish_tok)

  return node("ReturnStmt", {
    values = values,
    start = span.start,
    finish = span.finish,
  })
end

function Parser:parse_lua_block()
  local lua_tok = self:expect(TokenKind.KW_LUA)
  local first_tok = self:current()

  local depth = 0

  while not self:is_at_end() do
    local tok = self:current()

    if tok.kind == TokenKind.KW_IF
        or tok.kind == TokenKind.KW_FOR
        or tok.kind == TokenKind.KW_WHILE
        or tok.kind == TokenKind.KW_FUNC then
      depth = depth + 1
      self:advance()

    elseif tok.kind == TokenKind.KW_END then
      if depth == 0 then
        break
      end

      depth = depth - 1
      self:advance()

    else
      self:advance()
    end
  end

  local end_tok = self:expect(TokenKind.KW_END, "expected 'end' to close lua block")

  local source = ""

  if first_tok and first_tok ~= end_tok then
    local start_offset = first_tok.start.offset
    local end_offset = end_tok.start.offset
    source = self.source:sub(start_offset + 1, end_offset)
  end

  local span = token_span(lua_tok, end_tok)

  return node("LuaBlockStmt", {
    source = source,
    start = span.start,
    finish = span.finish,
  })
end

function Parser:parse_expr_or_assign_stmt()
  local expr = self:parse_expression()

  if self:match(TokenKind.ASSIGN) then
    local value = self:parse_expression()
    local span = token_span(expr.firstToken or self:current(), value.lastToken)

    return node("AssignStmt", {
      target = expr,
      value = value,
      start = span.start,
      finish = span.finish,
    })

  elseif self:match(TokenKind.REF_ASSIGN) then
    local value = self:parse_expression()
    local span = token_span(expr.firstToken or self:current(), value.lastToken)

    return node("RefAssignStmt", {
      target = expr,
      value = value,
      start = span.start,
      finish = span.finish,
    })

  else
    local tok = self:current()
    local op = tok and COMPOUND_ASSIGN_OPS[tok.kind]

    if op then
      local op_tok = self:advance()
      local value = self:parse_expression()
      local span = token_span(expr.firstToken or op_tok, value.lastToken)

      return node("CompoundAssignStmt", {
        target = expr,
        op = op,
        opToken = op_tok,
        value = value,
        start = span.start,
        finish = span.finish,
      })
    end
  end

  return node("ExprStmt", {
    expression = expr,
    start = expr.start,
    finish = expr.finish,
  })
end

function Parser:parse_expression()
  return self:parse_binary_expression(0)
end

local BINARY_PRECEDENCE = {
  [TokenKind.PIPE_GT] = { precedence = 0, assoc = "left" },
  [TokenKind.KW_OR] = { precedence = 1, assoc = "left" },
  [TokenKind.KW_AND] = { precedence = 2, assoc = "left" },
  [TokenKind.EQ] = { precedence = 3, assoc = "left" },
  [TokenKind.NE] = { precedence = 3, assoc = "left" },
  [TokenKind.LT] = { precedence = 4, assoc = "left" },
  [TokenKind.LTE] = { precedence = 4, assoc = "left" },
  [TokenKind.GT] = { precedence = 4, assoc = "left" },
  [TokenKind.GTE] = { precedence = 4, assoc = "left" },
  [TokenKind.CONCAT] = { precedence = 5, assoc = "right" },
  [TokenKind.PLUS] = { precedence = 6, assoc = "left" },
  [TokenKind.MINUS] = { precedence = 6, assoc = "left" },
  [TokenKind.STAR] = { precedence = 7, assoc = "left" },
  [TokenKind.SLASH] = { precedence = 7, assoc = "left" },
  [TokenKind.PERCENT] = { precedence = 7, assoc = "left" },
  [TokenKind.CARET] = { precedence = 9, assoc = "right" },
}

function Parser:parse_binary_expression(min_prec)
  local left = self:parse_unary_expression()

  while true do
    local tok = self:current()
    local info = tok and BINARY_PRECEDENCE[tok.kind] or nil
    if not info or info.precedence < min_prec then
      break
    end

    local op_tok = self:advance()
    local next_min = info.assoc == "right" and info.precedence or (info.precedence + 1)
    local right = self:parse_binary_expression(next_min)

    if op_tok.kind == TokenKind.PIPE_GT then
      left = node("PipeExpr", {
        left = left,
        right = right,
        opToken = op_tok,
        firstToken = left.firstToken or op_tok,
        lastToken = right.lastToken or op_tok,
        start = left.start,
        finish = right.finish,
      })
    else
      left = node("BinaryExpr", {
        op = op_tok.kind,
        opToken = op_tok,
        left = left,
        right = right,
        firstToken = left.firstToken or op_tok,
        lastToken = right.lastToken or op_tok,
        start = left.start,
        finish = right.finish,
      })
    end
  end

  return left
end

function Parser:parse_unary_expression()
  local tok = self:current()
  if tok and (tok.kind == TokenKind.MINUS or tok.kind == TokenKind.KW_NOT) then
    local op_tok = self:advance()
    local expr = self:parse_unary_expression()
    return node("UnaryExpr", {
      op = op_tok.kind,
      opToken = op_tok,
      expression = expr,
      firstToken = op_tok,
      lastToken = expr.lastToken,
      start = op_tok.start,
      finish = expr.finish,
    })
  end

  return self:parse_postfix_expression()
end

function Parser:parse_postfix_expression()
  local expr = self:parse_primary_expression()

  while true do
    if self:match(TokenKind.DOT) then
      local name_tok = self:expect_ident("expected member name after '.'")
      expr = node("MemberExpr", {
        base = expr,
        name = name_tok.lexeme,
        nameToken = name_tok,
        firstToken = expr.firstToken,
        lastToken = name_tok,
        start = expr.start,
        finish = name_tok.finish,
      })
    elseif self:match(TokenKind.COLON) then
      local name_tok = self:expect_ident("expected method name after ':'")
      expr = node("MethodLookupExpr", {
        base = expr,
        name = name_tok.lexeme,
        nameToken = name_tok,
        firstToken = expr.firstToken,
        lastToken = name_tok,
        start = expr.start,
        finish = name_tok.finish,
      })
    elseif self:match(TokenKind.LPAREN) then
      local args = self:parse_argument_list()
      local rparen_tok = self:expect(TokenKind.RPAREN, "expected ')' after argument list")
      expr = node("CallExpr", {
        callee = expr,
        args = args,
        firstToken = expr.firstToken,
        lastToken = rparen_tok,
        start = expr.start,
        finish = rparen_tok.finish,
      })
    elseif self:match(TokenKind.CARET) then
      expr = node("DerefExpr", {
        target = expr,
        firstToken = expr.firstToken,
        lastToken = self:peek(-1),
        start = expr.start,
        finish = (self:peek(-1) and self:peek(-1).finish) or expr.finish,
      })
    else
      break
    end
  end

  return expr
end

function Parser:parse_argument_list()
  local args = {}
  if self:check(TokenKind.RPAREN) then
    return args
  end

  repeat
    args[#args + 1] = self:parse_expression()
  until not self:match(TokenKind.COMMA)

  return args
end

function Parser:parse_lambda_expr()
  local func_tok = self:expect(TokenKind.KW_FUNC, "expected 'func'")

  self:expect(TokenKind.LPAREN, "expected '(' after 'func'")
  local params = self:parse_param_list()
  self:expect(TokenKind.RPAREN, "expected ')' after lambda parameters")

  if self:match(TokenKind.ARROW) then
    local body_expr = self:parse_expression()

    return node("LambdaExpr", {
      params = params,
      expressionBody = body_expr,
      blockBody = nil,
      firstToken = func_tok,
      lastToken = body_expr.lastToken,
      start = func_tok.start,
      finish = body_expr.finish,
    })
  end

  self:expect(TokenKind.KW_DO, "expected '=>' or 'do' after lambda parameters")

  local body = {}
  while not self:check(TokenKind.KW_END) and not self:is_at_end() do
    body[#body + 1] = self:parse_statement()
  end

  local end_tok = self:expect(TokenKind.KW_END, "expected 'end' to close lambda")

  return node("LambdaExpr", {
    params = params,
    expressionBody = nil,
    blockBody = body,
    firstToken = func_tok,
    lastToken = end_tok,
    start = func_tok.start,
    finish = end_tok.finish,
  })
end

function Parser:parse_primary_expression()
  local tok = self:current()
  if not tok then
    self:error_here("unexpected end of input in expression")
  end

  if tok.kind == TokenKind.IDENT then
    self:advance()
    return node("Identifier", {
      name = tok.lexeme,
      token = tok,
      firstToken = tok,
      lastToken = tok,
      start = tok.start,
      finish = tok.finish,
    })
  elseif tok.kind == TokenKind.SELF then
    self:advance()
    return node("SelfExpr", {
      token = tok,
      firstToken = tok,
      lastToken = tok,
      start = tok.start,
      finish = tok.finish,
    })
  elseif tok.kind == TokenKind.KW_SUPER then
    self:advance()
    return node("SuperExpr", {
      token = tok,
      firstToken = tok,
      lastToken = tok,
      start = tok.start,
      finish = tok.finish,
    })
  elseif tok.kind == TokenKind.NUMBER or tok.kind == TokenKind.STRING then
    self:advance()
    return node("Literal", {
      value = tok.value,
      token = tok,
      firstToken = tok,
      lastToken = tok,
      start = tok.start,
      finish = tok.finish,
    })
  elseif tok.kind == TokenKind.KW_TRUE or tok.kind == TokenKind.KW_FALSE or tok.kind == TokenKind.KW_NIL then
    self:advance()
    local value = nil
    if tok.kind == TokenKind.KW_TRUE then
      value = true
    elseif tok.kind == TokenKind.KW_FALSE then
      value = false
    end
    return node("Literal", {
      value = value,
      token = tok,
      firstToken = tok,
      lastToken = tok,
      start = tok.start,
      finish = tok.finish,
    })
  elseif tok.kind == TokenKind.LPAREN then
    local lparen = self:advance()
    local expr = self:parse_expression()
    local rparen = self:expect(TokenKind.RPAREN, "expected ')' after expression")
    return node("GroupExpr", {
      expression = expr,
      firstToken = lparen,
      lastToken = rparen,
      start = lparen.start,
      finish = rparen.finish,
    })
  elseif tok.kind == TokenKind.LBRACE then
    local lbrace = self:advance()
    local entries = {}

    if not self:check(TokenKind.RBRACE) then
      repeat
        if self:check(TokenKind.IDENT)
            and self:peek(1)
            and self:peek(1).kind == TokenKind.ASSIGN then
          local key_tok = self:advance()
          self:expect(TokenKind.ASSIGN, "expected '=' after table key")
          local value = self:parse_expression()

          entries[#entries + 1] = node("TableFieldEntry", {
            key = key_tok.lexeme,
            keyToken = key_tok,
            value = value,
            start = key_tok.start,
            finish = value.finish,
          })              
        else
          local value = self:parse_expression()

          entries[#entries + 1] = node("TableArrayEntry", {
            value = value,
            start = value.start,
            finish = value.finish,
          })
        end
      until not self:match(TokenKind.COMMA)
    end

    local rbrace = self:expect(TokenKind.RBRACE, "expected '}' after table literal")

    return node("TableLiteral", {
      entries = entries,
      firstToken = lbrace,
      lastToken = rbrace,
      start = lbrace.start,
      finish = rbrace.finish,
    })

  elseif tok.kind == TokenKind.KW_FUNC then
    return self:parse_lambda_expr()

  end

  self:error_here("unexpected token in expression: " .. tok.kind, tok)
end

return {
  Parser = Parser,
}
