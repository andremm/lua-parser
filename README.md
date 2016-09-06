lua-parser
==========
[![Build Status](https://travis-ci.org/andremm/lua-parser.svg?branch=master)](https://travis-ci.org/andremm/lua-parser)

This is a Lua 5.3 parser written with [LPegLabel](https://github.com/sqmedeiros/lpeglabel) that
generates an AST in the format specified by [Metalua](https://github.com/fab13n/metalua-parser).
The parser uses LPegLabel to provide more specific error messages.

Requirements
------------

        lua >= 5.1
        lpeglabel >= 1.0.0

API
---

The package `lua-parser` has two modules: `lua-parser.parser`
and `lua-parser.pp`.

The module `lua-parser.parser` implements the function `parser.parse`:

* `parser.parse (subject, filename)`

    Both subject and filename should be strings.
    It tries to parse subject and returns the AST in case of success.
    It returns **nil** plus an error message in case of error.
    In case of error, the parser uses the string filename to build an
    error message.

The module `lua-parser.pp` implements a pretty printer to the AST and
a dump function:

* `pp.tostring (ast)`

    It converts the AST to a string and returns this string.

* `pp.print (ast)`

    It converts the AST to a string and prints this string.

* `pp.dump (ast[, i])`

    It dumps the AST to the screen.
    The parameter **i** sets the indentation level.

Usage
--------

**Code example for parsing a string:**


    local parser = require "lua-parser.parser"
    local pp = require "lua-parser.pp"

    if #arg ~= 1 then
        print("Usage: parse.lua <string>")
        os.exit(1)
    end

    local ast, error_msg = parser.parse(arg[1], "example.lua")
    if not ast then
        print(error_msg)
        os.exit(1)
    end

    pp.print(ast)
    os.exit(0)

**Running the above code example using a string without syntax error:**

    $ lua parse.lua "for i=1, 10 do print(i) end"
    { `Fornum{ `Id "i", `Number "1", `Number "10", { `Call{ `Id "print", `Id "i" } } } }

**Running the above code example using a string with syntax error:**

    $ lua parse.lua "for i=1, 10 do print(i) "
    example.lua:1:24: syntax error, expected 'end' to close the for loop

