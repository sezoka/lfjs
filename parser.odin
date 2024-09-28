package lfjs

import "core:fmt"

Special_Form_Kind :: enum {
    None,
    If,
    Let,
    Def,
    Do,
    Cond,
    Lambda,
    Import,
    Pub_Import,
    Embed_Code,
}

SExpr :: struct {
    tag:   SExpr_Tag,
    value: SExpr_Value,
    row:   u16,
    col:   u16,
}

SExpr_Tag :: enum {
    Number,
    Ident,
    String,
    List,
    Field_Access,
}

SExpr_Value :: union {
    string,
    f64,
    SExpr_List,
}

SExpr_List :: struct {
    items:             []SExpr,
    is_quoted:         bool,
    special_form_kind: Special_Form_Kind,
}

Parser :: struct {
    tokens: []Token,
    i:      int,
}

parse :: proc(tokens: []Token) -> (result: []SExpr, ok: bool) {
    parser := Parser {
        tokens = tokens,
    }

    sexpr_items: [dynamic]SExpr

    for !is_parser_at_end(&parser) {
        append(&sexpr_items, parse_sexpr(&parser) or_return)
    }

    return sexpr_items[:], true
}

parse_sexpr :: proc(p: ^Parser) -> (item: SExpr, ok: bool) {
    tok := peek_token(p) or_return
    #partial switch tok.tag {
    case .Field_Access:
        next_token(p) or_return
        return make_sexpr(.Field_Access, tok.lexeme, tok.row, tok.col), true
    case .Left_Paren:
        sexpr_list := parse_sexpr_list(p) or_return
        return make_sexpr(.List, sexpr_list, tok.row, tok.col), true
    case .Number:
        next_token(p) or_return
        return make_sexpr(.Number, tok.value.(f64), tok.row, tok.col), true
    case .Ident:
        next_token(p) or_return
        return make_sexpr(.Ident, tok.lexeme, tok.row, tok.col), true
    case .String:
        next_token(p) or_return
        return make_sexpr(.String, tok.value.(string), tok.row, tok.col), true
    case:
        fmt.eprintln(
            "error[",
            tok.row,
            "]: unexpected token '",
            tok.lexeme,
            "'",
            sep = "",
        )
    }
    return {}, false
}

