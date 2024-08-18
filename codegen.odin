package lfjs
import "core:fmt"
import "core:strings"

Renderer :: struct {
    buff:                   strings.Builder,
    last_expr_is_printable: bool,
    scope_depth:            i32,
    dir_path:               string,
}

push_str :: proc(r: ^Renderer, str: string) {
    strings.write_string(&r.buff, str)
}

pop_byte :: proc(r: ^Renderer, cnt := 1) {
    for _ in 0 ..< cnt do strings.pop_byte(&r.buff)
}

render_js_code :: proc(
    sexprs: []SExpr,
    need_prelude: bool,
    dir_path: string,
) -> (
    result: string,
    ok: bool,
) {
    r: Renderer
    r.dir_path = dir_path
    strings.builder_init(&r.buff)

    if need_prelude {
        push_str(&r, string(#load("./prelude.js")))
        push_str(&r, "const std = (function() {\n")
        push_str(
            &r,
            compile_file_to_js("./std/std.lfjs", false, "./") or_return,
        )
        push_str(&r, "return ___module_export;\n})()\n")
    }
    push_str(&r, "const ___module_export = {};\n")


    for &sexpr in sexprs {
        is_printable := is_printable_sexpr(&r, sexpr)
        render_sexpr(&r, &sexpr) or_return
        push_str(&r, ";\n")
    }

    return strings.to_string(r.buff), true
}

is_printable_sexpr :: proc(r: ^Renderer, sexpr: SExpr) -> bool {
    return(
        sexpr.special_form_kind != .Def &&
        sexpr.special_form_kind != .Import &&
        len(sexpr.items) != 0 &&
        !(sexpr.items[0].tag == .Ident &&
                sexpr.items[0].value.(string) == "print") \
    )
}

is_printable_sexpr_item :: proc(r: ^Renderer, item: SExpr_Item) -> bool {
    switch item.tag {
    case .SExpr:
        return is_printable_sexpr(r, item.value.(SExpr))
    case .Ident:
        return true
    case .Number:
        return true
    case .String:
        return true
    case .Field_Access:
        return true
    }
    return true
}

render_equality_or_comparison :: proc(
    r: ^Renderer,
    sfk: Special_Form_Kind,
) -> int {
    op_len := 1
    #partial switch sfk {
    case .Less:
        push_str(r, "<")
    case .Greater:
        push_str(r, ">")
    case .Less_Equal:
        push_str(r, "<=")
        op_len = 2
    case .Greater_Equal:
        push_str(r, ">=")
        op_len = 2
    case .Not_Equal:
        push_str(r, "!==")
        op_len = 2
    case .Equal:
        push_str(r, "===")
        op_len = 2
    case:
        panic("unreachable")
    }
    return op_len
}

@(require_results)
render_sexpr :: proc(r: ^Renderer, sexpr: ^SExpr) -> bool {
    if len(sexpr.items) == 0 {
        push_str(r, "undefined")
        return false
    }

    r.scope_depth += 1
    defer r.scope_depth -= 1

    switch sexpr.special_form_kind {
    case .Embed_Code:
        code := sexpr.items[1].value.(string)
        push_str(r, code)
    case .Import:
        module_name := sexpr.items[1].value.(string)
        module_path := sexpr.items[2].value.(string)
        push_str(r, "const ")
        render_sexpr_item(r, &sexpr.items[1])
        push_str(r, " = (function () {\n")
        module_code := compile_file_to_js(
            module_path,
            false,
            r.dir_path,
        ) or_return
        push_str(r, module_code)
        push_str(r, "return ___module_export;\n})()")
    case .Lambda:
        params := sexpr.items[1].value.(SExpr).items
        lambda_body := sexpr.items[2]
        push_str(r, "((")
        for param in params {
            push_str(r, replace_problematic_idents(param.value.(string)))
            push_str(r, ", ")
        }
        if len(params) != 0 {
            pop_byte(r, 2)
        }
        push_str(r, ") => ")
        render_sexpr_item(r, &lambda_body)
        push_str(r, ")")
    case .Cond:
        for i := 1; i < len(sexpr.items); i += 2 {
            render_sexpr_item(r, &sexpr.items[i])
            push_str(r, " ? ")
            render_sexpr_item(r, &sexpr.items[i + 1])
            if len(sexpr.items) - 2 <= i {
                push_str(r, " : undefined")
            } else {
                push_str(r, " : ")
            }
        }
    case .Do:
        push_str(r, "{")
        for &item, i in sexpr.items[1:] {
            is_printable := is_printable_sexpr_item(r, item)
            is_last := len(sexpr.items) - 2 <= i
            render_sexpr_item(r, &item)
            push_str(r, ";\n")
        }
        push_str(r, "}")
    case .Def:
        def_name := replace_problematic_idents(sexpr.items[1].value.(string))
        if len(sexpr.items) == 4 {
            params := sexpr.items[2].value.(SExpr).items
            lambda_body := sexpr.items[3]
            push_str(r, "const ")
            push_str(r, def_name)
            push_str(r, " = (")

            for param in params {
                push_str(r, replace_problematic_idents(param.value.(string)))
                push_str(r, ", ")
            }
            if len(params) != 0 {
                pop_byte(r, 2)
            }
            push_str(r, ") => ")
            render_sexpr_item(r, &lambda_body)
        } else {
            def_name := replace_problematic_idents(
                sexpr.items[1].value.(string),
            )
            def_value := sexpr.items[2]
            push_str(r, "const ")
            push_str(r, def_name)
            push_str(r, " = ")
            render_sexpr_item(r, &def_value)
        }
        if r.scope_depth <= 1 {
            push_str(r, ";\n___module_export[\"")
            push_str(r, def_name)
            push_str(r, "\"] = ")
            push_str(r, def_name)
        }
    case .Let:
        push_str(r, "(((")
        decl_list := sexpr.items[1].value.(SExpr).items
        for i := 0; i < len(decl_list); i += 2 {
            name := replace_problematic_idents(decl_list[i].value.(string))
            push_str(r, name)
            push_str(r, ", ")
        }
        pop_byte(r, 2)
        push_str(r, ") => ")
        render_sexpr_item(r, &sexpr.items[2])
        push_str(r, ")(")
        for i := 1; i < len(decl_list); i += 2 {
            value := decl_list[i].value.(f64)
            fmt.sbprintf(&r.buff, "%0f", value)
            push_str(r, ", ")
        }
        pop_byte(r, 2)
        push_str(r, "))")
    case .Less, .Equal, .Greater, .Less_Equal, .Greater_Equal, .Not_Equal:
        push_str(r, "(")
        op_len: int
        for i in 1 ..< len(sexpr.items) - 1 {
            item_a := sexpr.items[i]
            item_b := sexpr.items[i + 1]
            is_at_end := len(sexpr.items) - 1 <= i

            push_str(r, "(")
            render_sexpr_item(r, &item_a)
            push_str(r, " ")
            op_len = render_equality_or_comparison(r, sexpr.special_form_kind)
            push_str(r, " ")
            render_sexpr_item(r, &item_b)
            push_str(r, ")")
            if !is_at_end {
                push_str(r, " && ")
            }
        }
        pop_byte(r, 4)
        push_str(r, ")")
    case .Plus, .Minus, .Div, .Mult:
        if len(sexpr.items) == 2 {
            #partial switch sexpr.special_form_kind {
            case .Minus:
                push_str(r, "-")
                render_sexpr_item(r, &sexpr.items[1])
            case:
                panic("unreachable")
            }
            return false
        }
        push_str(r, "(")
        for &item in sexpr.items[1:] {
            render_sexpr_item(r, &item)
            push_str(r, " ")
            #partial switch sexpr.special_form_kind {
            case .Plus:
                push_str(r, "+")
            case .Minus:
                push_str(r, "-")
            case .Div:
                push_str(r, "/")
            case .Mult:
                push_str(r, "*")
            case .Equal:
                push_str(r, "+")
            case:
                panic("unreachable")
            }
            push_str(r, " ")
        }
        pop_byte(r, 3)
        push_str(r, ")")
    case .If:
        push_str(r, "(")
        render_sexpr_item(r, &sexpr.items[1])
        push_str(r, " ? ")
        render_sexpr_item(r, &sexpr.items[2])
        push_str(r, " : ")
        render_sexpr_item(r, &sexpr.items[3])
        push_str(r, ")")
    case .None:
        render_sexpr_item(r, &sexpr.items[0])
        push_str(r, "(")
        if len(sexpr.items) > 1 {
            for &item in sexpr.items[1:] {
                render_sexpr_item(r, &item)
                push_str(r, ", ")
            }
            pop_byte(r, 2)
        }
        push_str(r, ")")
    }

    return true
}

