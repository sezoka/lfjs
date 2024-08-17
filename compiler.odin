package lfjs

import "core:fmt"

compile_to_js :: proc(src: string) -> (result: string, ok: bool) {
    tokens := get_tokens_list(src) or_return
    sexprs, parse_ok := parse(tokens)
    if !parse_ok {
        fmt.println("parse fail")
        return
    }
    js_code := render_js_code(sexprs)

    return js_code, true
}
