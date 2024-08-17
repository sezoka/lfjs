package lfjs

import "core:fmt"

Special_Form_Kind :: enum {
    None,
    If,
    Plus,
    Minus,
    Mult,
    Div,
    Less,
    Greater,
    Less_Equal,
    Greater_Equal,
    Equal,
    Not_Equal,
    Let,
    Def,
    Do,
    Cond,
    Lambda,
    Import,
}

SExpr :: struct {
    items:             []SExpr_Item,
    is_quoted:         bool,
    special_form_kind: Special_Form_Kind,
}

SExpr_Item_Tag :: enum {
    SExpr,
    Number,
    Ident,
    String,
}

SExpr_Item_Value :: union {
    SExpr,
    f64,
    string,
}

SExpr_Item :: struct {
    tag:   SExpr_Item_Tag,
    value: SExpr_Item_Value,
    line:  u16,
}

Parser :: struct {
    tokens: []Token,
    i:      int,
}

parse :: proc(tokens: []Token) -> (result: []SExpr, ok: bool) {
    parser := Parser {
        tokens = tokens,
    }

    sexprs: [dynamic]SExpr

    for !is_parser_at_end(&parser) {
        append(&sexprs, parse_sexpr(&parser) or_return)
    }

    return sexprs[:], true
}

parse_sexpr :: proc(p: ^Parser) -> (expr: SExpr, ok: bool) {
    _ = expect(p, .Left_Paren, "expect '('") or_return

    sexpr_items: [dynamic]SExpr_Item

    for (peek_token(p) or_return).tag != .Right_Paren {
        tok := peek_token(p) or_return
        #partial switch tok.tag {
        case .Left_Paren:
            sexpr_item_value := parse_sexpr(p) or_return
            append(
                &sexpr_items,
                make_sexpr_item(.SExpr, sexpr_item_value, tok.line),
            )
        case .Number:
            next_token(p) or_return
            append(
                &sexpr_items,
                make_sexpr_item(.Number, tok.value.(f64), tok.line),
            )
        case .Ident:
            next_token(p) or_return
            append(&sexpr_items, make_sexpr_item(.Ident, tok.lexeme, tok.line))
        case .String:
            next_token(p) or_return
            append(
                &sexpr_items,
                make_sexpr_item(.String, tok.value.(string), tok.line),
            )
        case:
            panic("unreachable")
        }
    }
    _ = expect(p, .Right_Paren, "expect ')'") or_return

    if len(sexpr_items) == 0 {
        return SExpr {
                items = sexpr_items[:],
                is_quoted = false,
                special_form_kind = .None,
            },
            true
    }

    if sexpr_items[0].tag != .Ident && sexpr_items[0].tag != .SExpr {
        fmt.eprintln(
            "error: first item in s-expression should be identifier or s-expression",
        )
        return {}, false
    }

    special_form_kind: Special_Form_Kind = .None

    if sexpr_items[0].tag == .Ident {
        ident := sexpr_items[0].value.(string)

        switch ident {
        case "import":
            special_form_kind = .Import
            if len(sexpr_items) != 3 {
                return parse_error(
                    "error: special form 'import' should take 2 arguments (import <module_name> \"path_to_modile.lfjs\">)",
                )
            }
            if sexpr_items[1].tag != .Ident {
                return parse_error(
                    "error: special form 'import' expects module name as first argument (import <module_name> \"path_to_modile.lfjs\">)",
                )
            }
            if sexpr_items[2].tag != .String {
                return parse_error(
                    "error: special form 'import' expects module path as second argument (import <module_name> \"path_to_modile.lfjs\">)",
                )
            }
        case "lambda":
            special_form_kind = .Lambda
            if len(sexpr_items) != 3 {
                return parse_error(
                    "error: special form 'lambda' should take 2 arguments (lambda (<param_0> <param_n>) <s-expression>)",
                )
            }
            maybe_params_list := sexpr_items[1]
            if maybe_params_list.tag != .SExpr {
                return parse_error(
                    "error: special form 'lambda' expect parameter name list as first argument, for example (lambda (x y z) (+ x y z))",
                )
            }
            params_list := sexpr_items[1].value.(SExpr).items
            for param in params_list {
                if param.tag != .Ident {
                    return parse_error(
                        "error: special form 'lambda' expect parameter name list as first argument, for example (lambda (x y z) (+ x y z))",
                    )
                }
            }
        case "cond":
            special_form_kind = .Cond
            if len(sexpr_items) < 5 {
                return parse_error(
                    "error: special form 'cond' should take at least 4 arguments (cond <condition-1> <result-1> <cond-2> <result-2> ...)",
                )
            }

            if len(sexpr_items) % 2 == 0 {
                return parse_error(
                    "error: special form 'cond' should take even number of arguments (cond <condition-1> <result-1> <cond-2> <result-2> ...)",
                )
            }
        case "do":
            special_form_kind = .Do
            if len(sexpr_items) < 2 {
                return parse_error(
                    "error: special form 'do' should take at least 1 argument (do <expr-1> [expr-*])",
                )
            }
        case "def":
            special_form_kind = .Def
            if len(sexpr_items) != 3 && len(sexpr_items) != 4 {
                return parse_error(
                    "error: special form 'def' should take 2 or 3 arguments (def <def_name> (<param_0> <param_n>) <s-expression>) or (def <def_name> <value>)",
                )
            }
            if sexpr_items[1].tag != .Ident {
                return parse_error(
                    "error: special form 'def' should take definition name as first parameter",
                )
            }
            if len(sexpr_items) == 4 {
                maybe_params_list := sexpr_items[2]
                if maybe_params_list.tag != .SExpr {
                    return parse_error(
                        "error: special form 'def' expect parameter name list as second argument, for example (def sum3 (x y z) (+ x y z))",
                    )
                }
                params_list := sexpr_items[2].value.(SExpr).items
                for param in params_list {
                    if param.tag != .Ident {
                        return parse_error(
                            "error: special form 'def' expect parameter name list as second argument, for example (def sum3 (x y z) (+ x y z))",
                        )
                    }
                }
            }
        case "let":
            special_form_kind = .Let
            if len(sexpr_items) != 3 {
                return parse_error(
                    "error: special form 'let' should have 2 arguments <(name value)> <s-expression>",
                )
            }
            if (sexpr_items[1].tag != .SExpr) ||
               (len(sexpr_items[1].value.(SExpr).items) % 2 != 0) {
                return parse_error(
                    "error: special form 'let' should take s-expression in form (name1 value1 name2 value2) as first argument",
                )
            }
        case "if":
            special_form_kind = .If
            if len(sexpr_items) != 4 {
                return parse_error(
                    "error: special form 'if' should have 3 arguments (<cond> <then> <else>)",
                )
            }
        case "-":
            special_form_kind = .Minus
            if len(sexpr_items) < 2 {
                return parse_error(
                    "error: special form 'TODO' should have at least 1 argument1",
                )
            }
        case "=", "!=", "+", "*", "/", "<", ">", "<=", ">=":
            if len(sexpr_items) < 3 {
                return parse_error(
                    "error: special form 'TODO' should have at least 2 arguments",
                )
            }
            switch ident {
            case "=":
                special_form_kind = .Equal
            case "!=":
                special_form_kind = .Not_Equal
            case "+":
                special_form_kind = .Plus
            case "*":
                special_form_kind = .Mult
            case "/":
                special_form_kind = .Div
            case "<":
                special_form_kind = .Less
            case ">":
                special_form_kind = .Greater
            case "<=":
                special_form_kind = .Less_Equal
            case ">=":
                special_form_kind = .Greater_Equal
            }
        }
    }

    return SExpr {
            items = sexpr_items[:],
            is_quoted = false,
            special_form_kind = special_form_kind,
        },
        true
}

@(require_results)
parse_error :: proc(msg: string) -> (SExpr, bool) {
    fmt.println(msg)
    return {}, false
}

make_sexpr_item := proc(
    tag: SExpr_Item_Tag,
    val: SExpr_Item_Value,
    line: u16,
) -> SExpr_Item {
    return {tag = tag, value = val, line = line}
}

@(require_results)
expect :: proc(
    p: ^Parser,
    tag: Token_Tag,
    msg: string,
) -> (
    expr: SExpr,
    ok: bool,
) {
    if (peek_token(p) or_return).tag == tag {
        next_token(p)
        return {}, true
    }
    fmt.eprintln(msg)
    return {}, false
}

peek_token :: proc(p: ^Parser) -> (^Token, bool) {
    if is_parser_at_end(p) {
        fmt.eprintln("Unexpected EOF")
        return {}, false
    }
    return &p.tokens[p.i], true
}

next_token :: proc(p: ^Parser) -> (Token, bool) {
    if is_parser_at_end(p) {
        fmt.eprintln("Unexpected EOF")
        return {}, false
    }
    p.i += 1
    return p.tokens[p.i], true
}

is_parser_at_end :: proc(p: ^Parser) -> bool {
    return p.tokens[p.i].tag == .Eof
}
