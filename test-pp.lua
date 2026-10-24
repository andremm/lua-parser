local pp = require "lua-parser.pp"
local saved_char = rawget(_G, "char")
local sentinel = {}
_G.char = sentinel
local ast = {{ tag = "Return", { tag = "String", "hello" } }}
assert(pp.tostring(ast) == '{ `Return{ `String "hello" } }')
assert(_G.char == sentinel, "pretty printing changed global char")
_G.char = nil
pp.tostring(ast)
assert(rawget(_G, "char") == nil, "pretty printing created global char")
_G.char = saved_char
