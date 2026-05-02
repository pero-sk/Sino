local Resolver = {}
Resolver.__index = Resolver

function Resolver.new(env)
  return setmetatable({
    env = env or { modules = {} },
  }, Resolver)
end

local function visit_list(self, list)
  for _, item in ipairs(list or {}) do
    self:visit(item)
  end
end

function Resolver.resolve(ast, env)
  local self = Resolver.new(env)
  self:visit(ast)
  return ast
end

function Resolver:visit(node)
  if type(node) ~= "table" then return end

  local method = self["visit_" .. node.kind]
  if method then
    method(self, node)
  end

  if node.kind == "Program" then
    visit_list(self, node.body)
  elseif node.kind == "Block" then
    visit_list(self, node.statements)
  elseif node.kind == "ClassDecl" then
    visit_list(self, node.members)
  elseif node.kind == "IfStmt" then
    visit_list(self, node.thenBranch)
    visit_list(self, node.elseBranch)
  end
end

function Resolver:visit_ImportDecl(node)
  self.env.modules[node.name] = true
end

function Resolver:visit_MethodLookupExpr(node)
  local base = node.base

  -- only handle simple identifier base for now
  if base.kind == "Identifier" then
    if self.env.modules[base.name] then
      node.resolvedStatic = true
    else
      node.resolvedStatic = false
    end
    return
  end

  node.resolvedStatic = false
end

return {
  Resolver = Resolver
}