--[[
This module implements a parser for Lua 5.3 with LPeg,
and generates an Abstract Syntax Tree in the Metalua format.
For more information about Metalua, please, visit:
https://github.com/fab13n/metalua-parser

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
  | `True
  | `False
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
]]

local lpeg = require "lpeglabel"

lpeg.locale(lpeg)

local P, S, V = lpeg.P, lpeg.S, lpeg.V
local C, Carg, Cb, Cc = lpeg.C, lpeg.Carg, lpeg.Cb, lpeg.Cc
local Cf, Cg, Cmt, Cp, Ct = lpeg.Cf, lpeg.Cg, lpeg.Cmt, lpeg.Cp, lpeg.Ct
local Lc, T = lpeg.Lc, lpeg.T

local alpha, digit, alnum = lpeg.alpha, lpeg.digit, lpeg.alnum
local xdigit = lpeg.xdigit
local space = lpeg.space


-- error message auxiliary functions

local labels = {
  { "ExpExprIf", "expected a condition after 'if'" },
  { "ExpThenIf", "expected 'then' after the condition" },
  { "ExpExprEIf", "expected a condition after 'elseif'" },
  { "ExpThenEIf", "expected 'then' after the condition" },
  { "ExpEndIf", "expected 'end' to close the if statement" },
  { "ExpEndDo", "expected 'end' to close the do block" },
  { "ExpExprWhile", "expected a condition after 'while'" },
  { "ExpDoWhile", "expected 'do' after the condition" },
  { "ExpEndWhile", "expected 'end' to close the while loop" },
  { "ExpUntilRep", "expected 'until' after the condition" },
  { "ExpExprRep", "expected a condition after 'until'" },

  { "ExpForRange", "expected a numeric or generic range after 'for'" },
  { "ExpEndFor", "expected 'end' to close the for loop" },
  { "ExpExprFor1", "expected a starting expression for the numeric range " },
  { "ExpCommaFor", "expected a comma to split the start and end of the range" },
  { "ExpExprFor2", "expected an ending expression for the numeric range" },
  { "ExpExprFor3", "expected a step expression for the numeric range after the comma" },
  { "ExpInFor", "expected 'in' after the variable names" },
  { "ExpEListFor", "expected one or more expressions after 'in'" },
  { "ExpDoFor", "expected 'do' after the range of the for loop" },

  { "ExpDefLocal", "expected a function definition or assignment after 'local'" },
  { "ExpNameLFunc", "expected an identifier after 'function'" },
  { "ExpEListLAssign", "expected one or more expressions after '='" },
  { "ExpFuncName", "expected a function name after 'function'" },
  { "ExpNameFunc1", "expected an identifier after the dot" },
  { "ExpNameFunc2", "expected an identifier after the colon" },
  { "ExpOpenParenParams", "expected opening '(' for the parameter list" },
  { "MisCloseParenParams", "missing closing ')' to end the parameter list" },
  { "ExpEndFunc", "expected 'end' to close the function body" },

  { "ExpLHSComma", "expected a variable or table field after the comma" },
  { "ExpEListAssign", "expected one or more expressions after '='" },
  { "ExpLabelName", "expected a label name after '::'" },
  { "MisCloseLabel", "missing closing '::' after the label" },
  { "ExpLabel", "expected a label name after 'goto'" },
  { "ExpExprCommaRet", "expected an expression after the comma" },
  { "ExpNameNList", "expected an identifier after the comma" },
  { "ExpExprEList", "expected an expression after the comma" },

  { "ExpExprSub1", "expected an expression after the 'or' operator" },
  { "ExpExprSub2", "expected an expression after the 'and' operator" },
  { "ExpExprSub3", "expected an expression after the relational operator" },
  { "ExpExprSub4", "expected an expression after the '|' operator" },
  { "ExpExprSub5", "expected an expression after the '~' operator" },
  { "ExpExprSub6", "expected an expression after the '&' operator" },
  { "ExpExprSub7", "expected an expression after the bitshift operator" },
  { "ExpExprSub8", "expected an expression after the '..' operator" },
  { "ExpExprSub9", "expected an expression after the additive operator" },
  { "ExpExprSub10", "expected an expression after the multiplicative operator" },
  { "ExpExprSub11", "expected an expression after the unary operator" },
  { "ExpExprSub12", "expected an expression after the '^' operator" },

  { "ExpNameDot", "expected a field name after the dot" },
  { "MisCloseBracketIndex", "missing closing ']' in the table indexing" },
  { "ExpNameColon", "expected an identifier after the colon" },
  { "ExpFuncArgs", "expected at least one argument in the method call" },
  { "ExpExprParen", "expected an expression after '('" },
  { "MisCloseParenExpr", "missing closing ')' in the parenthesized expression" },

  { "ExpExprArgs", "expected an expression after the comma in the argument list" },
  { "MisCloseParenArgs", "expected closing ')' to end the argument list" },

  { "MisCloseBrace", "missing closing '}' for the table constructor" },
  { "MisCloseBracket", "missing closing ']' in the key" },
  { "ExpEqField1", "expected '=' after the key" },
  { "ExpExprField1", "expected an expression after '='" },
  { "ExpEqField2", "expected '=' after the field name" },
  { "ExpExprField2", "expected an expression after '='" },

  { "ExpDigitsHex", "expected one or more hexadecimal digits" },
  { "ExpDigitsPoint", "expected one or more digits after the decimal point" },
  { "ExpDigitsExpo", "expected one or more digits for the exponent" },
  { "MisTermDQuote", "missing terminating double quote for the string" },
  { "MisTermSQuote", "missing terminating single quote for the string" },
  { "MisTermLStr", "missing closing delimiter for the multi-line string (must have same '='s)" },
}

