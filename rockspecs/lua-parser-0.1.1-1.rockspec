--*-lua-*--
package = "lua-parser"
version = "0.1.1-1"
source = {
  url = "git://github.com/andremm/lua-parser",
  tag = "v0.1.1",
}
description = {
  summary = "A Lua 5.3 parser written with LPeg",
  detailed = [[
           This is a Lua 5.3 parser written with LPeg that generates an AST in
           the format specified by Metalua.
           The parser also implements an error reporting technique that is
           based on tracking the farthest failure position.
  ]],
  homepage = "https://github.com/andremm/lua-parser",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1",
  "lpeg >= 0.12",
}
build = {
  type="builtin",
  modules={
    ["lua-parser.parser"] = "lua-parser/parser.lua",
    ["lua-parser.pp"] = "lua-parser/pp.lua",
    ["lua-parser.scope"] = "lua-parser/scope.lua",
  }
}

