local TokenKind = {
  EOF = "EOF",

  IDENT = "IDENT",
  SELF = "SELF",

  NUMBER = "NUMBER",
  STRING = "STRING",

  KW_CLASS = "KW_CLASS",
  KW_FIELD = "KW_FIELD",
  KW_FUNC = "KW_FUNC",
  KW_EXTENDS = "KW_EXTENDS",
  KW_SUPER = "KW_SUPER",
  KW_LET = "KW_LET",
  KW_CONST = "KW_CONST",
  KW_REF = "KW_REF",
  KW_IMPORT = "KW_IMPORT",
  KW_FROM = "KW_FROM",
  KW_RETURN = "KW_RETURN",
  KW_IF = "KW_IF",
  KW_THEN = "KW_THEN",
  KW_ELSEIF = "KW_ELSEIF",
  KW_ELSE = "KW_ELSE",
  KW_FOR = "KW_FOR",
  KW_IN = "KW_IN",
  KW_WHILE = "KW_WHILE",
  KW_DO = "KW_DO",
  KW_LOCAL = "KW_LOCAL",
  KW_END = "KW_END",
  KW_NIL = "KW_NIL",
  KW_TRUE = "KW_TRUE",
  KW_LUA = "KW_LUA",
  KW_FALSE = "KW_FALSE",
  KW_AND = "KW_AND",
  KW_OR = "KW_OR",
  KW_NOT = "KW_NOT",
  KW_EXPORT = "KW_EXPORT",
  KW_CONTINUE = "KW_CONTINUE",
  KW_BREAK = "KW_BREAK",

  LPAREN = "LPAREN",
  RPAREN = "RPAREN",
  LBRACE = "LBRACE",
  RBRACE = "RBRACE",
  LBRACKET = "LBRACKET",
  RBRACKET = "RBRACKET",
  COMMA = "COMMA",
  DOT = "DOT",
  COLON = "COLON",
  SEMICOLON = "SEMICOLON",
  HASH = "HASH",
  ARROW = "ARROW",
  AT = "AT", -- @ used for debug scripting

  ASSIGN = "ASSIGN",
  REF_ASSIGN = "REF_ASSIGN",

  PLUS = "PLUS",
  MINUS = "MINUS",
  STAR = "STAR",
  SLASH = "SLASH",
  PERCENT = "PERCENT",
  CARET = "CARET",
  CONCAT = "CONCAT",
  PIPE_GT = "PIPE_GT",

  PLUS_ASSIGN = "PLUS_ASSIGN",
  MINUS_ASSIGN = "MINUS_ASSIGN",
  STAR_ASSIGN = "STAR_ASSIGN",
  SLASH_ASSIGN = "SLASH_ASSIGN",
  PERCENT_ASSIGN = "PERCENT_ASSIGN",

  EQ = "EQ",
  NE = "NE",
  LT = "LT",
  LTE = "LTE",
  GT = "GT",
  GTE = "GTE",
}

local KEYWORDS = {
  ["class"] = TokenKind.KW_CLASS,
  ["field"] = TokenKind.KW_FIELD,
  ["func"] = TokenKind.KW_FUNC,
  ["extends"] = TokenKind.KW_EXTENDS,
  ["super"] = TokenKind.KW_SUPER,
  ["let"] = TokenKind.KW_LET,
  ["const"] = TokenKind.KW_CONST,
  ["ref"] = TokenKind.KW_REF,
  ["import"] = TokenKind.KW_IMPORT,
  ["from"] = TokenKind.KW_FROM,
  ["return"] = TokenKind.KW_RETURN,
  ["if"] = TokenKind.KW_IF,
  ["then"] = TokenKind.KW_THEN,
  ["elseif"] = TokenKind.KW_ELSEIF,
  ["else"] = TokenKind.KW_ELSE,
  ["for"] = TokenKind.KW_FOR,
  ["in"] = TokenKind.KW_IN,
  ["while"] = TokenKind.KW_WHILE,
  ["do"] = TokenKind.KW_DO,
  ["local"] = TokenKind.KW_LOCAL,
  ["end"] = TokenKind.KW_END,
  ["nil"] = TokenKind.KW_NIL,
  ["true"] = TokenKind.KW_TRUE,
  ["lua"] = TokenKind.KW_LUA,
  ["false"] = TokenKind.KW_FALSE,
  ["and"] = TokenKind.KW_AND,
  ["or"] = TokenKind.KW_OR,
  ["not"] = TokenKind.KW_NOT,
  ["export"] = TokenKind.KW_EXPORT,
  ["continue"] = TokenKind.KW_CONTINUE,
  ["break"] = TokenKind.KW_BREAK,
}

