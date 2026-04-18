#import "Basic";

CODEPOINT_BINDING_ARROW :: 0x2190;
CODEPOINT_ADD           :: 0x002B;
CODEPOINT_SUB           :: 0x2212;
CODEPOINT_MUL           :: 0x00D7;
CODEPOINT_DIV           :: 0x00F7;
CODEPOINT_REDUCE        :: 0x002F;
CODEPOINT_IOTA          :: 0x21E1;
CODEPOINT_FIRST         :: 0x2283;
CODEPOINT_ETA           :: 0x03B7;
CODEPOINT_PI            :: 0x03C0;
CODEPOINT_TAU           :: 0x03C4;
CODEPOINT_INF           :: 0x221E;

TokenKind :: enum {
    NUMBER;
    LETTER;
    GLYPH;
    MODIFIER;
    IDENT;
    ARROW;
    OPEN_PAREN;
    CLOSE_PAREN;
    NEWLINE;
}

Token :: struct {
    kind: TokenKind;
    original_offset: s64;
    length: s64;
    using payload: union {
        number_value: float64;
        codepoint: u32;
        name: string;
    }
}

codepoint_to_token :: (codepoint: u32, offset: s64) -> Token, bool {
    t: Token;
    t.original_offset = offset;
    t.length = 1;
    t.payload.codepoint = codepoint;
    if codepoint == {
        case CODEPOINT_BINDING_ARROW;
            t.kind = .ARROW;
        case CODEPOINT_ADD;  #through;
        case CODEPOINT_SUB;  #through;
        case CODEPOINT_MUL;  #through;
        case CODEPOINT_DIV;  #through;
        case CODEPOINT_IOTA; #through;
        case CODEPOINT_FIRST;
            t.kind = .GLYPH;
        case CODEPOINT_REDUCE;
            t.kind = .MODIFIER;
        case CODEPOINT_ETA; #through;
        case CODEPOINT_PI;  #through;
        case CODEPOINT_TAU; #through;
        case CODEPOINT_INF;
            t.kind = .NUMBER;
        case #char "(";
            t.kind = .OPEN_PAREN;
        case #char ")";
            t.kind = .CLOSE_PAREN;
        case #char "\n";
            t.kind = .NEWLINE;
        case;
            print("Unknown codepoint: %\n", codepoint);
            return t, false;
    }
    return t, true;
}

char_letter_to_token :: (codepoint: *u8, offset: s64) -> Token {
    t: Token;
    t.original_offset = offset;
    return t;
}

evaluate :: (input: *u8, count: s64) -> [..] Token, bool {
    cursor := 0;
    tokens : [..] Token;
    while cursor < count {
        bac := input[cursor];
        if bac == #char " " || bac == #char "\t" {
            cursor +=1;
            continue;
        }
        if bac >= #char "0" && bac <= #char "9" {
            start := cursor;
            while cursor < count && input[cursor] >= #char "0" && input[cursor] <= #char "9" {
                cursor += 1;
            }
            if cursor < count && input[cursor] == #char "." {
                cursor += 1;
                while cursor < count && input[cursor] >= #char "0" && input[cursor] <= #char "9" {
                    cursor += 1;
                }
            }
            token: Token;
            token.kind = .NUMBER;
            token.original_offset = start;
            token.length = cursor - start;
            num_str: string;
            num_str.data = input + start;
            num_str.count = cursor - start;
            token.number_value = string_to_float(num_str);
            array_add(*tokens, token);
            continue;
        }
        if bac >= #char "a" && bac <= #char "z" || bac >= #char "A" && bac <= #char "Z" {
            start := cursor;
            while cursor < count && (input[cursor] >= #char "a" && input[cursor] <= #char "z" || input[cursor] >= #char "A" && input[cursor] <= #char "Z") {
                cursor += 1;
            }
            token: Token;
            token.kind = .IDENT;
            token.original_offset = start;
            token.length = cursor - start;
            token.name.data = input + start;
            token.name.count = cursor - start;
            array_add(*tokens, token);
            continue;
        }
        else if bac < 128 {
            codepoint := cast(u32) bac;
            token, ok := codepoint_to_token(codepoint, cursor);
            if !ok  {
                return tokens, false;
            }
            array_add(*tokens, token);
            cursor +=1;
            continue;
        } else if bac >= 192 && bac < 224 {
            b1 := cast(u32) bac;
            b2 := cast(u32) input[cursor+1];
            codepoint := ((b1 & 0x1F) << 6) | (b2 & 0x3F);
            token, ok := codepoint_to_token(codepoint, cursor);
            if !ok  {
                return tokens, false;
            }
            array_add(*tokens, token);
            cursor +=2;
            continue;
        } else if bac >= 224 && bac < 240 {
            b1 := cast(u32) bac;
            b2 := cast(u32) input[cursor+1];
            b3 := cast(u32) input[cursor+2];
            codepoint := ((b1 & 0x0F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F);
            token, ok := codepoint_to_token(codepoint, cursor);
            if !ok  {
                return tokens, false;
            }
            array_add(*tokens, token);
            cursor +=3;
            continue;
        } else if bac >= 240 {
            b1 := cast(u32) bac;
            b2 := cast(u32) input[cursor+1];
            b3 := cast(u32) input[cursor+2];
            b4 := cast(u32) input[cursor+3];
            codepoint := ((b1 & 0x07) << 18) | ((b2 & 0x3F) << 12) | ((b3 & 0x3F) << 6) | (b4 & 0x3F);
            token, ok := codepoint_to_token(codepoint, cursor);
            if !ok  {
                return tokens, false;
            }
            array_add(*tokens, token);
            cursor +=4;
            continue;
        } else {
            print("Weird sized codepoint detected, this will fail");
            return tokens, false;
        }

    }

    return tokens, true;
}

print_tokens :: (tokens: [] Token) {
    print("[% tokens]\n", tokens.count);
    for tokens {
        print("  %: kind=% offset=% length=%", it_index, it.kind, it.original_offset, it.length);
        if it.kind == {
            case .NUMBER;
                print(" number_value=%", it.number_value);
            case .IDENT;
                print(" name=\"%\"", it.name);
            case .GLYPH; #through;
            case .ARROW; #through;
            case .OPEN_PAREN; #through;
            case .CLOSE_PAREN; #through;
            case .NEWLINE; #through;
            case .LETTER;
                print(" codepoint=U+%", formatInt(it.codepoint, base=16, minimum_digits=4));
        }
        print("\n");
    }
}

evaluate_string :: (s: string) -> [..] Token, bool {
    tokens, ok := evaluate(s.data, s.count);
    return tokens, ok;
}
