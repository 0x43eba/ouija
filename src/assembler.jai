WordKind :: enum {
    PUSH;
    PRIMITIVE;
    MODIFIED;
    FUNCTION;
}

Word :: struct {
    kind: WordKind;
    using Payload: union {
        value: float64;
        glyph: u32;
        modified: struct {
            modifier: u32;
            operand: *Word;
        };
        function: [..]Word;
    }
}

assemble :: (tokens: [] Token) -> [..] Word, bool {
    words: [..] Word;
    total_tokens := tokens.count;
    cursor := 0;
    while cursor < total_tokens {
        token := tokens[cursor];
        if token.kind == {
            case .MODIFIER;
                operand_words := assemble(array_view(tokens, cursor + 1, total_tokens - (cursor + 1)));
                w: Word;
                w.kind = .MODIFIED;
                w.modified.modifier = token.codepoint;
                w.modified.operand = New(Word);
                w.modified.operand.* = operand_words[0];
                array_add(*words, w);
                cursor += 2;
            case .GLYPH;
                w: Word;
                w.kind = .PRIMITIVE;
                w.glyph = token.codepoint;
                array_add(*words, w);
                cursor += 1;
            case .NUMBER;
                w: Word;
                w.kind = .PUSH;
                w.value = token.number_value;
                array_add(*words, w);
                cursor += 1;
            case;
                cursor += 1;
        }
    }
    return words, true;
}


print_words :: (words: [] Word) {
    print("[% words]\n", words.count);
    for words {
        print("  %: kind=%", it_index, it.kind);
        if it.kind == {
            case .PUSH;
                print(" value=%", it.value);
            case .PRIMITIVE;
                print(" glyph=U+%", formatInt(it.glyph, base=16, minimum_digits=4));
            case .MODIFIED;
                print(" modifier=U+% operand=U+%",
                    formatInt(it.modified.modifier, base=16, minimum_digits=4),
                    formatInt(it.modified.operand.glyph, base=16, minimum_digits=4));
            case .FUNCTION;
                print(" function=[% words]", it.function.count);
        }
        print("\n");
    }
}