local Lexer = {}
Lexer.__index = Lexer

local function is_alpha(ch)
  return ch:match("^[A-Za-z_]$") ~= nil
end

local function is_digit(ch)
  return ch:match("^%d$") ~= nil
end

local function is_alnum(ch)
  return ch:match("^[A-Za-z0-9_]$") ~= nil
end

local function clone_pos(pos)
  return {
    offset = pos.offset,
    line = pos.line,
    column = pos.column,
  }
end

function Lexer.new(source, filename)
  local self = setmetatable({}, Lexer)

  self.source = source or ""
  self.filename = filename or "<stdin>"
  self.length = #self.source
  self.index = 1
  self.line = 1
  self.column = 1

  return self
end

function Lexer:current_char()
  if self.index > self.length then
    return nil
  end
  return self.source:sub(self.index, self.index)
end

function Lexer:peek(offset)
  offset = offset or 0
  local i = self.index + offset
  if i > self.length then
    return nil
  end
  return self.source:sub(i, i)
end

function Lexer:position()
  return {
    offset = self.index - 1,
    line = self.line,
    column = self.column,
  }
end

function Lexer:advance()
  local ch = self:current_char()
  if not ch then
    return nil
  end

  self.index = self.index + 1

  if ch == "\n" then
    self.line = self.line + 1
    self.column = 1
  else
    self.column = self.column + 1
  end

  return ch
end

function Lexer:match_char(expected)
  if self:current_char() == expected then
    self:advance()
    return true
  end
  return false
end

function Lexer:error_here(message, start_pos, finish_pos)
  error({
    kind = "LexerError",
    message = message,
    filename = self.filename,
    start = start_pos or self:position(),
    finish = finish_pos or self:position(),
  })
end

function Lexer:make_token(kind, lexeme, value, start_pos, finish_pos)
  return {
    kind = kind,
    lexeme = lexeme,
    value = value,
    filename = self.filename,
    start = clone_pos(start_pos),
    finish = clone_pos(finish_pos),
  }
end

function Lexer:skip_whitespace_and_comments()
  while true do
    local ch = self:current_char()

    if not ch then
      return
    end

    if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" then
      self:advance()
    elseif ch == "-" and self:peek(1) == "-" then
      self:skip_comment()
    else
      return
    end
  end
end