parse_sexpr_list :: proc(p: ^Parser) -> (expr: SExpr_List, ok: bool) {
    _ = expect(p, .Left_Paren, "expect '('") or_return

    sexpr_items: [dynamic]SExpr
    for (peek_token(p) or_return).tag != .Right_Paren {
        append(&sexpr_items, parse_sexpr(p) or_return)
    }
    _ = expect(p, .Right_Paren, "expect ')'") or_return

    if len(sexpr_items) == 0 {
        return SExpr_List {
                items = sexpr_items[:],
                is_quoted = false,
                special_form_kind = .None,
            },
            true
    }

    if sexpr_items[0].tag != .Ident &&
       sexpr_items[0].tag != .List &&
       sexpr_items[0].tag != .Field_Access {
        fmt.eprintln(
            "error: first item in unquoted s-expression should be identifier or s-expression",
        )
        return {}, false
    }

    special_form_kind: Special_Form_Kind = .None

    if sexpr_items[0].tag == .Ident {
        ident := sexpr_items[0].value.(string)

        switch ident {
        case "@pub-import":
            special_form_kind = .Pub_Import
            if len(sexpr_items) != 3 {
                return parse_error_list(
                    "error: special form '@pub-import' should take 2 arguments (@pub-import <module_name> \"path_to_modile.lfjs\">)",
                )
            }
            if sexpr_items[1].tag != .Ident {
                return parse_error_list(
                    "error: special form '@pub-import' expects module name as first argument (@pub-import <module_name> \"path_to_modile.lfjs\">)",
                )
            }
            if sexpr_items[2].tag != .String {
                return parse_error_list(
                    "error: special form '@pub-import' expects module path as second argument (@pub-import <module_name> \"path_to_modile.lfjs\">)",
                )
            }
        case "@embed-code":
            special_form_kind = .Embed_Code
            if len(sexpr_items) != 2 {
                return parse_error_list(
                    "error: special form '@embed_code' should take 2 arguments (@embed-code \"console.log('hello world')\")",
                )
            }
        case "@import":
            special_form_kind = .Import
            if len(sexpr_items) != 3 {
                return parse_error_list(
                    "error: special form 'import' should take 2 arguments (import <module_name> \"path_to_modile.lfjs\">)",
                )
            }
            if sexpr_items[1].tag != .Ident {
                return parse_error_list(
                    "error: special form 'import' expects module name as first argument (import <module_name> \"path_to_modile.lfjs\">)",
                )
            }
            if sexpr_items[2].tag != .String {
                return parse_error_list(
                    "error: special form 'import' expects module path as second argument (import <module_name> \"path_to_modile.lfjs\">)",
                )
            }
        case "lambda":
            special_form_kind = .Lambda
            if len(sexpr_items) != 3 {
                return parse_error_list(
                    "error: special form 'lambda' should take 2 arguments (lambda (<param_0> <param_n>) <s-expression>)",
                )
            }
            maybe_params_list := sexpr_items[1]
            if maybe_params_list.tag != .List {
                return parse_error_list(
                    "error: special form 'lambda' expect parameter name list as first argument, for example (lambda (x y z) (+ x y z))",
                )
            }
            params_list := sexpr_items[1].value.(SExpr_List).items
            for param in params_list {
                if param.tag != .Ident {
                    return parse_error_list(
                        "error: special form 'lambda' expect parameter name list as first argument, for example (lambda (x y z) (+ x y z))",
                    )
                }
            }
        case "cond":
            special_form_kind = .Cond
            if len(sexpr_items) < 5 {
                return parse_error_list(
                    "error: special form 'cond' should take at least 4 arguments (cond <condition-1> <result-1> <cond-2> <result-2> ...)",
                )
            }

            if len(sexpr_items) % 2 == 0 {
                return parse_error_list(
                    "error: special form 'cond' should take even number of arguments (cond <condition-1> <result-1> <cond-2> <result-2> ...)",
                )
            }
        case "do":
            special_form_kind = .Do
            if len(sexpr_items) < 2 {
                return parse_error_list(
                    "error: special form 'do' should take at least 1 argument (do <expr-1> [expr-*])",
                )
            }
        case "def":
            special_form_kind = .Def
            if len(sexpr_items) != 3 && len(sexpr_items) != 4 {
                return parse_error_list(
                    "error: special form 'def' should take 2 or 3 arguments (def <def_name> (<param_0> <param_n>) <s-expression>) or (def <def_name> <value>)",
                )
            }
            if sexpr_items[1].tag != .Ident {
                return parse_error_list(
                    "error: special form 'def' should take definition name as first parameter",
                )
            }
            if len(sexpr_items) == 4 {
                maybe_params_list := sexpr_items[2]
                if maybe_params_list.tag != .List {
                    return parse_error_list(
                        "error: special form 'def' expect parameter name list as second argument, for example (def sum3 (x y z) (+ x y z))",
                    )
                }
                params_list := sexpr_items[2].value.(SExpr_List).items
                for param in params_list {
                    if param.tag != .Ident {
                        return parse_error_list(
                            "error: special form 'def' expect parameter name list as second argument, for example (def sum3 (x y z) (+ x y z))",
                        )
                    }
                }
            }
        case "let":
            special_form_kind = .Let
            if len(sexpr_items) != 3 {
                return parse_error_list(
                    "error: special form 'let' should have 2 arguments <(name value)> <s-expression>",
                )
            }
            if (sexpr_items[1].tag != .List) ||
               (len(sexpr_items[1].value.(SExpr_List).items) % 2 != 0) {
                return parse_error_list(
                    "error: special form 'let' should take s-expression in form (name1 value1 name2 value2) as first argument",
                )
            }
        case "if":
            special_form_kind = .If
            if len(sexpr_items) != 4 {
                return parse_error_list(
                    "error: special form 'if' should have 3 arguments (<cond> <then> <else>)",
                )
            }
        }
    }

    return SExpr_List {
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

@(require_results)
parse_error_list :: proc(msg: string) -> (SExpr_List, bool) {
    fmt.println(msg)
    return {}, false
}

make_sexpr :: proc(
    tag: SExpr_Tag,
    value: SExpr_Value,
    row: u16,
    col: u16,
) -> SExpr {
    return {tag = tag, value = value, row = row, col = col}
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
