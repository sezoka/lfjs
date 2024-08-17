package lfjs

import "core:fmt"
import os "core:os/os2"


main :: proc() {
    args := os.args
    if len(args) != 3 && len(args) != 2 {
        fmt.eprintln("usage: lfjs <src.lfjs> [out.js]")
        return
    }

    src, read_err := os.read_entire_file_from_path(args[1], context.allocator)
    if read_err != nil {
        fmt.eprintln("failed reading file", args[1])
        return
    }

    tokens, tokenizer_ok := get_tokens_list(string(src))
    if !tokenizer_ok do return
    sexprs, parse_ok := parse(tokens)
    if !parse_ok {
        fmt.println("parse fail")
        return
    }
    js_code := render_js_code(sexprs)

    out_path: string
    if len(args) == 2 {
        out_path = "out.js"
    } else {
        out_path = args[2]
    }

    write_err := os.write_entire_file(out_path, transmute([]u8)js_code, 0x555)

    if len(args) == 2 {
        process, process_err := os.process_start(
            {
                command = []string{"node", "-e", js_code},
                stdout = os.stdout,
                stderr = os.stderr,
            },
        )
        if process_err != nil {
            fmt.eprintln("failed opening node")
            return
        }
        process_state, process_wait_err := os.process_wait(process)
        return
    }
}
