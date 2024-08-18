package lfjs

import "core:fmt"
import os "core:os/os2"
import "core:strings"


main :: proc() {
    args := os.args
    if len(args) != 3 && len(args) != 2 {
        fmt.eprintln("usage: lfjs <src.lfjs> [out.js]")
        return
    }

    js_code, compile_ok := compile_file_to_js(args[1], true, "./")
    if !compile_ok do return


    out_path: string
    if len(args) == 2 {
        out_path = "out.js"
    } else {
        out_path = args[2]
    }

    write_err := os.write_entire_file(out_path, transmute([]u8)js_code, 0x700)

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