local function expect(patt, label)
  for i, labelinfo in ipairs(labels) do
    if labelinfo[1] == label then
      return patt + T(i)
    end
  end

  error("Label not found: " .. label)
end

-- creates an error message for the input string
local function syntaxerror (errorinfo, pos, msg)
  local l, c = lineno(errorinfo.subject, pos)
  local error_msg = "%s:%d:%d: syntax error, %s"
  return string.format(error_msg, errorinfo.filename, l, c, msg)
end

-- regular combinators and auxiliary functions

local function token (pat)
  return pat * V"Skip"
end

local function sym (str)
  return token(P(str))
end

local function kw (str)
  return token(P(str) * -V"IdRest")
end

local function taggedCap (tag, pat)
  return Ct(Cg(Cp(), "pos") * Cg(Cc(tag), "tag") * pat)
end

local function unaryop (op, e)
  return { tag = "Op", pos = e.pos, [1] = op, [2] = e }
end

local function binaryop (e1, op, e2)
  if not op then
    return e1
  elseif op == "add" or
         op == "sub" or
         op == "mul" or
         op == "div" or
         op == "idiv" or
         op == "mod" or
         op == "pow" or
         op == "concat" or
         op == "band" or
         op == "bor" or
         op == "bxor" or
         op == "shl" or
         op == "shr" or
         op == "eq" or
         op == "lt" or
         op == "le" or
         op == "and" or
         op == "or" then
    return { tag = "Op", pos = e1.pos, [1] = op, [2] = e1, [3] = e2 }
  elseif op == "ne" then
    return unaryop ("not", { tag = "Op", pos = e1.pos, [1] = "eq", [2] = e1, [3] = e2 })
  elseif op == "gt" then
    return { tag = "Op", pos = e1.pos, [1] = "lt", [2] = e2, [3] = e1 }
  elseif op == "ge" then
    return { tag = "Op", pos = e1.pos, [1] = "le", [2] = e2, [3] = e1 }
  end
end

local function chainl1 (pat, sep, label)
  return Cf(pat * Cg(sep * expect(pat, label))^0, binaryop)
end

local function sepby1 (pat, sep, tag)
  return taggedCap(tag, pat * (sep * pat)^0)
end

local function fix_esc_seq (str)
  str = string.gsub(str, "\\a", "\a")
  str = string.gsub(str, "\\b", "\b")
  str = string.gsub(str, "\\f", "\f")
  str = string.gsub(str, "\\n", "\n")
  str = string.gsub(str, "\\r", "\r")
  str = string.gsub(str, "\\t", "\t")
  str = string.gsub(str, "\\v", "\v")
  str = string.gsub(str, "\\\n", "\n")
  str = string.gsub(str, "\\\r", "\n")
  str = string.gsub(str, "\\'", "'")
  str = string.gsub(str, '\\"', '"')
  str = string.gsub(str, '\\\\', '\\')
  return str
end

local function tag_as_do (block)
  block.tag = "Do"
  return block
end

