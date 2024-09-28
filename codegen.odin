package lfjs
import "core:fmt"
import "core:strings"

Renderer :: struct {
    buff:                   strings.Builder,
    last_expr_is_printable: bool,
    scope_depth:            i32,
    dir_path:               string,
    need_export:            bool,
}

push_str :: proc(r: ^Renderer, str: string) {
    strings.write_string(&r.buff, str)
}

push_int :: proc(r: ^Renderer, i: int) {
    strings.write_int(&r.buff, i)
}

pop_byte :: proc(r: ^Renderer, cnt := 1) {
    for _ in 0 ..< cnt do strings.pop_byte(&r.buff)
}

render_js_code :: proc(
    sexpr_list: []SExpr,
    need_prelude: bool,
    need_export: bool,
    dir_path: string,
) -> (
    result: string,
    ok: bool,
) {
    r: Renderer
    r.dir_path = dir_path
    r.need_export = need_export
    strings.builder_init(&r.buff)

    if need_prelude {
        push_str(&r, "const __lfjs_stack = [];\n")
        push_str(&r, "let __lfjs_line, __lfjs_row;\n")
        push_str(&r, "try {")
        push_str(
            &r,
            compile_file_to_js(
                "./prelude/prelude.lfjs",
                false,
                false,
                ".",
            ) or_return,
        )
    }
    if need_export {
        push_str(&r, "const ___module_export = {};\n")
    }

    for &item in sexpr_list {
        if item.tag == .List {
            render_sexpr(&r, &item.value.(SExpr_List)) or_return
            push_str(&r, ";\n")
        }
    }

    if need_prelude {
        push_str(&r, "} catch (err) {")
        push_str(&r, #load("./js_snippets/catch.js"))
        push_str(&r, "}")
    }

    return strings.to_string(r.buff), true
}

is_printable_sexpr_list :: proc(r: ^Renderer, list: SExpr_List) -> bool {
    return(
        list.special_form_kind != .Def &&
        list.special_form_kind != .Import &&
        len(list.items) != 0 &&
        !(list.items[0].tag == .Ident &&
                list.items[0].value.(string) == "print") \
    )
}

is_printable_sexpr :: proc(r: ^Renderer, item: SExpr) -> bool {
    switch item.tag {
    case .List:
        return is_printable_sexpr_list(r, item.value.(SExpr_List))
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

@(require_results)
render_sexpr :: proc(r: ^Renderer, sexpr_list: ^SExpr_List) -> bool {
    if len(sexpr_list.items) == 0 {
        push_str(r, "undefined")
        return false
    }

    r.scope_depth += 1
    defer r.scope_depth -= 1

    switch sexpr_list.special_form_kind {
    case .Embed_Code:
        code := sexpr_list.items[1].value.(string)
        push_str(r, code)
    case .Import, .Pub_Import:
        is_pub_import := sexpr_list.special_form_kind == .Pub_Import

        module_path := sexpr_list.items[2].value.(string)
        push_str(r, "const ")
        push_str(
            r,
            replace_problematic_idents(sexpr_list.items[1].value.(string)),
        )
        push_str(r, " = (function () {\n")
        module_code := compile_file_to_js(
            module_path,
            false,
            true,
            r.dir_path,
        ) or_return
        push_str(r, module_code)
        push_str(r, "return ___module_export;\n})();\n")
        if is_pub_import {
            push_str(r, "___module_export[\"")
            module_name := replace_problematic_idents(
                sexpr_list.items[1].value.(string),
            )
            push_str(r, module_name)
            push_str(r, "\"] = ")
            push_str(r, module_name)
            push_str(r, ";\n")
        }
    case .Lambda:
        params := sexpr_list.items[1].value.(SExpr_List).items
        lambda_body := sexpr_list.items[2]
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
        for i := 1; i < len(sexpr_list.items); i += 2 {
            render_sexpr_item(r, &sexpr_list.items[i])
            push_str(r, " ? ")
            render_sexpr_item(r, &sexpr_list.items[i + 1])
            if len(sexpr_list.items) - 2 <= i {
                push_str(r, " : undefined")
            } else {
                push_str(r, " : ")
            }
        }
    case .Do:
        push_str(r, "{")
        for &item, i in sexpr_list.items[1:] {
            is_printable := is_printable_sexpr(r, item)
            is_last := len(sexpr_list.items) - 2 <= i
            render_sexpr_item(r, &item)
            push_str(r, ";\n")
        }
        push_str(r, "}")
    case .Def:
        def_name := replace_problematic_idents(
            sexpr_list.items[1].value.(string),
        )
        if len(sexpr_list.items) == 4 {
            params := sexpr_list.items[2].value.(SExpr_List).items
            lambda_body := sexpr_list.items[3]
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
                sexpr_list.items[1].value.(string),
            )
            def_value := sexpr_list.items[2]
            push_str(r, "const ")
            push_str(r, def_name)
            push_str(r, " = ")
            render_sexpr_item(r, &def_value)
        }
        if r.scope_depth <= 1 && r.need_export {
            push_str(r, ";\n___module_export[\"")
            push_str(r, def_name)
            push_str(r, "\"] = ")
            push_str(r, def_name)
        }
    case .Let:
        push_str(r, "(((")
        decl_list := sexpr_list.items[1].value.(SExpr_List).items
        for i := 0; i < len(decl_list); i += 2 {
            name := replace_problematic_idents(decl_list[i].value.(string))
            push_str(r, name)
            push_str(r, ", ")
        }
        pop_byte(r, 2)
        push_str(r, ") => ")
        render_sexpr_item(r, &sexpr_list.items[2])
        push_str(r, ")(")
        for i := 1; i < len(decl_list); i += 2 {
            value := decl_list[i].value.(f64)
            fmt.sbprintf(&r.buff, "%0f", value)
            push_str(r, ", ")
        }
        pop_byte(r, 2)
        push_str(r, "))")
    case .If:
        push_str(r, "(")
        render_sexpr_item(r, &sexpr_list.items[1])
        push_str(r, " ? ")
        render_sexpr_item(r, &sexpr_list.items[2])
        push_str(r, " : ")
        render_sexpr_item(r, &sexpr_list.items[3])
        push_str(r, ")")
    case .None:
        if sexpr_list.items[0].tag == .Ident {
            item := &sexpr_list.items[0]
            push_str(r, "__lfjs_call(")
            render_sexpr_item(r, &sexpr_list.items[0])
            push_str(r, ", ")
            push_int(r, int(item.row))
            push_str(r, ", ")
            push_int(r, int(item.col))
            push_str(r, ")(")
        } else {
            render_sexpr_item(r, &sexpr_list.items[0])
            push_str(r, "(")
        }
        if len(sexpr_list.items) > 1 {
            for &item in sexpr_list.items[1:] {
                render_sexpr_item(r, &item)
                push_str(r, ", ")
            }
            pop_byte(r, 2)
        }
        push_str(r, ")")
    }

    return true
}

render_ident_with_runtime_check :: proc(r: ^Renderer, item: ^SExpr) {
    push_str(r, "(__lfjs_check_var(typeof ")
    render_sexpr_item(r, item)
    push_str(r, ", \"")
    push_str(r, item.value.(string))
    push_str(r, "\", ")
    push_int(r, int(item.row))
    push_str(r, ", ")
    push_int(r, int(item.col))
    push_str(r, "), ")
    render_sexpr_item(r, item)
    push_str(r, ")")
}

render_sexpr_item :: proc(r: ^Renderer, sexpr: ^SExpr) -> bool {
    switch sexpr.tag {
    case .List:
        return render_sexpr(r, &sexpr.value.(SExpr_List))
    case .Ident:
        orig_ident := sexpr.value.(string)
        ident := replace_problematic_idents(sexpr.value.(string))
        push_str(r, "(__lfjs_check_var(typeof ")
        push_str(r, ident)
        push_str(r, ", \"")
        push_str(r, orig_ident)
        push_str(r, "\", ")
        push_int(r, int(sexpr.row))
        push_str(r, ", ")
        push_int(r, int(sexpr.col))
        push_str(r, "), ")
        push_str(r, ident)
        push_str(r, ")")
    case .Number:
        fmt.sbprintf(&r.buff, "%0f", sexpr.value.(f64))
    case .String:
        push_str(r, "\"")
        push_str(r, sexpr.value.(string))
        push_str(r, "\"")
    case .Field_Access:
        push_str(r, replace_problematic_idents(sexpr.value.(string), true))
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
