package lfjs

import "core:fmt"
import os "core:os/os2"

compile_to_js :: proc(
    src: string,
    need_prelude: bool,
) -> (
    result: string,
    ok: bool,
) {
    tokens := get_tokens_list(src) or_return
    sexprs, parse_ok := parse(tokens)
    if !parse_ok {
        fmt.println("parse fail")
        return {}, false
    }

    return render_js_code(sexprs, need_prelude)
}

compile_file_to_js :: proc(
    path_to_file: string,
    need_prelude := true,
) -> (
    result: string,
    ok: bool,
) {
    src, read_err := os.read_entire_file_from_path(
        path_to_file,
        context.allocator,
    )
    if read_err != nil {
        fmt.eprintln("failed reading file", path_to_file)
        return
    }

    return compile_to_js(string(src), need_prelude)
}
