package lfjs

import "core:fmt"
import os "core:os/os2"
import "core:path/filepath"
import "core:strings"

compile_to_js :: proc(
    src: string,
    need_prelude: bool,
    need_export: bool,
    dir_path: string,
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

    return render_js_code(sexprs, need_prelude, need_export, dir_path)
}

compile_file_to_js :: proc(
    path_to_file: string,
    need_prelude: bool,
    need_export: bool,
    base_path: string,
) -> (
    result: string,
    ok: bool,
) {
    full_path_to_file := strings.concatenate({base_path, "/", path_to_file})
    compiled_file_dir_path := filepath.dir(full_path_to_file)

    src, read_err := os.read_entire_file_from_path(
        full_path_to_file,
        context.allocator,
    )
    if read_err != nil {
        fmt.eprintln("failed reading file", full_path_to_file)
        return
    }

    return compile_to_js(string(src), need_prelude, need_export, compiled_file_dir_path)
}