render_sexpr_item :: proc(r: ^Renderer, item: ^SExpr_Item) -> bool {
    switch item.tag {
    case .SExpr:
        return render_sexpr(r, &item.value.(SExpr))
    case .Ident:
        push_str(r, replace_problematic_idents(item.value.(string)))
    case .Number:
        fmt.sbprintf(&r.buff, "%0f", item.value.(f64))
    case .String:
        push_str(r, "\"")
        push_str(r, item.value.(string))
        push_str(r, "\"")
    case .Field_Access:
        push_str(r, replace_problematic_idents(item.value.(string), true))
    }

    return true
}

replace_problematic_idents :: proc(
    lexeme: string,
    skip_dots: bool = false,
) -> string {
    filtered_lexeme: strings.Builder
    strings.builder_init(&filtered_lexeme)

    if (is_reserved_keyword(lexeme)) {
        strings.write_rune(&filtered_lexeme, '_')
        strings.write_string(&filtered_lexeme, lexeme)
        return strings.to_string(filtered_lexeme)
    }

    if !check_is_allowed_as_first_character_of_name(rune(lexeme[0])) {
        strings.write_rune(&filtered_lexeme, '_')
    }

    for r in lexeme {
        if '0' <= r && r <= '9' ||
           'a' <= r && r <= 'z' ||
           'A' <= r && r <= 'Z' ||
           (skip_dots && r == '.') ||
           r == '_' {
            strings.write_rune(&filtered_lexeme, r)
        } else {
            fmt.sbprint(&filtered_lexeme, u32(r))
        }
    }
    return strings.to_string(filtered_lexeme)
}

is_reserved_keyword :: proc(lexeme: string) -> bool {
    switch lexeme {
    case "else", "if", "while", "function", "for":
        return true
    }
    return false
}

check_is_allowed_as_first_character_of_name :: proc(r: rune) -> bool {
    return r == '_' || 'a' <= r && r <= 'z' || 'A' <= r && r <= 'Z' || r == '_'
}
