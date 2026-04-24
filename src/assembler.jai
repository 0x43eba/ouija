WordKind :: enum {
    PUSH;
    PRIMITIVE;
    MODIFIED;
    FUNCTION;
    INTERNAL;
    ARRAY;
}

Word :: struct {
    kind: WordKind;
    using Payload: union {
        value: float64;
        array_value: [..]Word;
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
            case .OPEN_BRACE;
                subiterator := 1;
                top_word: Word;
                top_word.kind = .ARRAY;
                word_collection: [..]Word;
                while cursor + subiterator < total_tokens {
                    next := tokens[cursor+subiterator];
                    if next.kind == .CLOSE_BRACE {
                        break;
                    }
                    if next.kind != .NUMBER {
                        print("This isn't Python, don't put an unsigned Toyota Yaris into the array and this won't happen.\n");
                        print("ERR CODE: SKILL_ISSUE");
                        return words, false;
                    }
                    w: Word;
                    w.kind = .PUSH;
                    w.value = next.number_value;
                    array_add(*word_collection, w);
                    subiterator += 1;
                }
                top_word.array_value = word_collection;
                array_add(*words, top_word);
                cursor += subiterator + 1;
            case .INTERNAL;
                w: Word;
                w.kind = .INTERNAL;
                w.glyph = token.codepoint;
                array_add(*words, w);
                cursor += 1;
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
            case .INTERNAL;
                print(" internal=U+%", formatInt(it.glyph, base=16, minimum_digits=4));
        }
        print("\n");
    }
}