function Lexer:skip_comment()
  local start_pos = self:position()

  self:advance() -- -
  self:advance() -- -

  if self:current_char() == "[" and self:peek(1) == "[" then
    self:advance() -- [
    self:advance() -- [

    while true do
      local ch = self:current_char()
      if not ch then
        self:error_here("unterminated block comment", start_pos, self:position())
      end

      if ch == "]" and self:peek(1) == "]" then
        self:advance()
        self:advance()
        return
      end

      self:advance()
    end
  else
    while true do
      local ch = self:current_char()
      if not ch or ch == "\n" then
        return
      end
      self:advance()
    end
  end
end

function Lexer:read_identifier_or_keyword()
  local start_pos = self:position()
  local buffer = {}

  while true do
    local ch = self:current_char()
    if not ch or not is_alnum(ch) then
      break
    end
    buffer[#buffer + 1] = self:advance()
  end

  local lexeme = table.concat(buffer)
  local finish_pos = self:position()

  if lexeme == "Self" then
    return self:make_token(TokenKind.SELF, lexeme, lexeme, start_pos, finish_pos)
  end

  local keyword_kind = KEYWORDS[lexeme]
  if keyword_kind then
    return self:make_token(keyword_kind, lexeme, lexeme, start_pos, finish_pos)
  end

  return self:make_token(TokenKind.IDENT, lexeme, lexeme, start_pos, finish_pos)
end

function Lexer:read_number()
  local start_pos = self:position()
  local buffer = {}
  local saw_dot = false

  while true do
    local ch = self:current_char()
    if not ch then
      break
    end

    if is_digit(ch) then
      buffer[#buffer + 1] = self:advance()
    elseif ch == "." and not saw_dot and is_digit(self:peek(1) or "") then
      saw_dot = true
      buffer[#buffer + 1] = self:advance()
    else
      break
    end
  end

  local lexeme = table.concat(buffer)
  local finish_pos = self:position()
  local value = tonumber(lexeme)

  if value == nil then
    self:error_here("invalid numeric literal '" .. lexeme .. "'", start_pos, finish_pos)
  end

  return self:make_token(TokenKind.NUMBER, lexeme, value, start_pos, finish_pos)
end

function Lexer:read_string()
  local quote = self:current_char()
  local start_pos = self:position()
  local raw_buffer = {}
  local value_buffer = {}

  raw_buffer[#raw_buffer + 1] = self:advance()

  while true do
    local ch = self:current_char()
    if not ch then
      self:error_here("unterminated string literal", start_pos, self:position())
    end

    if ch == quote then
      raw_buffer[#raw_buffer + 1] = self:advance()
      break
    end

    if ch == "\\" then
      raw_buffer[#raw_buffer + 1] = self:advance()
      local esc = self:current_char()
      if not esc then
        self:error_here("unterminated escape sequence", start_pos, self:position())
      end

      raw_buffer[#raw_buffer + 1] = self:advance()

      if esc == "n" then
        value_buffer[#value_buffer + 1] = "\n"
      elseif esc == "t" then
        value_buffer[#value_buffer + 1] = "\t"
      elseif esc == "r" then
        value_buffer[#value_buffer + 1] = "\r"
      elseif esc == "\\" then
        value_buffer[#value_buffer + 1] = "\\"
      elseif esc == '"' then
        value_buffer[#value_buffer + 1] = '"'
      elseif esc == "'" then
        value_buffer[#value_buffer + 1] = "'"
      elseif esc == "0" then
        value_buffer[#value_buffer + 1] = "\0"
      else
        self:error_here("unsupported escape sequence '\\" .. esc .. "'", start_pos, self:position())
      end
    else
      if ch == "\n" then
        self:error_here("newline in string literal", start_pos, self:position())
      end
      raw_buffer[#raw_buffer + 1] = self:advance()
      value_buffer[#value_buffer + 1] = ch
    end
  end

  local lexeme = table.concat(raw_buffer)
  local value = table.concat(value_buffer)
  local finish_pos = self:position()

  return self:make_token(TokenKind.STRING, lexeme, value, start_pos, finish_pos)
end

function Lexer:read_simple_token(kind)
  local start_pos = self:position()
  local lexeme = self:advance()
  local finish_pos = self:position()
  return self:make_token(kind, lexeme, lexeme, start_pos, finish_pos)
end

function Lexer:next_token()
  self:skip_whitespace_and_comments()

  local start_pos = self:position()
  local ch = self:current_char()

  if not ch then
    return self:make_token(TokenKind.EOF, "", nil, start_pos, start_pos)
  end

  if is_alpha(ch) then
    return self:read_identifier_or_keyword()
  end

  if is_digit(ch) then
    return self:read_number()
  end

  if ch == '"' or ch == "'" then
    return self:read_string()
  end

  if ch == ":" and self:peek(1) == "=" then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.REF_ASSIGN, ":=", ":=", start_pos, self:position())
  end

  if ch == "=" and self:peek(1) == "=" then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.EQ, "==", "==", start_pos, self:position())
  end

  if ch == "+" and self:peek(1) == "=" then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.PLUS_ASSIGN, "+=", "+=", start_pos, self:position())
  end

  if ch == "-" and self:peek(1) == "=" then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.MINUS_ASSIGN, "-=", "-=", start_pos, self:position())
  end

  if ch == "*" and self:peek(1) == "=" then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.STAR_ASSIGN, "*=", "*=", start_pos, self:position())
  end

  if ch == "/" and self:peek(1) == "=" then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.SLASH_ASSIGN, "/=", "/=", start_pos, self:position())
  end

  if ch == "%" and self:peek(1) == "=" then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.PERCENT_ASSIGN, "%=", "%=", start_pos, self:position())
  end

  if ch == "~" and self:peek(1) == "=" then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.NE, "~=", "~=", start_pos, self:position())
  end

  if ch == "<" and self:peek(1) == "=" then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.LTE, "<=", "<=", start_pos, self:position())
  end

  if ch == ">" and self:peek(1) == "=" then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.GTE, ">=", ">=", start_pos, self:position())
  end

  if ch == "." and self:peek(1) == "." then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.CONCAT, "..", "..", start_pos, self:position())
  end

  if ch == "=" and self:peek(1) == ">" then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.ARROW, "=>", "=>", start_pos, self:position())
  end

  if ch == "|" and self:peek(1) == ">" then
    self:advance()
    self:advance()
    return self:make_token(TokenKind.PIPE_GT, "|>", "|>", start_pos, self:position())
  end

  if ch == "=" then
    return self:read_simple_token(TokenKind.ASSIGN)
  elseif ch == "+" then
    return self:read_simple_token(TokenKind.PLUS)
  elseif ch == "-" then
    return self:read_simple_token(TokenKind.MINUS)
  elseif ch == "*" then
    return self:read_simple_token(TokenKind.STAR)
  elseif ch == "/" then
    return self:read_simple_token(TokenKind.SLASH)
  elseif ch == "%" then
    return self:read_simple_token(TokenKind.PERCENT)
  elseif ch == "^" then
    return self:read_simple_token(TokenKind.CARET)
  elseif ch == "<" then
    return self:read_simple_token(TokenKind.LT)
  elseif ch == ">" then
    return self:read_simple_token(TokenKind.GT)
  elseif ch == "(" then
    return self:read_simple_token(TokenKind.LPAREN)
  elseif ch == ")" then
    return self:read_simple_token(TokenKind.RPAREN)
  elseif ch == "{" then
    return self:read_simple_token(TokenKind.LBRACE)
  elseif ch == "}" then
    return self:read_simple_token(TokenKind.RBRACE)
  elseif ch == "[" then
    return self:read_simple_token(TokenKind.LBRACKET)
  elseif ch == "]" then
    return self:read_simple_token(TokenKind.RBRACKET)
  elseif ch == "#" then
    return self:read_simple_token(TokenKind.HASH)
  elseif ch == "," then
    return self:read_simple_token(TokenKind.COMMA)
  elseif ch == "." then
    return self:read_simple_token(TokenKind.DOT)
  elseif ch == ":" then
    return self:read_simple_token(TokenKind.COLON)
  elseif ch == "@" then
    return self:read_simple_token(TokenKind.AT)
  elseif ch == ";" then
    return self:read_simple_token(TokenKind.SEMICOLON)
  end

  self:error_here("unexpected character '" .. ch .. "'", start_pos, self:position())
end

function Lexer:tokenize()
  local tokens = {}

  while true do
    local token = self:next_token()
    tokens[#tokens + 1] = token

    if token.kind == TokenKind.EOF then
      break
    end
  end

  return tokens
end

return {
  TokenKind = TokenKind,
  Lexer = Lexer,
}