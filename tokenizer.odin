package lfjs

import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:unicode"

Token :: struct {
    tag:    Token_Tag,
    value:  Token_Value,
    lexeme: string,
    row:    u16,
    col:    u16,
}

Token_Tag :: enum {
    Unknown,
    Left_Paren,
    Right_Paren,
    Ident,
    Field_Access,
    Number,
    Quote,
    String,
    Eof,
}

Token_Value :: union {
    f64,
    string,
}

Tokenizer :: struct {
    reader:    strings.Reader,
    pos:       uint,
    row:       u16,
    col:       u16,
    start_col: u16,
    start_row: u16,
    start:     i64,
}

get_tokens_list :: proc(src: string) -> ([]Token, bool) {
    reader: strings.Reader
    strings.reader_init(&reader, src)

    tokenizer := Tokenizer {
        reader = reader,
        row    = 1,
        col    = 1,
    }

    tokens_list: [dynamic]Token


    for token, ok := scan_next_token(&tokenizer);
        ok;
        token, ok = scan_next_token(&tokenizer) {
        assert(token.tag != .Unknown)
        append(&tokens_list, token)

        if token.tag == .Eof do break
    }

    if len(tokens_list) != 0 && tokens_list[len(tokens_list) - 1].tag == .Eof {
        return tokens_list[:], true
    }

    return {}, false
}

scan_next_token :: proc(t: ^Tokenizer) -> (Token, bool) {
    skip_whitespaces(t)

    if is_tokenizer_at_end(t) {
        return make_token(t, .Eof), true
    }

    t.start = t.reader.i
    t.start_col = t.col
    t.start_row = t.row

    r := next_rune(t)

    switch r {
    case '(':
        return make_token(t, .Left_Paren), true
    case ')':
        return make_token(t, .Right_Paren), true
    case '\'':
        return make_token(t, .Quote), true
    case '"':
        return read_string(t, '"')
    case '`':
        return read_string(t, '`')
    case:
        if unicode.is_digit(r) ||
           (unicode.is_digit(peek_rune(t)) && r == '-') {
            return read_number(t)
        }

        return read_symbol(t), true
    }

    return {}, false
}

read_string :: proc(t: ^Tokenizer, sym: rune) -> (Token, bool) {
    for !is_tokenizer_at_end(t) && peek_rune(t) != sym {
        prev := next_rune(t)
        if prev == '\\' && peek_rune(t) == sym {
            next_rune(t)
        }
    }
    if is_tokenizer_at_end(t) {
        fmt.eprintln("error: unenclosed string")
        return {}, false
    }
    next_rune(t)

    str := get_curr_token_lexeme(t)
    return make_token(t, .String, str[1:len(str) - 1]), true
}

read_number :: proc(t: ^Tokenizer) -> (Token, bool) {
    for unicode.is_digit(peek_rune(t)) do next_rune(t)
    if peek_rune(t) == '.' {
        next_rune(t)
        for unicode.is_digit(peek_rune(t)) do next_rune(t)
    }

    lex := get_curr_token_lexeme(t)
    val, ok := strconv.parse_f64(lex)
    if ok {
        return make_token(t, .Number, val), true
    }
    fmt.eprintf("can't parse number '%d' as f64\n", lex)
    return {}, false
}

get_curr_token_lexeme :: proc(t: ^Tokenizer) -> string {
    return t.reader.s[t.start:t.reader.i]
}

read_symbol :: proc(t: ^Tokenizer) -> Token {
    is_field_access := false
    for !is_tokenizer_at_end(t) && is_ident_rune(peek_rune(t)) {
        rune := next_rune(t)
        if rune == '.' {
            is_field_access = true
        }
    }

    return make_token(t, is_field_access ? .Field_Access : .Ident)
}

is_ident_rune :: proc(r: rune) -> bool {
    return !(r == '(' || r == ')' || r == '\'' || unicode.is_white_space(r))
}

is_tokenizer_at_end :: proc(t: ^Tokenizer) -> bool {
    return len(t.reader.s) <= int(t.reader.i)
}

make_token :: proc(
    t: ^Tokenizer,
    tag: Token_Tag,
    value: Token_Value = {},
) -> Token {
    return Token {
        row = t.start_row,
        col = t.start_col,
        tag = tag,
        value = value,
        lexeme = t.reader.s[t.start:t.reader.i],
    }
}

skip_whitespaces :: proc(t: ^Tokenizer) {
    for {
        switch peek_rune(t) {
        case ' ', '\r', '\t', '\n':
            next_rune(t)
        case ';':
            for !is_tokenizer_at_end(t) && peek_rune(t) != '\n' {
                next_rune(t)
            }
        case:
            return
        }
    }
}

peek_rune :: proc(t: ^Tokenizer) -> rune {
    rr, size, _ := strings.reader_read_rune(&t.reader)
    t.reader.i -= i64(size)
    if size == 0 do return 0
    return rr
}

next_rune :: proc(t: ^Tokenizer) -> rune {
    rr, size, _ := strings.reader_read_rune(&t.reader)
    if rr == '\n' {
        t.row += 1
        t.col = 0
    }
    t.col += 1
    if size == 0 do return 0
    return rr
}
