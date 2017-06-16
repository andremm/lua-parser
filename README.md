lua-parser
==========
[![Build Status](https://travis-ci.org/hnes/lua-parser.svg?branch=master)](https://travis-ci.org/hnes/lua-parser)

This is a Lua 5.3 parser written with [LPegLabel](https://github.com/sqmedeiros/lpeglabel) that
generates an AST in a format that is similar to the one specified by [Metalua](https://github.com/fab13n/metalua-parser).
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

AST format
----------

	block: { stat* }

	stat:
            `Do{ stat* }
          | `Set{ {lhs+} {expr+} }                    -- lhs1, lhs2... = e1, e2...
          | `While{ expr block }                      -- while e do b end
          | `Repeat{ block expr }                     -- repeat b until e
          | `If{ (expr block)+ block? }               -- if e1 then b1 [elseif e2 then b2] ... [else bn] end
          | `Fornum{ ident expr expr expr? block }    -- for ident = e, e[, e] do b end
          | `Forin{ {ident+} {expr+} block }          -- for i1, i2... in e1, e2... do b end
          | `Local{ {ident+} {expr+}? }               -- local i1, i2... = e1, e2...
          | `Localrec{ ident expr }                   -- only used for 'local function'
          | `Goto{ <string> }                         -- goto str
          | `Label{ <string> }                        -- ::str::
          | `Return{ <expr*> }                        -- return e1, e2...
          | `Break                                    -- break
          | apply

	expr:
            `Nil
          | `Dots
          | `Boolean{ <boolean> }
          | `Number{ <number> }
          | `String{ <string> }
          | `Function{ { `Id{ <string> }* `Dots? } block }
          | `Table{ ( `Pair{ expr expr } | expr )* }
          | `Op{ opid expr expr? }
          | `Paren{ expr }       -- significant to cut multiple values returns
          | apply
          | lhs

	apply:
             `Call{ expr expr* }
           | `Invoke{ expr `String{ <string> } expr* }

	lhs: `Id{ <string> } | `Index{ expr expr }

	opid:  -- includes additional operators from Lua 5.3
            'add'  | 'sub' | 'mul'  | 'div'
          | 'idiv' | 'mod' | 'pow'  | 'concat'
          | 'band' | 'bor' | 'bxor' | 'shl' | 'shr'
          | 'eq'   | 'lt'  | 'le'   | 'and' | 'or'
          | 'unm'  | 'len' | 'bnot' | 'not'


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

