#!/usr/bin/env lua

local metalua = false

if arg[1] == "metalua" then metalua = true end

local parser
if metalua then
  parser = require "metalua.compiler".new()
else
  parser = require "lua-parser.parser"
end
local pp = require "lua-parser.pp"

-- expected result, result, subject
local e, r, s

local filename = "test.lua"

local function parse (s)
  local t,m
  if metalua then
    t = parser:src_to_ast(s)
  else
    t,m = parser.parse(s,filename)
  end
  local r
  if not t then
    r = m
  else
    r = pp.tostring(t)
  end
  return r .. "\n"
end

local function fixint (s)
  return _VERSION < "Lua 5.3" and s:gsub("%.0","") or s
end

print("> testing lexer...")

-- syntax ok

-- empty files

s = [=[
]=]
e = [=[
{  }
]=]

r = parse(s)
assert(r == e)

s = [=[
-- testing empty file
]=]
e = [=[
{  }
]=]

r = parse(s)
assert(r == e)

-- expressions

s = [=[
_nil,_false,_true,_dots = nil,false,true,...
]=]
e = [=[
{ `Set{ { `Id "_nil", `Id "_false", `Id "_true", `Id "_dots" }, { `Nil, `False, `True, `Dots } } }
]=]

r = parse(s)
assert(r == e)

-- floating points

s = [=[
f1 = 1.
f2 = 1.1
]=]
e = [=[
{ `Set{ { `Id "f1" }, { `Number "1.0" } }, `Set{ { `Id "f2" }, { `Number "1.1" } } }
]=]

r = parse(s)
assert(r == fixint(e))

s = [=[
f1 = 1.e-1
f2 = 1.e1
]=]
e = [=[
{ `Set{ { `Id "f1" }, { `Number "0.1" } }, `Set{ { `Id "f2" }, { `Number "10.0" } } }
]=]

r = parse(s)
assert(r == fixint(e))

s = [=[
f1 = 1.1e+1
f2 = 1.1e1
]=]
e = [=[
{ `Set{ { `Id "f1" }, { `Number "11.0" } }, `Set{ { `Id "f2" }, { `Number "11.0" } } }
]=]

r = parse(s)
assert(r == fixint(e))

s = [=[
f1 = .1
f2 = .1e1
]=]
e = [=[
{ `Set{ { `Id "f1" }, { `Number "0.1" } }, `Set{ { `Id "f2" }, { `Number "1.0" } } }
]=]

r = parse(s)
assert(r == fixint(e))

s = [=[
f1 = 1E1
f2 = 1e-1
]=]
e = [=[
{ `Set{ { `Id "f1" }, { `Number "10.0" } }, `Set{ { `Id "f2" }, { `Number "0.1" } } }
]=]

r = parse(s)
assert(r == fixint(e))

-- integers

s = [=[
i = 1
h = 0xff
]=]
e = [=[
{ `Set{ { `Id "i" }, { `Number "1" } }, `Set{ { `Id "h" }, { `Number "255" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
h = 0x76c
i = 4294967296 -- 2^32
]=]
e = [=[
{ `Set{ { `Id "h" }, { `Number "1900" } }, `Set{ { `Id "i" }, { `Number "4294967296" } } }
]=]

r = parse(s)
assert(r == e)

-- long comments

s = [=[
--[======[
testing
long
comment
[==[ one ]==]
[===[ more ]===]
[====[ time ]====]
bye
]======]
]=]
e = [=[
{  }
]=]

r = parse(s)
assert(r == e)

-- long strings

s = [=[
--[[
testing long string1 begin
]]

ls1 =
[[
testing long string
]]

--[[
testing long string1 end
]]
]=]
e = [=[
{ `Set{ { `Id "ls1" }, { `String "testing long string\n" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
--[==[
testing long string2 begin
]==]

ls2 = [==[ testing \n [[ long ]] \t [===[ string ]===]
\a ]==]

--[==[
[[ testing long string2 end ]]
]==]
]=]
e = [=[
{ `Set{ { `Id "ls2" }, { `String " testing \\n [[ long ]] \\t [===[ string ]===]\n\\a " } } }
]=]

r = parse(s)
assert(r == e)

-- short strings

s = [=[
-- short string test begin

ss1_a = "ola mundo\a"
ss1_b = 'ola mundo\a'

-- short string test end
]=]
e = [=[
{ `Set{ { `Id "ss1_a" }, { `String "ola mundo\a" } }, `Set{ { `Id "ss1_b" }, { `String "ola mundo\a" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
-- short string test begin

ss2_a = "testando,\tteste\n1\n2\n3 --> \"tchau\""
ss2_b = 'testando,\tteste\n1\n2\n3 --> \'tchau\''

-- short string test end
]=]
e = [=[
{ `Set{ { `Id "ss2_a" }, { `String "testando,\tteste\n1\n2\n3 --> \"tchau\"" } }, `Set{ { `Id "ss2_b" }, { `String "testando,\tteste\n1\n2\n3 --> 'tchau'" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
-- short string test begin

ss3_a = "ola \
'mundo'!"

ss3_b = 'ola \
"mundo"!'

-- short string test end
]=]
e = [=[
{ `Set{ { `Id "ss3_a" }, { `String "ola \n'mundo'!" } }, `Set{ { `Id "ss3_b" }, { `String "ola \n\"mundo\"!" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
-- short string test begin

ss4_a = "C:\\Temp/"

ss4_b = 'C:\\Temp/'

-- short string test end
]=]
e = [=[
{ `Set{ { `Id "ss4_a" }, { `String "C:\\Temp/" } }, `Set{ { `Id "ss4_b" }, { `String "C:\\Temp/" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
-- short string test begin

lf = "\\n"

-- short string test end
]=]
e = [=[
{ `Set{ { `Id "lf" }, { `String "\\n" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
-- short string test begin

ss5_a = "ola \
mundo \\ \
cruel"

ss5_b = 'ola \
mundo \\ \
cruel'

-- short string test end
]=]
e = [=[
{ `Set{ { `Id "ss5_a" }, { `String "ola \nmundo \\ \ncruel" } }, `Set{ { `Id "ss5_b" }, { `String "ola \nmundo \\ \ncruel" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
-- short string test begin

s1 = 'a \z  b'
s2 = "adeus \z
      mundo\
\z    maravilhoso"

-- short string test end
]=]
e = [=[
{ `Set{ { `Id "s1" }, { `String "a b" } }, `Set{ { `Id "s2" }, { `String "adeus mundo\nmaravilhoso" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
-- short string test begin

deci = '\28'
hex = '\x1C'
uni = '\u{001C}'

-- short string test end
]=]
e = [=[
{ `Set{ { `Id "deci" }, { `String "\028" } }, `Set{ { `Id "hex" }, { `String "\028" } }, `Set{ { `Id "uni" }, { `String "\028" } } }
]=]

r = parse(s)
assert(r == e)

-- syntax error

if not metalua then

-- floating points

s = [=[
f = 9e
]=]
e = [=[
test.lua:2:1: syntax error, expected one or more digits for the exponent
]=]

r = parse(s)
assert(r == e)

s = [=[
f = 5.e
]=]
e = [=[
test.lua:2:1: syntax error, expected one or more digits for the exponent
]=]

r = parse(s)
assert(r == e)

s = [=[
f = .9e-
]=]
e = [=[
test.lua:2:1: syntax error, expected one or more digits for the exponent
]=]

r = parse(s)
assert(r == e)

s = [=[
f = 5.9e+
]=]
e = [=[
test.lua:2:1: syntax error, expected one or more digits for the exponent
]=]

r = parse(s)
assert(r == e)

-- integers

s = [=[
-- invalid hexadecimal number

hex = 0xG
]=]
e = [=[
test.lua:3:9: syntax error, expected one or more hexadecimal digits after '0x'
]=]

r = parse(s)
assert(r == e)

-- long strings

s = [=[
--[==[
testing long string3 begin
]==]

ls3 = [===[
testing
unfinised
long string
]==]

--[==[
[[ testing long string3 end ]]
]==]
]=]
e = [=[
test.lua:14:1: syntax error, unclosed long string
]=]

r = parse(s)
assert(r == e)

-- short strings

s = [=[
-- short string test begin

ss6 = "testing unfinished string

-- short string test end
]=]
e = [=[
test.lua:4:1: syntax error, unclosed string
]=]

r = parse(s)
assert(r == e)

s = [=[
-- short string test begin

ss7 = 'testing \\
unfinished \\
string'

-- short string test end
]=]
e = [=[
test.lua:4:1: syntax error, unclosed string
]=]

r = parse(s)
assert(r == e)

-- unfinished comments

s = [=[
--[[ testing
unfinished
comment
]=]
e = [=[
test.lua:4:1: syntax error, unclosed long string
]=]

r = parse(s)
assert(r == e)

end

print("> testing parser...")

-- syntax ok

-- anonymous functions

s = [=[
local a,b,c = function () end
]=]
e = [=[
{ `Local{ { `Id "a", `Id "b", `Id "c" }, { `Function{ {  }, {  } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local test = function ( a , b , ... ) end
]=]
e = [=[
{ `Local{ { `Id "test" }, { `Function{ { `Id "a", `Id "b", `Dots }, {  } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
test = function (...) return ...,0 end
]=]
e = [=[
{ `Set{ { `Id "test" }, { `Function{ { `Dots }, { `Return{ `Dots, `Number "0" } } } } } }
]=]

r = parse(s)
assert(r == e)

-- arithmetic expressions

s = [=[
arithmetic = 1 - 2 * 3 + 4
]=]
e = [=[
{ `Set{ { `Id "arithmetic" }, { `Op{ "add", `Op{ "sub", `Number "1", `Op{ "mul", `Number "2", `Number "3" } }, `Number "4" } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
pow = -3^-2^2
]=]
e = [=[
{ `Set{ { `Id "pow" }, { `Op{ "unm", `Op{ "pow", `Number "3", `Op{ "unm", `Op{ "pow", `Number "2", `Number "2" } } } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
q, r, f = 3//2, 3%2, 3/2
]=]
e = [=[
{ `Set{ { `Id "q", `Id "r", `Id "f" }, { `Op{ "idiv", `Number "3", `Number "2" }, `Op{ "mod", `Number "3", `Number "2" }, `Op{ "div", `Number "3", `Number "2" } } } }
]=]

r = parse(s)
assert(r == e)

-- assignments

s = [=[
a = f()[1]
]=]
e = [=[
{ `Set{ { `Id "a" }, { `Index{ `Call{ `Id "f" }, `Number "1" } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
a()[1] = 1;
]=]
e = [=[
{ `Set{ { `Index{ `Call{ `Id "a" }, `Number "1" } }, { `Number "1" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
i = a.f(1)
]=]
e = [=[
{ `Set{ { `Id "i" }, { `Call{ `Index{ `Id "a", `String "f" }, `Number "1" } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
i = a[f(1)]
]=]
e = [=[
{ `Set{ { `Id "i" }, { `Index{ `Id "a", `Call{ `Id "f", `Number "1" } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
a[f()] = sub
i = i + 1
]=]
e = [=[
{ `Set{ { `Index{ `Id "a", `Call{ `Id "f" } } }, { `Id "sub" } }, `Set{ { `Id "i" }, { `Op{ "add", `Id "i", `Number "1" } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
a:b(1)._ = some_value
]=]
e = [=[
{ `Set{ { `Index{ `Invoke{ `Id "a", `String "b", `Number "1" }, `String "_" } }, { `Id "some_value" } } }
]=]

r = parse(s)
assert(r == e)

-- bitwise expressions

s = [=[
b = 1 & 0 | 1 ~ 1
]=]
e = [=[
{ `Set{ { `Id "b" }, { `Op{ "bor", `Op{ "band", `Number "1", `Number "0" }, `Op{ "bxor", `Number "1", `Number "1" } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
b = 1 & 0 | 1 >> 1 ~ 1
]=]
e = [=[
{ `Set{ { `Id "b" }, { `Op{ "bor", `Op{ "band", `Number "1", `Number "0" }, `Op{ "bxor", `Op{ "shr", `Number "1", `Number "1" }, `Number "1" } } } } }
]=]

r = parse(s)
assert(r == e)

-- break

s = [=[
while 1 do
  break
end
]=]
e = [=[
{ `While{ `Number "1", { `Break } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
while 1 do
  while 1 do
    break
  end
  break
end
]=]
e = [=[
{ `While{ `Number "1", { `While{ `Number "1", { `Break } }, `Break } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
repeat
  if 2 > 1 then break end
until 1
]=]
e = [=[
{ `Repeat{ { `If{ `Op{ "lt", `Number "1", `Number "2" }, { `Break } } }, `Number "1" } }
]=]

r = parse(s)
assert(r == e)

s = [=[
for i=1,10 do
  do
    break
    break
    return
  end
end
]=]
e = [=[
{ `Fornum{ `Id "i", `Number "1", `Number "10", { `Do{ `Break, `Break, `Return } } } }
]=]

r = parse(s)
assert(r == e)

-- block statements

s = [=[
do
  var = 2+2;
  return
end
]=]
e = [=[
{ `Do{ `Set{ { `Id "var" }, { `Op{ "add", `Number "2", `Number "2" } } }, `Return } }
]=]

r = parse(s)
assert(r == e)

-- concatenation expressions

s = [=[
concat1 = 1 .. 2^3
]=]
e = [=[
{ `Set{ { `Id "concat1" }, { `Op{ "concat", `Number "1", `Op{ "pow", `Number "2", `Number "3" } } } } }
]=]

r = parse(s)
assert(r == e)

-- empty files

if not metalua then

s = [=[
;
]=]
e = [=[
{  }
]=]

end

r = parse(s)
assert(r == e)

-- for generic

s = [=[
for k,v in pairs(t) do print (k,v) end
]=]
e = [=[
{ `Forin{ { `Id "k", `Id "v" }, { `Call{ `Id "pairs", `Id "t" } }, { `Call{ `Id "print", `Id "k", `Id "v" } } } }
]=]

r = parse(s)
assert(r == e)

-- for numeric

s = [=[
for i = 1 , 10 , 2 do end
]=]
e = [=[
{ `Fornum{ `Id "i", `Number "1", `Number "10", `Number "2", {  } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
for i=1,10 do end
]=]
e = [=[
{ `Fornum{ `Id "i", `Number "1", `Number "10", {  } } }
]=]

r = parse(s)
assert(r == e)

-- global functions

s = [=[
function test(a , b , ...) end
]=]
e = [=[
{ `Set{ { `Id "test" }, { `Function{ { `Id "a", `Id "b", `Dots }, {  } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
function test (...) end
]=]
e = [=[
{ `Set{ { `Id "test" }, { `Function{ { `Dots }, {  } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
function t.a:b() end
]=]
e = [=[
{ `Set{ { `Index{ `Index{ `Id "t", `String "a" }, `String "b" } }, { `Function{ { `Id "self" }, {  } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
function t.a() end
]=]
e = [=[
{ `Set{ { `Index{ `Id "t", `String "a" } }, { `Function{ {  }, {  } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
function testando . funcao . com : espcacos ( e, com , parametros, ... ) end
]=]
e = [=[
{ `Set{ { `Index{ `Index{ `Index{ `Id "testando", `String "funcao" }, `String "com" }, `String "espcacos" } }, { `Function{ { `Id "self", `Id "e", `Id "com", `Id "parametros", `Dots }, {  } } } } }
]=]

r = parse(s)
assert(r == e)

-- goto

if not metalua then

s = [=[
goto label
:: label :: return
]=]
e = [=[
{ `Goto{ "label" }, `Label{ "label" }, `Return }
]=]

r = parse(s)
assert(r == e)

s = [=[
::label::
goto label
]=]
e = [=[
{ `Label{ "label" }, `Goto{ "label" } }
]=]

r = parse(s)
assert(r == e)

s = [=[
goto label
::label::
]=]
e = [=[
{ `Goto{ "label" }, `Label{ "label" } }
]=]

r = parse(s)
assert(r == e)

s = [=[
::label::
do ::label:: goto label end
]=]
e = [=[
{ `Label{ "label" }, `Do{ `Label{ "label" }, `Goto{ "label" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
::label::
do goto label ; ::label:: end
]=]
e = [=[
{ `Label{ "label" }, `Do{ `Goto{ "label" }, `Label{ "label" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
::label::
do goto label end
]=]
e = [=[
{ `Label{ "label" }, `Do{ `Goto{ "label" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
do goto label end
::label::
]=]
e = [=[
{ `Do{ `Goto{ "label" } }, `Label{ "label" } }
]=]

r = parse(s)
assert(r == e)

s = [=[
do do do do do goto label end end end end end
::label::
]=]
e = [=[
{ `Do{ `Do{ `Do{ `Do{ `Do{ `Goto{ "label" } } } } } }, `Label{ "label" } }
]=]

r = parse(s)
assert(r == e)

end

-- if-else

s = [=[
if a then end
]=]
e = [=[
{ `If{ `Id "a", {  } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
if a then return a else return end
]=]
e = [=[
{ `If{ `Id "a", { `Return{ `Id "a" } }, { `Return } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
if a then
  return a
else
  local c = d
  d = d + 1
  return d
end
]=]
e = [=[
{ `If{ `Id "a", { `Return{ `Id "a" } }, { `Local{ { `Id "c" }, { `Id "d" } }, `Set{ { `Id "d" }, { `Op{ "add", `Id "d", `Number "1" } } }, `Return{ `Id "d" } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
if a then
  return a
elseif b then
  return b
elseif c then
  return c
end
]=]
e = [=[
{ `If{ `Id "a", { `Return{ `Id "a" } }, `Id "b", { `Return{ `Id "b" } }, `Id "c", { `Return{ `Id "c" } } } }
]=]

r = parse(s)
assert(r == e)

if not metalua then

s = [=[
if a then return a
elseif b then return
else ;
end
]=]
e = [=[
{ `If{ `Id "a", { `Return{ `Id "a" } }, `Id "b", { `Return }, {  } } }
]=]

r = parse(s)
assert(r == e)

end

s = [=[
if a then
  return
elseif c then
end
]=]
e = [=[
{ `If{ `Id "a", { `Return }, `Id "c", {  } } }
]=]

r = parse(s)
assert(r == e)

-- labels

if not metalua then

s = [=[
::label::
do ::label:: end
::other_label::
]=]
e = [=[
{ `Label{ "label" }, `Do{ `Label{ "label" } }, `Label{ "other_label" } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local x = glob
::label::
foo()
]=]
e = [=[
{ `Local{ { `Id "x" }, { `Id "glob" } }, `Label{ "label" }, `Call{ `Id "foo" } }
]=]

r = parse(s)
assert(r == e)

end

-- locals

s = [=[
local a
]=]
e = [=[
{ `Local{ { `Id "a" }, {  } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local a,b,c
]=]
e = [=[
{ `Local{ { `Id "a", `Id "b", `Id "c" }, {  } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local a = 1 , 1 + 2, 5.1
]=]
e = [=[
{ `Local{ { `Id "a" }, { `Number "1", `Op{ "add", `Number "1", `Number "2" }, `Number "5.1" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local a,b,c = 1.9
]=]
e = [=[
{ `Local{ { `Id "a", `Id "b", `Id "c" }, { `Number "1.9" } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local function test() end
]=]
e = [=[
{ `Localrec{ { `Id "test" }, { `Function{ {  }, {  } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local function test ( a , b , c , ... ) end
]=]
e = [=[
{ `Localrec{ { `Id "test" }, { `Function{ { `Id "a", `Id "b", `Id "c", `Dots }, {  } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local function test(...) return ... end
]=]
e = [=[
{ `Localrec{ { `Id "test" }, { `Function{ { `Dots }, { `Return{ `Dots } } } } } }
]=]

r = parse(s)
assert(r == e)

-- relational expressions

s = [=[
relational = 1 < 2 >= 3 == 4 ~= 5 < 6 <= 7
]=]
e = [=[
{ `Set{ { `Id "relational" }, { `Op{ "le", `Op{ "lt", `Op{ "not", `Op{ "eq", `Op{ "eq", `Op{ "le", `Number "3", `Op{ "lt", `Number "1", `Number "2" } }, `Number "4" }, `Number "5" } }, `Number "6" }, `Number "7" } } } }
]=]

r = parse(s)
assert(r == e)

-- repeat

s = [=[
repeat
  a,b,c = 1+1,2+2,3+3
  break
until a < 1
]=]
e = [=[
{ `Repeat{ { `Set{ { `Id "a", `Id "b", `Id "c" }, { `Op{ "add", `Number "1", `Number "1" }, `Op{ "add", `Number "2", `Number "2" }, `Op{ "add", `Number "3", `Number "3" } } }, `Break }, `Op{ "lt", `Id "a", `Number "1" } } }
]=]

r = parse(s)
assert(r == e)

-- return

s = [=[
return
]=]
e = [=[
{ `Return }
]=]

r = parse(s)
assert(r == e)

s = [=[
return 1
]=]
e = [=[
{ `Return{ `Number "1" } }
]=]

r = parse(s)
assert(r == e)

s = [=[
return 1,1-2*3+4,"alo"
]=]
e = [=[
{ `Return{ `Number "1", `Op{ "add", `Op{ "sub", `Number "1", `Op{ "mul", `Number "2", `Number "3" } }, `Number "4" }, `String "alo" } }
]=]

r = parse(s)
assert(r == e)

s = [=[
return;
]=]
e = [=[
{ `Return }
]=]

r = parse(s)
assert(r == e)

s = [=[
return 1;
]=]
e = [=[
{ `Return{ `Number "1" } }
]=]

r = parse(s)
assert(r == e)

s = [=[
return 1,1-2*3+4,"alo";
]=]
e = [=[
{ `Return{ `Number "1", `Op{ "add", `Op{ "sub", `Number "1", `Op{ "mul", `Number "2", `Number "3" } }, `Number "4" }, `String "alo" } }
]=]

r = parse(s)
assert(r == e)

-- tables

s = [=[
t = { [1] = "alo", alo = 1, 2; }
]=]
e = [=[
{ `Set{ { `Id "t" }, { `Table{ `Pair{ `Number "1", `String "alo" }, `Pair{ `String "alo", `Number "1" }, `Number "2" } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
t = { 1.5 }
]=]
e = [=[
{ `Set{ { `Id "t" }, { `Table{ `Number "1.5" } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
t = {1,2;
3,
4,



5}
]=]
e = [=[
{ `Set{ { `Id "t" }, { `Table{ `Number "1", `Number "2", `Number "3", `Number "4", `Number "5" } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
t = {[1]=1,[2]=2;
[3]=3,
[4]=4,



[5]=5}
]=]
e = [=[
{ `Set{ { `Id "t" }, { `Table{ `Pair{ `Number "1", `Number "1" }, `Pair{ `Number "2", `Number "2" }, `Pair{ `Number "3", `Number "3" }, `Pair{ `Number "4", `Number "4" }, `Pair{ `Number "5", `Number "5" } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local t = {{{}}, {"alo"}}
]=]
e = [=[
{ `Local{ { `Id "t" }, { `Table{ `Table{ `Table }, `Table{ `String "alo" } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local x = 0
local t = {x}
]=]
e = [=[
{ `Local{ { `Id "x" }, { `Number "0" } }, `Local{ { `Id "t" }, { `Table{ `Id "x" } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local x = 0
local t = {x = 1}
]=]
e = [=[
{ `Local{ { `Id "x" }, { `Number "0" } }, `Local{ { `Id "t" }, { `Table{ `Pair{ `String "x", `Number "1" } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local x = 0
local t = {x == 1}
]=]
e = [=[
{ `Local{ { `Id "x" }, { `Number "0" } }, `Local{ { `Id "t" }, { `Table{ `Op{ "eq", `Id "x", `Number "1" } } } } }
]=]

r = parse(s)
assert(r == e)

-- vararg

s = [=[
function f (...)
  return ...
end
]=]
e = [=[
{ `Set{ { `Id "f" }, { `Function{ { `Dots }, { `Return{ `Dots } } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
function f ()
  function g (x, y, ...)
    return ...,...,...
  end
end
]=]
e = [=[
{ `Set{ { `Id "f" }, { `Function{ {  }, { `Set{ { `Id "g" }, { `Function{ { `Id "x", `Id "y", `Dots }, { `Return{ `Dots, `Dots, `Dots } } } } } } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local function f (x, ...)
  return ...
end
]=]
e = [=[
{ `Localrec{ { `Id "f" }, { `Function{ { `Id "x", `Dots }, { `Return{ `Dots } } } } } }
]=]

r = parse(s)
assert(r == e)

s = [=[
local f = function (x, ...)
  return ...
end
]=]
e = [=[
{ `Local{ { `Id "f" }, { `Function{ { `Id "x", `Dots }, { `Return{ `Dots } } } } } }
]=]

r = parse(s)
assert(r == e)

-- while

s = [=[
i = 0
while (i < 10)
do
  i = i + 1
end
]=]
e = [=[
{ `Set{ { `Id "i" }, { `Number "0" } }, `While{ `Paren{ `Op{ "lt", `Id "i", `Number "10" } }, { `Set{ { `Id "i" }, { `Op{ "add", `Id "i", `Number "1" } } } } } }
]=]

r = parse(s)
assert(r == e)

-- syntax error

if not metalua then

-- anonymous functions

s = [=[
a = function (a,b,) end
]=]
e = [=[
test.lua:1:19: syntax error, expected a variable name or '...' after ','
]=]

r = parse(s)
assert(r == e)

s = [=[
a = function (...,a) end
]=]
e = [=[
test.lua:1:18: syntax error, expected ')' to close the parameter list
]=]

r = parse(s)
assert(r == e)

s = [=[
local a = function (1) end
]=]
e = [=[
test.lua:1:21: syntax error, expected ')' to close the parameter list
]=]

r = parse(s)
assert(r == e)

s = [=[
local test = function ( a , b , c , ... )
]=]
e = [=[
test.lua:2:1: syntax error, expected 'end' to close the function body
]=]

r = parse(s)
assert(r == e)

-- arithmetic expressions

s = [=[
a = 3 / / 2
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the multiplicative operator
]=]

r = parse(s)
assert(r == e)

-- bitwise expressions

s = [=[
b = 1 && 1
]=]
e = [=[
test.lua:1:8: syntax error, expected an expression after '&'
]=]

r = parse(s)
assert(r == e)

s = [=[
b = 1 <> 0
]=]
e = [=[
test.lua:1:8: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

s = [=[
b = 1 < < 0
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

-- break

s = [=[
break
]=]
e = [=[
test.lua:1:1: syntax error, <break> not inside a loop
]=]

r = parse(s)
assert(r == e)

s = [=[
function f (x)
  if 1 then break end
end
]=]
e = [=[
test.lua:2:13: syntax error, <break> not inside a loop
]=]

r = parse(s)
assert(r == e)

s = [=[
while 1 do
end
break
]=]
e = [=[
test.lua:3:1: syntax error, <break> not inside a loop
]=]

r = parse(s)
assert(r == e)

-- concatenation expressions

s = [=[
concat2 = 2^3..1
]=]
e = [=[
test.lua:1:15: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
local s = "1 + 1 = "
print(s .. 1+1)
]=]
e = [=[
{ `Local{ { `Id "s" }, { `String "1 + 1 = " } }, `Call{ `Id "print", `Op{ "concat", `Id "s", `Op{ "add", `Number "1", `Number "1" } } } }
]=]

r = parse(s)
assert(r == e)

-- for generic

s = [=[
for k;v in pairs(t) do end
]=]
e = [=[
test.lua:1:6: syntax error, expected '=' or 'in' after the variable(s)
]=]

r = parse(s)
assert(r == e)

s = [=[
for k,v in pairs(t:any) do end
]=]
e = [=[
test.lua:1:23: syntax error, expected some arguments for the method call (or '()')
]=]

r = parse(s)
assert(r == e)

-- for numeric

s = [=[
for i=1,10, do end
]=]
e = [=[
test.lua:1:13: syntax error, expected a step expression for the numeric range after ','
]=]

r = parse(s)
assert(r == e)

s = [=[
for i=1,n:number do end
]=]
e = [=[
test.lua:1:18: syntax error, expected some arguments for the method call (or '()')
]=]

r = parse(s)
assert(r == e)

-- global functions

s = [=[
function func(a,b,c,) end
]=]
e = [=[
test.lua:1:21: syntax error, expected a variable name or '...' after ','
]=]

r = parse(s)
assert(r == e)

s = [=[
function func(...,a) end
]=]
e = [=[
test.lua:1:18: syntax error, expected ')' to close the parameter list
]=]

r = parse(s)
assert(r == e)

s = [=[
function a.b:c:d () end
]=]
e = [=[
test.lua:1:15: syntax error, expected '(' for the parameter list
]=]

r = parse(s)
assert(r == e)

-- goto

s = [=[
:: label :: return
goto label
]=]
e = [=[
test.lua:2:1: syntax error, unexpected character(s), expected EOF
]=]

r = parse(s)
assert(r == e)

s = [=[
goto label
]=]
e = [=[
test.lua:1:1: syntax error, no visible label 'label' for <goto>
]=]

r = parse(s)
assert(r == e)

s = [=[
goto label
::other_label::
]=]
e = [=[
test.lua:1:1: syntax error, no visible label 'label' for <goto>
]=]

r = parse(s)
assert(r == e)

s = [=[
::other_label::
do do do goto label end end end
]=]
e = [=[
test.lua:2:10: syntax error, no visible label 'label' for <goto>
]=]

r = parse(s)
assert(r == e)

-- if-else

s = [=[
if a then
]=]
e = [=[
test.lua:2:1: syntax error, expected 'end' to close the if statement
]=]

r = parse(s)
assert(r == e)

s = [=[
if a then else
]=]
e = [=[
test.lua:2:1: syntax error, expected 'end' to close the if statement
]=]

r = parse(s)
assert(r == e)

s = [=[
if a then
  return a
elseif b then
  return b
elseif

end
]=]
e = [=[
test.lua:7:1: syntax error, expected a condition after 'elseif'
]=]

r = parse(s)
assert(r == e)

s = [=[
if a:any then else end
]=]
e = [=[
test.lua:1:10: syntax error, expected some arguments for the method call (or '()')
]=]

r = parse(s)
assert(r == e)

-- labels

s = [=[
:: blah ::
:: not ::
]=]
e = [=[
test.lua:2:4: syntax error, expected a label name after '::'
]=]

r = parse(s)
assert(r == e)

s = [=[
::label::
::other_label::
::label::
]=]
e = [=[
test.lua:3:1: syntax error, label 'label' already defined at line 1
]=]

r = parse(s)
assert(r == e)

-- locals

s = [=[
local a =
]=]
e = [=[
test.lua:2:1: syntax error, expected one or more expressions after '='
]=]

r = parse(s)
assert(r == e)

s = [=[
local function t.a() end
]=]
e = [=[
test.lua:1:17: syntax error, expected '(' for the parameter list
]=]

r = parse(s)
assert(r == e)

s = [=[
local function test (a,) end
]=]
e = [=[
test.lua:1:24: syntax error, expected a variable name or '...' after ','
]=]

r = parse(s)
assert(r == e)

s = [=[
local function test(...,a) end
]=]
e = [=[
test.lua:1:24: syntax error, expected ')' to close the parameter list
]=]

r = parse(s)
assert(r == e)

s = [=[
local function (a, b, c, ...) end
]=]
e = [=[
test.lua:1:16: syntax error, expected a function name after 'function'
]=]

r = parse(s)
assert(r == e)

-- repeat

s = [=[
repeat
  a,b,c = 1+1,2+2,3+3
  break
]=]
e = [=[
test.lua:4:1: syntax error, expected 'until' at the end of the repeat loop
]=]

r = parse(s)
assert(r == e)

-- return

s = [=[
return
return 1
return 1,1-2*3+4,"alo"
return;
return 1;
return 1,1-2*3+4,"alo";
]=]
e = [=[
test.lua:2:1: syntax error, unexpected character(s), expected EOF
]=]

r = parse(s)
assert(r == e)

-- tables

s = [=[
t = { , }
]=]
e = [=[
test.lua:1:7: syntax error, expected '}' to close the table constructor
]=]

r = parse(s)
assert(r == e)

-- vararg

s = [=[
function f ()
  return ...
end
]=]
e = [=[
test.lua:2:10: syntax error, cannot use '...' outside a vararg function
]=]

r = parse(s)
assert(r == e)

s = [=[
function f ()
  function g (x, y)
    return ...,...,...
  end
end
]=]
e = [=[
test.lua:3:12: syntax error, cannot use '...' outside a vararg function
]=]

r = parse(s)
assert(r == e)

s = [=[
local function f (x)
  return ...
end
]=]
e = [=[
test.lua:2:10: syntax error, cannot use '...' outside a vararg function
]=]

r = parse(s)
assert(r == e)

s = [=[
local f = function (x)
  return ...
end
]=]
e = [=[
test.lua:2:10: syntax error, cannot use '...' outside a vararg function
]=]

r = parse(s)
assert(r == e)

-- while

s = [=[
i = 0
while (i < 10)
  i = i + 1
end
]=]
e = [=[
test.lua:3:3: syntax error, expected 'do' after the condition
]=]

r = parse(s)
assert(r == e)

end

if not metalua then

print("> testing more syntax errors...")

-- ErrExtra
s = [=[
return; print("hello")
]=]
e = [=[
test.lua:1:9: syntax error, unexpected character(s), expected EOF
]=]

r = parse(s)
assert(r == e)

s = [=[
while foo do if bar then baz() end end end
]=]
e = [=[
test.lua:1:40: syntax error, unexpected character(s), expected EOF
]=]

r = parse(s)
assert(r == e)

s = [=[
local func f()
  g()
end
]=]
e = [=[
test.lua:3:1: syntax error, unexpected character(s), expected EOF
]=]

r = parse(s)
assert(r == e)

s = [=[
function qux()
  if false then
    -- do
    return 0
    end
  end
  return 1
end
print(qux())
]=]
e = [=[
test.lua:8:1: syntax error, unexpected character(s), expected EOF
]=]

r = parse(s)
assert(r == e)

-- ErrInvalidStat
s = [=[
find_solution() ? print("yes") : print("no")
]=]
e = [=[
test.lua:1:17: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
local i : int = 0
]=]
e = [=[
test.lua:1:9: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
local a = 1, b = 2
]=]
e = [=[
test.lua:1:16: syntax error, unexpected token, invalid start of statement
]=]

s = [=[
x = -
y = 2
]=]
e = [=[
test.lua:2:3: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
obj::hello()
]=]
e = [=[
test.lua:1:1: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
while foo() do
  // not a lua comment
  bar()
end
]=]
e = [=[
test.lua:2:3: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
repeat:
  action()
until condition
end
]=]
e = [=[
test.lua:1:7: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
function f(x)
  local result
  ... -- TODO: compute for the next result
  return result
end
]=]
e = [=[
test.lua:3:3: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
x;
]=]
e = [=[
test.lua:1:1: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
a, b, c
]=]
e = [=[
test.lua:1:1: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
local x = 42 // the meaning of life
]=]
e = [=[
test.lua:1:21: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
let x = 2
]=]
e = [=[
test.lua:1:1: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
if p then
  f()
elif q then
  g()
end
]=]
e = [=[
test.lua:3:1: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

s = [=[
function foo()
  bar()
emd
]=]
e = [=[
test.lua:3:1: syntax error, unexpected token, invalid start of statement
]=]

r = parse(s)
assert(r == e)

-- ErrEndIf
s = [=[
if 1 > 2 then print("impossible")
]=]
e = [=[
test.lua:2:1: syntax error, expected 'end' to close the if statement
]=]

r = parse(s)
assert(r == e)

s = [=[
if 1 > 2 then return; print("impossible") end
]=]
e = [=[
test.lua:1:23: syntax error, expected 'end' to close the if statement
]=]

r = parse(s)
assert(r == e)

s = [=[
if condA then doThis()
else if condB then doThat() end
]=]
e = [=[
test.lua:3:1: syntax error, expected 'end' to close the if statement
]=]

r = parse(s)
assert(r == e)

s = [=[
if a then
  b()
else
  c()
else
  d()
end
]=]
e = [=[
test.lua:5:1: syntax error, expected 'end' to close the if statement
]=]

r = parse(s)
assert(r == e)

-- ErrExprIf
s = [=[
if then print("that") end
]=]
e = [=[
test.lua:1:4: syntax error, expected a condition after 'if'
]=]

r = parse(s)
assert(r == e)

s = [=[
if !ok then error("fail") end
]=]
e = [=[
test.lua:1:4: syntax error, expected a condition after 'if'
]=]

r = parse(s)
assert(r == e)

-- ErrThenIf
s = [=[
if age < 18
  print("too young!")
end
]=]
e = [=[
test.lua:2:3: syntax error, expected 'then' after the condition
]=]

r = parse(s)
assert(r == e)

-- ErrExprEIf
s = [=[
if age < 18 then print("too young!")
elseif then print("too old") end
]=]
e = [=[
test.lua:2:8: syntax error, expected a condition after 'elseif'
]=]

r = parse(s)
assert(r == e)

-- ErrThenEIf
s = [=[
if not result then error("fail")
elseif result > 0:
  process(result)
end
]=]
e = [=[
test.lua:2:18: syntax error, expected 'then' after the condition
]=]

r = parse(s)
assert(r == e)

-- ErrEndDo
s = [=[
do something()
]=]
e = [=[
test.lua:2:1: syntax error, expected 'end' to close the do block
]=]

r = parse(s)
assert(r == e)

s = [=[
do
  return arr[i]
  i = i + 1
end
]=]
e = [=[
test.lua:3:3: syntax error, expected 'end' to close the do block
]=]

r = parse(s)
assert(r == e)

-- ErrExprWhile
s = [=[
while !done do done = work() end
]=]
e = [=[
test.lua:1:7: syntax error, expected a condition after 'while'
]=]

r = parse(s)
assert(r == e)

s = [=[
while do print("hello again!") end
]=]
e = [=[
test.lua:1:7: syntax error, expected a condition after 'while'
]=]

r = parse(s)
assert(r == e)

-- ErrDoWhile
s = [=[
while not done then work() end
]=]
e = [=[
test.lua:1:16: syntax error, expected 'do' after the condition
]=]

r = parse(s)
assert(r == e)

s = [=[
while not done
  work()
end
]=]
e = [=[
test.lua:2:3: syntax error, expected 'do' after the condition
]=]

r = parse(s)
assert(r == e)

-- ErrEndWhile
s = [=[
while not found do i = i + 1
]=]
e = [=[
test.lua:2:1: syntax error, expected 'end' to close the while loop
]=]

r = parse(s)
assert(r == e)

s = [=[
while i < #arr do
  if arr[i] == target then break
  i = i +1
end
]=]
e = [=[
test.lua:5:1: syntax error, expected 'end' to close the while loop
]=]

r = parse(s)
assert(r == e)

-- ErrUntilRep
s = [=[
repeat play_song()
]=]
e = [=[
test.lua:2:1: syntax error, expected 'until' at the end of the repeat loop
]=]

r = parse(s)
assert(r == e)

-- ErrExprRep
s = [=[
repeat film() until end
]=]
e = [=[
test.lua:1:21: syntax error, expected a conditions after 'until'
]=]

r = parse(s)
assert(r == e)

-- ErrForRange
s = [=[
for (key, val) in obj do
  print(key .. " -> " .. val)
end
]=]
e = [=[
test.lua:1:5: syntax error, expected a numeric or generic range after 'for'
]=]

r = parse(s)
assert(r == e)

-- ErrEndFor
s = [=[
for i = 1,10 do print(i)
]=]
e = [=[
test.lua:2:1: syntax error, expected 'end' to close the for loop
]=]

r = parse(s)
assert(r == e)

-- ErrExprFor1
s = [=[
for i = ,10 do print(i) end
]=]
e = [=[
test.lua:1:9: syntax error, expected a starting expression for the numeric range
]=]

r = parse(s)
assert(r == e)

-- ErrCommaFor
s = [=[
for i = 1 to 10 do print(i) end
]=]
e = [=[
test.lua:1:11: syntax error, expected ',' to split the start and end of the range
]=]

r = parse(s)
assert(r == e)

-- ErrExprFor2
s = [=[
for i = 1, do print(i) end
]=]
e = [=[
test.lua:1:12: syntax error, expected an ending expression for the numeric range
]=]

r = parse(s)
assert(r == e)

-- ErrExprFor3
s = [=[
for i = 1,10, do print(i) end
]=]
e = [=[
test.lua:1:15: syntax error, expected a step expression for the numeric range after ','
]=]

r = parse(s)
assert(r == e)

-- ErrInFor
s = [=[
for arr do print(arr[i]) end
]=]
e = [=[
test.lua:1:9: syntax error, expected '=' or 'in' after the variable(s)
]=]

r = parse(s)
assert(r == e)

s = [=[
for nums := 1,10 do print(i) end
]=]
e = [=[
test.lua:1:10: syntax error, expected '=' or 'in' after the variable(s)
]=]

r = parse(s)
assert(r == e)

-- ErrEListFor
s = [=[
for i in ? do print(i) end
]=]
e = [=[
test.lua:1:10: syntax error, expected one or more expressions after 'in'
]=]

r = parse(s)
assert(r == e)

-- ErrDoFor
s = [=[
for i = 1,10 doo print(i) end
]=]
e = [=[
test.lua:1:14: syntax error, expected 'do' after the range of the for loop
]=]

r = parse(s)
assert(r == e)

s = [=[
for _, elem in ipairs(list)
  print(elem)
end
]=]
e = [=[
test.lua:2:3: syntax error, expected 'do' after the range of the for loop
]=]

r = parse(s)
assert(r == e)

-- ErrDefLocal
s = [=[
local
]=]
e = [=[
test.lua:2:1: syntax error, expected a function definition or assignment after local
]=]

r = parse(s)
assert(r == e)

s = [=[
local; x = 2
]=]
e = [=[
test.lua:1:6: syntax error, expected a function definition or assignment after local
]=]

r = parse(s)
assert(r == e)

s = [=[
local *p = nil
]=]
e = [=[
test.lua:1:7: syntax error, expected a function definition or assignment after local
]=]

r = parse(s)
assert(r == e)

-- ErrNameLFunc
s = [=[
local function() return 0 end
]=]
e = [=[
test.lua:1:15: syntax error, expected a function name after 'function'
]=]

r = parse(s)
assert(r == e)

s = [=[
local function 3dprint(x, y, z) end
]=]
e = [=[
test.lua:1:16: syntax error, expected a function name after 'function'
]=]

r = parse(s)
assert(r == e)

s = [=[
local function repeat(f, ntimes) for i = 1,ntimes do f() end end
]=]
e = [=[
test.lua:1:16: syntax error, expected a function name after 'function'
]=]

r = parse(s)
assert(r == e)

-- ErrEListLAssign
s = [=[
local x = ?
]=]
e = [=[
test.lua:1:11: syntax error, expected one or more expressions after '='
]=]

r = parse(s)
assert(r == e)

-- ErrEListAssign
s = [=[
x = ?
]=]
e = [=[
test.lua:1:5: syntax error, expected one or more expressions after '='
]=]

r = parse(s)
assert(r == e)

-- ErrFuncName
s = [=[
function() return 0 end
]=]
e = [=[
test.lua:1:9: syntax error, expected a function name after 'function'
]=]

r = parse(s)
assert(r == e)

s = [=[
function 3dprint(x, y, z) end
]=]
e = [=[
test.lua:1:10: syntax error, expected a function name after 'function'
]=]

r = parse(s)
assert(r == e)

s = [=[
function repeat(f, ntimes) for i = 1,ntimes do f() end end
]=]
e = [=[
test.lua:1:10: syntax error, expected a function name after 'function'
]=]

r = parse(s)
assert(r == e)

-- ErrNameFunc1
s = [=[
function foo.() end
]=]
e = [=[
test.lua:1:14: syntax error, expected a function name after '.'
]=]

r = parse(s)
assert(r == e)

s = [=[
function foo.1() end
]=]
e = [=[
test.lua:1:14: syntax error, expected a function name after '.'
]=]

r = parse(s)
assert(r == e)

-- ErrNameFunc2
s = [=[
function foo:() end
]=]
e = [=[
test.lua:1:14: syntax error, expected a method name after ':'
]=]

r = parse(s)
assert(r == e)

s = [=[
function foo:1() end
]=]
e = [=[
test.lua:1:14: syntax error, expected a method name after ':'
]=]

r = parse(s)
assert(r == e)

-- ErrOParenPList
s = [=[
function foo
  return bar
end
]=]
e = [=[
test.lua:2:3: syntax error, expected '(' for the parameter list
]=]

r = parse(s)
assert(r == e)

s = [=[
function foo?(bar)
  return bar
end
]=]
e = [=[
test.lua:1:13: syntax error, expected '(' for the parameter list
]=]

r = parse(s)
assert(r == e)

-- ErrCParenPList
s = [=[
function foo(bar
  return bar
end
]=]
e = [=[
test.lua:2:3: syntax error, expected ')' to close the parameter list
]=]

r = parse(s)
assert(r == e)

s = [=[
function foo(bar; baz)
  return bar
end
]=]
e = [=[
test.lua:1:17: syntax error, expected ')' to close the parameter list
]=]

r = parse(s)
assert(r == e)

s = [=[
function foo(a, b, ...rest) end
]=]
e = [=[
test.lua:1:23: syntax error, expected ')' to close the parameter list
]=]

r = parse(s)
assert(r == e)

-- ErrEndFunc
s = [=[
function foo(bar)
  return bar
]=]
e = [=[
test.lua:3:1: syntax error, expected 'end' to close the function body
]=]

r = parse(s)
assert(r == e)

s = [=[
function foo() do
  bar()
end
]=]
e = [=[
test.lua:4:1: syntax error, expected 'end' to close the function body
]=]

r = parse(s)
assert(r == e)

-- ErrParList
s = [=[
function foo(bar, baz,)
  return bar
end
]=]
e = [=[
test.lua:1:23: syntax error, expected a variable name or '...' after ','
]=]

r = parse(s)
assert(r == e)

-- ErrLabel
s = [=[
::1::
]=]
e = [=[
test.lua:1:3: syntax error, expected a label name after '::'
]=]

r = parse(s)
assert(r == e)

-- ErrCloseLabel
s = [=[
::loop
]=]
e = [=[
test.lua:2:1: syntax error, expected '::' after the label
]=]

r = parse(s)
assert(r == e)

-- ErrGoto
s = [=[
goto;
]=]
e = [=[
test.lua:1:5: syntax error, expected a label after 'goto'
]=]

r = parse(s)
assert(r == e)

s = [=[
goto 1
]=]
e = [=[
test.lua:1:6: syntax error, expected a label after 'goto'
]=]

r = parse(s)
assert(r == e)

-- ErrRetList
s = [=[
return a, b, 
]=]
e = [=[
test.lua:2:1: syntax error, expected an expression after ',' in the return statement
]=]

r = parse(s)
assert(r == e)

-- ErrVarList
s = [=[
x, y, = 0, 0
]=]
e = [=[
test.lua:1:7: syntax error, expected a variable name after ','
]=]

r = parse(s)
assert(r == e)

-- ErrExprList
s = [=[
x, y = 0, 0,
]=]
e = [=[
test.lua:2:1: syntax error, expected an expression after ','
]=]

r = parse(s)
assert(r == e)

-- ErrOrExpr
s = [=[
foo(a or)
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after 'or'
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a or $b
]=]
e = [=[
test.lua:1:10: syntax error, expected an expression after 'or'
]=]

r = parse(s)
assert(r == e)

-- ErrAndExpr
s = [=[
foo(a and)
]=]
e = [=[
test.lua:1:10: syntax error, expected an expression after 'and'
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a and $b
]=]
e = [=[
test.lua:1:11: syntax error, expected an expression after 'and'
]=]

r = parse(s)
assert(r == e)

-- ErrRelExpr
s = [=[
foo(a <)
]=]
e = [=[
test.lua:1:8: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a < $b
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

s = [=[
foo(a <=)
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a <= $b
]=]
e = [=[
test.lua:1:10: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

s = [=[
foo(a >)
]=]
e = [=[
test.lua:1:8: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a > $b
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

s = [=[
foo(a >=)
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a >= $b
]=]
e = [=[
test.lua:1:10: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

s = [=[
foo(a ==)
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a == $b
]=]
e = [=[
test.lua:1:10: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

s = [=[
foo(a ~=)
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a ~= $b
]=]
e = [=[
test.lua:1:10: syntax error, expected an expression after the relational operator
]=]

r = parse(s)
assert(r == e)

-- ErrBOrExpr
s = [=[
foo(a |)
]=]
e = [=[
test.lua:1:8: syntax error, expected an expression after '|'
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a | $b
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after '|'
]=]

r = parse(s)
assert(r == e)

-- ErrBXorExpr
s = [=[
foo(a ~)
]=]
e = [=[
test.lua:1:8: syntax error, expected an expression after '~'
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a ~ $b
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after '~'
]=]

r = parse(s)
assert(r == e)

-- ErrBAndExpr
s = [=[
foo(a &)
]=]
e = [=[
test.lua:1:8: syntax error, expected an expression after '&'
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a & $b
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after '&'
]=]

r = parse(s)
assert(r == e)

-- ErrShiftExpr
s = [=[
foo(a >>)
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the bit shift
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a >> $b
]=]
e = [=[
test.lua:1:10: syntax error, expected an expression after the bit shift
]=]

r = parse(s)
assert(r == e)

s = [=[
foo(a <<)
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the bit shift
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a >> $b
]=]
e = [=[
test.lua:1:10: syntax error, expected an expression after the bit shift
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a >>> b
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the bit shift
]=]

r = parse(s)
assert(r == e)

-- ErrConcatExpr
s = [=[
foo(a ..)
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after '..'
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a .. $b
]=]
e = [=[
test.lua:1:10: syntax error, expected an expression after '..'
]=]

r = parse(s)
assert(r == e)

-- ErrAddExpr
s = [=[
foo(a +, b)
]=]
e = [=[
test.lua:1:8: syntax error, expected an expression after the additive operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a + $b
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the additive operator
]=]

r = parse(s)
assert(r == e)

s = [=[
foo(a -, b)
]=]
e = [=[
test.lua:1:8: syntax error, expected an expression after the additive operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a - $b
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the additive operator
]=]

r = parse(s)
assert(r == e)

s = [=[
arr[i++]
]=]
e = [=[
test.lua:1:7: syntax error, expected an expression after the additive operator
]=]

r = parse(s)
assert(r == e)

-- ErrMulExpr
s = [=[
foo(b, a *)
]=]
e = [=[
test.lua:1:11: syntax error, expected an expression after the multiplicative operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a * $b
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the multiplicative operator
]=]

r = parse(s)
assert(r == e)

s = [=[
foo(b, a /)
]=]
e = [=[
test.lua:1:11: syntax error, expected an expression after the multiplicative operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a / $b
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the multiplicative operator
]=]

r = parse(s)
assert(r == e)

s = [=[
foo(b, a //)
]=]
e = [=[
test.lua:1:12: syntax error, expected an expression after the multiplicative operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a // $b
]=]
e = [=[
test.lua:1:10: syntax error, expected an expression after the multiplicative operator
]=]

r = parse(s)
assert(r == e)

s = [=[
foo(b, a %)
]=]
e = [=[
test.lua:1:11: syntax error, expected an expression after the multiplicative operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a % $b
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after the multiplicative operator
]=]

r = parse(s)
assert(r == e)

-- ErrUnaryExpr
s = [=[
x, y = a + not, b
]=]
e = [=[
test.lua:1:15: syntax error, expected an expression after the unary operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x, y = a + -, b
]=]
e = [=[
test.lua:1:13: syntax error, expected an expression after the unary operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x, y = a + #, b
]=]
e = [=[
test.lua:1:13: syntax error, expected an expression after the unary operator
]=]

r = parse(s)
assert(r == e)

s = [=[
x, y = a + ~, b
]=]
e = [=[
test.lua:1:13: syntax error, expected an expression after the unary operator
]=]

r = parse(s)
assert(r == e)

-- ErrPowExpr
s = [=[
foo(a ^)
]=]
e = [=[
test.lua:1:8: syntax error, expected an expression after '^'
]=]

r = parse(s)
assert(r == e)

s = [=[
x = a ^ $b
]=]
e = [=[
test.lua:1:9: syntax error, expected an expression after '^'
]=]

r = parse(s)
-- assert(r == e)

-- ErrExprParen
s = [=[
x = ()
]=]
e = [=[
test.lua:1:6: syntax error, expected an expression after '('
]=]

r = parse(s)
assert(r == e)

s = [=[
y = (???)
]=]
e = [=[
test.lua:1:6: syntax error, expected an expression after '('
]=]

r = parse(s)
assert(r == e)

-- ErrCParenExpr
s = [=[
z = a*(b+c
]=]
e = [=[
test.lua:2:1: syntax error, expected ')' to close the expression
]=]

r = parse(s)
assert(r == e)

s = [=[
w = (0xBV)
]=]
e = [=[
test.lua:1:9: syntax error, expected ')' to close the expression
]=]

r = parse(s)
assert(r == e)

s = [=[
ans = 2^(m*(n-1)
]=]
e = [=[
test.lua:2:1: syntax error, expected ')' to close the expression
]=]

r = parse(s)
assert(r == e)

-- ErrNameIndex
s = [=[
f = t.
]=]
e = [=[
test.lua:2:1: syntax error, expected a field name after '.'
]=]

r = parse(s)
assert(r == e)

s = [=[
f = t.['f']
]=]
e = [=[
test.lua:1:7: syntax error, expected a field name after '.'
]=]

r = parse(s)
assert(r == e)

s = [=[
x.
]=]
e = [=[
test.lua:2:1: syntax error, expected a field name after '.'
]=]

r = parse(s)
assert(r == e)

-- ErrExprIndex
s = [=[
f = t[]
]=]
e = [=[
test.lua:1:7: syntax error, expected an expression after '['
]=]

r = parse(s)
assert(r == e)

s = [=[
f = t[?]
]=]
e = [=[
test.lua:1:7: syntax error, expected an expression after '['
]=]

r = parse(s)
assert(r == e)

-- ErrCBracketIndex
s = [=[
f = t[x[y]
]=]
e = [=[
test.lua:2:1: syntax error, expected ']' to close the indexing expression
]=]

r = parse(s)
assert(r == e)

s = [=[
f = t[x,y]
]=]
e = [=[
test.lua:1:8: syntax error, expected ']' to close the indexing expression
]=]

r = parse(s)
assert(r == e)

s = [=[
arr[i--]
]=]
e = [=[
test.lua:2:1: syntax error, expected ']' to close the indexing expression
]=]

r = parse(s)
assert(r == e)

-- ErrNameMeth
s = [=[
x = obj:
]=]
e = [=[
test.lua:2:1: syntax error, expected a method name after ':'
]=]

r = parse(s)
assert(r == e)

s = [=[
x := 0
]=]
e = [=[
test.lua:1:4: syntax error, expected a method name after ':'
]=]

r = parse(s)
assert(r == e)

-- ErrMethArgs
s = [=[
cow:moo
]=]
e = [=[
test.lua:2:1: syntax error, expected some arguments for the method call (or '()')
]=]

r = parse(s)
assert(r == e)

s = [=[
dog:bark msg
]=]
e = [=[
test.lua:1:10: syntax error, expected some arguments for the method call (or '()')
]=]

r = parse(s)
assert(r == e)

s = [=[
duck:quack[4]
]=]
e = [=[
test.lua:1:11: syntax error, expected some arguments for the method call (or '()')
]=]

r = parse(s)
assert(r == e)

s = [=[
local t = {
  x = X:
  y = Y;
}
]=]
e = [=[
test.lua:3:5: syntax error, expected some arguments for the method call (or '()')
]=]

r = parse(s)
assert(r == e)

-- ErrArgList
s = [=[
foo(a, b, )
]=]
e = [=[
test.lua:1:11: syntax error, expected an expression after ',' in the argument list
]=]

r = parse(s)
assert(r == e)

s = [=[
foo(a, b, ..)
]=]
e = [=[
test.lua:1:11: syntax error, expected an expression after ',' in the argument list
]=]

r = parse(s)
assert(r == e)

-- ErrCParenArgs
s = [=[
foo(a + (b - c)
]=]
e = [=[
test.lua:2:1: syntax error, expected ')' to close the argument list
]=]

r = parse(s)
assert(r == e)

s = [=[
foo(arg1 arg2)
]=]
e = [=[
test.lua:1:10: syntax error, expected ')' to close the argument list
]=]

r = parse(s)
assert(r == e)

-- ErrCBraceTable
s = [=[
nums = {1, 2, 3]
]=]
e = [=[
test.lua:1:16: syntax error, expected '}' to close the table constructor
]=]

r = parse(s)
assert(r == e)

s = [=[
nums = {
  one = 1;
  two = 2
  three = 3;
  four = 4
}
]=]
e = [=[
test.lua:4:3: syntax error, expected '}' to close the table constructor
]=]

r = parse(s)
assert(r == e)

-- ErrEqField
s = [=[
words2nums = { ['one'] -> 1 }
]=]
e = [=[
test.lua:1:24: syntax error, expected '=' after the table key
]=]

r = parse(s)
assert(r == e)

-- ErrExprField
s = [=[
words2nums = { ['one'] => 2 }
]=]
e = [=[
test.lua:1:25: syntax error, expected an expression after '='
]=]

r = parse(s)
assert(r == e)

-- ErrExprFKey
s = [=[
table = { [] = value }
]=]
e = [=[
test.lua:1:12: syntax error, expected an expression after '[' for the table key
]=]

r = parse(s)
assert(r == e)

-- ErrCBracketFKey
s = [=[
table = { [key = value }
]=]
e = [=[
test.lua:1:16: syntax error, expected ']' to close the table key
]=]

r = parse(s)
assert(r == e)


-- ErrDigitHex
s = [=[
print(0x)
]=]
e = [=[
test.lua:1:9: syntax error, expected one or more hexadecimal digits after '0x'
]=]

r = parse(s)
assert(r == e)

s = [=[
print(0xGG)
]=]
e = [=[
test.lua:1:9: syntax error, expected one or more hexadecimal digits after '0x'
]=]

r = parse(s)
assert(r == e)

-- ErrDigitDeci
s = [=[
print(1 + . 0625)
]=]
e = [=[
test.lua:1:12: syntax error, expected one or more digits after the decimal point
]=]

r = parse(s)
assert(r == e)

s = [=[
print(.)
]=]
e = [=[
test.lua:1:8: syntax error, expected one or more digits after the decimal point
]=]

r = parse(s)
assert(r == e)

-- ErrDigitExpo
s = [=[
print(1.0E)
]=]
e = [=[
test.lua:1:11: syntax error, expected one or more digits for the exponent
]=]

r = parse(s)
assert(r == e)

s = [=[
print(3E)
]=]
e = [=[
test.lua:1:9: syntax error, expected one or more digits for the exponent
]=]

r = parse(s)
assert(r == e)

-- ErrQuote
s = [=[
local message = "Hello
]=]
e = [=[
test.lua:2:1: syntax error, unclosed string
]=]

r = parse(s)
assert(r == e)

s = [=[
local message = "*******
Welcome
*******"
]=]
e = [=[
test.lua:2:1: syntax error, unclosed string
]=]

r = parse(s)
assert(r == e)

s = [=[
local message = 'Hello
]=]
e = [=[
test.lua:2:1: syntax error, unclosed string
]=]

r = parse(s)
assert(r == e)

s = [=[
local message = '*******
Welcome
*******'
]=]
e = [=[
test.lua:2:1: syntax error, unclosed string
]=]

r = parse(s)
assert(r == e)

-- ErrHexEsc
s = [=[
print("\x")
]=]
e = [=[
test.lua:1:10: syntax error, expected exactly two hexadecimal digits after '\x'
]=]

r = parse(s)
assert(r == e)

s = [=[
print("\xF")
]=]
e = [=[
test.lua:1:10: syntax error, expected exactly two hexadecimal digits after '\x'
]=]

r = parse(s)
assert(r == e)

s = [=[
print("\xG")
]=]
e = [=[
test.lua:1:10: syntax error, expected exactly two hexadecimal digits after '\x'
]=]

r = parse(s)
assert(r == e)

-- ErrOBraceUEsc
s = [=[
print("\u3D")
]=]
e = [=[
test.lua:1:10: syntax error, expected '{' after '\u'
]=]

r = parse(s)
assert(r == e)

-- ErrDigitUEsc
s = [=[
print("\u{}")
]=]
e = [=[
test.lua:1:11: syntax error, expected one or more hexadecimal digits for the UTF-8 code point
]=]

r = parse(s)
assert(r == e)

s = [=[
print("\u{XD}")
]=]
e = [=[
test.lua:1:11: syntax error, expected one or more hexadecimal digits for the UTF-8 code point
]=]

r = parse(s)
assert(r == e)

-- ErrCBraceUEsc
s = [=[
print("\u{0x3D}")
]=]
e = [=[
test.lua:1:12: syntax error, expected '}' after the code point
]=]

r = parse(s)
assert(r == e)

s = [=[
print("\u{FFFF Hi")
]=]
e = [=[
test.lua:1:15: syntax error, expected '}' after the code point
]=]

r = parse(s)
assert(r == e)

-- ErrEscSeq
s = [=[
print("\m")
]=]
e = [=[
test.lua:1:9: syntax error, invalid escape sequence
]=]

r = parse(s)
assert(r == e)

-- ErrCloseLStr
s = [===[
local message = [==[
    *******
    WELCOME
    *******
]=]
]===]
e = [=[
test.lua:6:1: syntax error, unclosed long string
]=]

r = parse(s)
assert(r == e)

end

print("OK")