local function fix_func_stat (func)
  if func[1].is_method then table.insert(func[2][1], 1, {tag = "Id", [1] = "self"}) end
  func[1] = {func[1]}
  func[2] = {func[2]}
  return func
end

local function add_dots (params, dots)
  if dots then table.insert(params, dots) end
  return params
end

local function insert_index (t, index)
  return {tag = "Index", pos = t.pos, [1] = t, [2] = index}
end

local function mark_method(t, method)
  if method then
    return {tag = "Index", pos = t.pos, is_method = true, [1] = t, [2] = method}
  end
  return t
end

local function make_index_or_call (t1, t2)
  if t2.tag == "Call" or t2.tag == "Invoke" then
    local t = {tag = t2.tag, pos = t1.pos, [1] = t1}
    for k, v in ipairs(t2) do
      table.insert(t, v)
    end
    return t
  end
  return {tag = "Index", pos = t1.pos, [1] = t1, [2] = t2[1]}
end

-- grammar
local G = { V"Lua",
  Lua      = V"Shebang"^-1 * V"Skip" * V"Chunk" * -1;
  Shebang  = P"#" * (P(1) - P"\n")^0 * P"\n";

  Chunk  = V"Block";
  Block  = taggedCap("Block", V"Stat"^0 * V"RetStat"^-1);
  Stat   = V"IfStat" + V"DoStat" + V"WhileStat" + V"RepeatStat" + V"ForStat" 
         + V"LocalStat" + V"FuncStat" + V"BreakStat" + V"LabelStat" + V"GoToStat"
         + V"FuncCall" + V"Assignment" + sym(";");

  IfStat      = taggedCap("If", V"IfPart" * V"ElseIfPart"^0 * V"ElsePart"^-1 * expect(kw("end"), "ExpEndIf"));
  IfPart      = kw("if") * expect(V"Expr", "ExpExprIf") * expect(kw("then"), "ExpThenIf") * V"Block";
  ElseIfPart  = kw("elseif") * expect(V"Expr", "ExpExprEIf") * expect(kw("then"), "ExpThenEIf") * V"Block";
  ElsePart    = kw("else") * V"Block";

  DoStat      = kw("do") * V"Block" * expect(kw("end"), "ExpEndDo") / tag_as_do;
  WhileStat   = taggedCap("While", kw("while") * expect(V"Expr", "ExpExprWhile") * V"WhileBody");
  WhileBody   = expect(kw("do"), "ExpDoWhile") * V"Block" * expect(kw("end"), "ExpEndWhile");
  RepeatStat  = taggedCap("Repeat", kw("repeat") * V"Block" * expect(kw("until"), "ExpUntilRep") * expect(V"Expr", "ExpExprRep"));

  ForStat   = kw("for") * expect(V"ForNum" + V"ForGen", "ExpForRange") * expect(kw("end"), "ExpEndFor");
  ForNum    = taggedCap("Fornum", V"Id" * sym("=") * V"ForRange" * V"ForBody");
  ForRange  = expect(V"Expr", "ExpExprFor1") * expect(sym(","), "ExpCommaFor") *expect(V"Expr", "ExpExprFor2")
            * (sym(",") * expect(V"Expr", "ExpExprFor3"))^-1; 
  ForGen    = taggedCap("Forin", V"NameList" * expect(kw("in"), "ExpInFor") * expect(V"ExpList", "ExpEListFor") * V"ForBody");
  ForBody   = expect(kw("do"), "ExpDoFor") * V"Block";

  LocalStat    = kw("local") * expect(V"LocalFunc" + V"LocalAssign", "ExpDefLocal");
  LocalFunc    = taggedCap("Localrec", kw("function") * expect(V"Id", "ExpNameLFunc") * V"FuncBody") / fix_func_stat;
  LocalAssign  = taggedCap("Local", V"NameList" * (sym("=") * expect(V"ExpList", "ExpEListLAssign") + Ct(Cc())));
  Assignment   = taggedCap("Set", V"VarList" * sym("=") * expect(V"ExpList", "ExpEListAssign"));

  FuncStat    = taggedCap("Set", kw("function") * expect(V"FuncName", "ExpFuncName") * V"FuncBody") / fix_func_stat;
  FuncName    = Cf(V"Id" * (sym(".") * expect(taggedCap("String", V"Name"), "ExpNameFunc1"))^0, insert_index)
              * (sym(":") * expect(taggedCap("String", V"Name"), "ExpNameFunc2"))^-1 / mark_method;
  FuncBody    = taggedCap("Function", V"FuncParams" * V"Block" * expect(kw("end"), "ExpEndFunc"));
  FuncParams  = expect(sym("("), "ExpOpenParenParams") * V"ParList" * expect(sym(")"), "MisCloseParenParams");
  ParList     = V"NameList" * (sym(",") * taggedCap("Dots", sym("...")))^-1 / add_dots
              + Ct(taggedCap("Dots", sym("...")))
              + Ct(Cc()); -- Cc({}) generates a bug since the {} would be shared across parses

  LabelStat  = taggedCap("Label", sym("::") * expect(V"Name", "ExpLabelName") * expect(sym("::"), "MisCloseLabel"));
  GoToStat   = taggedCap("Goto", kw("goto") * expect(V"Name", "ExpLabel"));
  BreakStat  = taggedCap("Break", kw("break"));
  RetStat    = taggedCap("Return", kw("return") * (V"Expr" * (sym(",") * expect(V"Expr", "ExpExprCommaRet"))^0)^-1 * sym(";")^-1);

  NameList = sepby1(V"Id", sym(","), "NameList");
  VarList  = sepby1(V"VarExp", sym(","), "VarList");
  ExpList  = sepby1(V"Expr", sym(","), "ExpList");

  Expr        = V"SubExpr_1";
  SubExpr_1   = chainl1(V"SubExpr_2", V"OrOp", "ExpExprSub1");
  SubExpr_2   = chainl1(V"SubExpr_3", V"AndOp", "ExpExprSub2");
  SubExpr_3   = chainl1(V"SubExpr_4", V"RelOp", "ExpExprSub3");
  SubExpr_4   = chainl1(V"SubExpr_5", V"BOrOp", "ExpExprSub4");
  SubExpr_5   = chainl1(V"SubExpr_6", V"BXorOp", "ExpExprSub5");
  SubExpr_6   = chainl1(V"SubExpr_7", V"BAndOp", "ExpExprSub6");
  SubExpr_7   = chainl1(V"SubExpr_8", V"ShiftOp", "ExpExprSub7");
  SubExpr_8   = V"SubExpr_9" * V"ConOp" * expect(V"SubExpr_8", "ExpExprSub8") / binaryop
              + V"SubExpr_9";
  SubExpr_9   = chainl1(V"SubExpr_10", V"AddOp", "ExpExprSub9");
  SubExpr_10  = chainl1(V"SubExpr_11", V"MulOp", "ExpExprSub10");
  SubExpr_11  = V"UnOp" * expect(V"SubExpr_11", "ExpExprSub11") / unaryop
              + V"SubExpr_12";
  SubExpr_12  = V"SimpleExp" * (V"PowOp" * expect(V"SubExpr_11", "ExpExprSub12"))^-1 / binaryop;
  
  SimpleExp = taggedCap("Number", V"Number")
            + taggedCap("String", V"String")
            + taggedCap("Nil", kw("nil"))
            + taggedCap("False", kw("false"))
            + taggedCap("True", kw("true"))
            + taggedCap("Dots", sym("..."))
            + V"FunctionDef"
            + V"Constructor"
            + V"SuffixedExp";

  FuncCall  = Cmt(V"SuffixedExp", function(s, i, exp) return exp.tag == "Call" or exp.tag == "Invoke", exp end);
  VarExp    = Cmt(V"SuffixedExp", function(s, i, exp) return exp.tag == "Id" or exp.tag == "Index", exp end);

  SuffixedExp  = Cf(V"PrimaryExp" * (V"Index" + V"Call")^0, make_index_or_call);
  PrimaryExp   = V"Id" + taggedCap("Paren", sym("(") * expect(V"Expr", "ExpExprParen") * expect(sym(")"), "MisCloseParenExpr"));
  Index        = taggedCap("DotIndex", sym(".") * expect(taggedCap("String", V"Name"), "ExpNameDot"))
               + taggedCap("ArrayIndex", sym("[" * -P(S"=[")) * V"Expr" * expect(sym("]"), "MisCloseBracketIndex"));
  Call         = taggedCap("Invoke", Cg(sym(":") * expect(taggedCap("String", V"Name"), "ExpNameColon") * expect(V"FuncArgs", "ExpFuncArgs")))
               + taggedCap("Call", V"FuncArgs");

  FunctionDef  = kw("function") * V"FuncBody";
  FuncArgs     = sym("(") * (V"Expr" * (sym(",") * V"Expr")^0)^-1 * sym(")")
               + V"Constructor"
               + taggedCap("String", V"String");

  Constructor  = taggedCap("Table", sym("{") * V"FieldList" * expect(sym("}"), "MisCloseBrace"));
  FieldList    = (V"Field" * (V"FieldSep" * V"Field")^0 * V"FieldSep"^-1)^-1;
  Field        = taggedCap("Pair", V"FieldKey" * expect(sym("="), "ExpEqField1") * expect(V"Expr", "ExpExprField1"))
               + V"Expr";
  FieldKey     = sym("[" * -P(S"=[")) * V"Expr" * expect(sym("]"), "MisCloseBracket")
               + taggedCap("String", V"Name");
  FieldSep     = sym(",") + sym(";");

  Id = taggedCap("Id", V"Name");

  -- lexer
  Skip     = (V"Space" + V"Comment")^0;
  Space    = space^1;
  Comment  = P"--" * V"LongString" / function () return end
           + P"--" * (P(1) - P"\n")^0;

  Name      = token(-V"Reserved" * C(V"Ident"));
  Reserved  = V"Keywords" * -V"IdRest";
  Keywords  = P"and" + "break" + "do" + "elseif" + "else" + "end"
            + "false" + "for" + "function" + "goto" + "if" + "in"
            + "local" + "nil" + "not" + "or" + "repeat" + "return"
            + "then" + "true" + "until" + "while";
  Ident     = V"IdStart" * V"IdRest"^0;
  IdStart   = alpha + P"_";
  IdRest    = alnum + P"_";

  Number   = token((V"Hex" + V"Float" + V"Int") / tonumber);
  Hex      = (P"0x" + "0X") * expect(xdigit^1, "ExpDigitsHex");
  Float    = V"Decimal" * V"Expo"^-1
           + V"Int" * V"Expo";
  Decimal  = digit^1 * "." * digit^0
           + P"." * digit^1;
  Expo     = S"eE" * S"+-"^-1 * expect(digit^1, "ExpDigitsExpo");
  Int      = digit^1;

  String       = token(V"ShortString" + V"LongString");
  ShortString  = ( P'"' * C((P'\\'*P(1) + (P(1)-S'"\n'))^0) * expect(P'"', "MisTermDQuote")
                 + P"'" * C((P"\\"*P(1) + (P(1)-S"'\n"))^0) * expect(P"'", "MisTermSQuote")
                 ) / fix_esc_seq;

  LongString  = V"Open" * C((P(1) - V"CloseEq")^0) * expect(V"Close", "MisTermLStr") / function (s, eqs) return s end;
  Open        = "[" * Cg(V"Equals", "openEq") * "[" * P"\n"^-1;
  Close       = "]" * C(V"Equals") * "]";
  Equals      = P"="^0;
  CloseEq     = Cmt(V"Close" * Cb("openEq"), function (s, i, closeEq, openEq) return #openEq == #closeEq end);

  OrOp     = kw("or")   / "or";
  AndOp    = kw("and")  / "and";
  RelOp    = sym("~=")  / "ne"
           + sym("==")  / "eq"
           + sym("<=")  / "le"
           + sym(">=")  / "ge"
           + sym("<")   / "lt"
           + sym(">")   / "gt";
  BOrOp    = sym("|")   / "bor";
  BXorOp   = sym("~" * -P"=") / "bxor";
  BAndOp   = sym("&")   / "band";
  ShiftOp  = sym("<<")  / "shl"
           + sym(">>")  / "shr";
  ConOp    = sym("..")  / "concat";
  AddOp    = sym("+")   / "add"
           + sym("-")   / "sub";
  MulOp    = sym("*")   / "mul"
           + sym("//")  / "idiv"
           + sym("/")   / "div"
           + sym("%")   / "mod";
  UnOp     = kw("not")  / "not"
           + sym("-")   / "unm"
           + sym("#")   / "len"
           + sym("~")   / "bnot";
  PowOp    = sym("^")   / "pow";
}

local parser = {}
local validate = require("lua-parser.validator").validate

function parser.parse (subject, filename)
  local errorinfo = { subject = subject, filename = filename }
  lpeg.setmaxstack(1000)
  local ast, error_msg = lpeg.match(G, subject, nil, errorinfo)
  if not ast then return ast, error_msg end
  return validate(ast, errorinfo)
end

return parser