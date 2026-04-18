#load "../src/tokenizer.jai";
#load "../src/assembler.jai";

Expected :: struct {
    kind: TokenKind;
    codepoint: u32 = 0;
    number_value: float64 = 0;
    name: string;
}

g :: (cp: u32) -> Expected { return .{ kind = .GLYPH, codepoint = cp }; }
n :: (v: float64) -> Expected { return .{ kind = .NUMBER, number_value = v }; }
id :: (s: string) -> Expected { return .{ kind = .IDENT, name = s }; }
op :: () -> Expected { return .{ kind = .OPEN_PAREN, codepoint = #char "(" }; }
cp :: () -> Expected { return .{ kind = .CLOSE_PAREN, codepoint = #char ")" }; }
arrow :: () -> Expected { return .{ kind = .ARROW, codepoint = CODEPOINT_BINDING_ARROW }; }
num_glyph :: (cp: u32) -> Expected { return .{ kind = .NUMBER, codepoint = cp }; }

total_tests := 0;
failed_tests := 0;

check :: (name: string, input: string, expected: [] Expected, expect_success := true) {
    total_tests += 1;
    tokens, success := parse_string(input);
    defer array_free(tokens);

    failed := false;
    reason: string;

    if success != expect_success {
        failed = true;
        reason = tprint("expected success=% but got %", expect_success, success);
    } else if tokens.count != expected.count {
        failed = true;
        reason = tprint("expected % tokens but got %", expected.count, tokens.count);
    } else {
        for expected {
            got := tokens[it_index];
            if got.kind != it.kind {
                failed = true;
                reason = tprint("token % kind mismatch: expected % got %", it_index, it.kind, got.kind);
                break;
            }
            if it.kind == {
                case .NUMBER;
                    if it.codepoint != 0 {
                        if got.codepoint != it.codepoint {
                            failed = true;
                            reason = tprint("token % codepoint mismatch: expected U+% got U+%", it_index,
                                formatInt(it.codepoint, base=16), formatInt(got.codepoint, base=16));
                            break;
                        }
                    } else {
                        diff := got.number_value - it.number_value;
                        if diff < 0 diff = -diff;
                        if diff > 0.000001 {
                            failed = true;
                            reason = tprint("token % number mismatch: expected % got %", it_index, it.number_value, got.number_value);
                            break;
                        }
                    }
                case .IDENT;
                    if got.name != it.name {
                        failed = true;
                        reason = tprint("token % name mismatch: expected \"%\" got \"%\"", it_index, it.name, got.name);
                        break;
                    }
                case;
                    if got.codepoint != it.codepoint {
                        failed = true;
                        reason = tprint("token % codepoint mismatch: expected U+% got U+%", it_index,
                            formatInt(it.codepoint, base=16), formatInt(got.codepoint, base=16));
                        break;
                    }
            }
        }
    }

    if failed {
        failed_tests += 1;
        print("  FAIL  %  [%]  — %\n", name, input, reason);
    } else {
        print("  ok    %\n", name);
    }
}

AsmExpected :: struct {
    kind: WordKind;
    value: float64 = 0;
    glyph: u32 = 0;
    modifier: u32 = 0;
    operand_glyph: u32 = 0;
}

aw_push :: (v: float64) -> AsmExpected { return .{ kind = .PUSH, value = v }; }
aw_prim :: (cp: u32) -> AsmExpected { return .{ kind = .PRIMITIVE, glyph = cp }; }
aw_mod  :: (modifier: u32, operand: u32) -> AsmExpected {
    return .{ kind = .MODIFIED, modifier = modifier, operand_glyph = operand };
}

check_asm :: (name: string, input: string, expected: [] AsmExpected, expect_success := true) {
    total_tests += 1;
    tokens, tok_ok := parse_string(input);
    defer array_free(tokens);

    if !tok_ok {
        failed_tests += 1;
        print("  FAIL  %  [%]  — tokenizer failed before assembler could run\n", name, input);
        return;
    }

    words, asm_ok := assemble(tokens);
    defer array_free(words);

    failed := false;
    reason: string;

    if asm_ok != expect_success {
        failed = true;
        reason = tprint("expected success=% but got %", expect_success, asm_ok);
    } else if words.count != expected.count {
        failed = true;
        reason = tprint("expected % words but got %", expected.count, words.count);
    } else {
        for expected {
            got := words[it_index];
            if got.kind != it.kind {
                failed = true;
                reason = tprint("word % kind mismatch: expected % got %", it_index, it.kind, got.kind);
                break;
            }
            if it.kind == {
                case .PUSH;
                    diff := got.value - it.value;
                    if diff < 0 diff = -diff;
                    if diff > 0.000001 {
                        failed = true;
                        reason = tprint("word % value mismatch: expected % got %", it_index, it.value, got.value);
                        break;
                    }
                case .PRIMITIVE;
                    if got.glyph != it.glyph {
                        failed = true;
                        reason = tprint("word % glyph mismatch: expected U+% got U+%", it_index,
                            formatInt(it.glyph, base=16), formatInt(got.glyph, base=16));
                        break;
                    }
                case .MODIFIED;
                    if got.modified.modifier != it.modifier {
                        failed = true;
                        reason = tprint("word % modifier mismatch: expected U+% got U+%", it_index,
                            formatInt(it.modifier, base=16), formatInt(got.modified.modifier, base=16));
                        break;
                    }
                    if got.modified.operand == null {
                        failed = true;
                        reason = tprint("word % operand is null", it_index);
                        break;
                    }
                    if got.modified.operand.kind != .PRIMITIVE {
                        failed = true;
                        reason = tprint("word % operand kind mismatch: expected PRIMITIVE got %", it_index, got.modified.operand.kind);
                        break;
                    }
                    if got.modified.operand.glyph != it.operand_glyph {
                        failed = true;
                        reason = tprint("word % operand glyph mismatch: expected U+% got U+%", it_index,
                            formatInt(it.operand_glyph, base=16), formatInt(got.modified.operand.glyph, base=16));
                        break;
                    }
            }
        }
    }

    if failed {
        failed_tests += 1;
        print("  FAIL  %  [%]  — %\n", name, input, reason);
    } else {
        print("  ok    %\n", name);
    }
}

main :: () {
    print("Running tokenizer tests\n");
    print("=======================\n");

    check("empty input", "", .[]);
    check("only whitespace", "   \t  ", .[]);

    check("single digit", "5", .[n(5)]);
    check("multi digit", "42", .[n(42)]);
    check("float", "3.14", .[n(3.14)]);
    check("zero", "0", .[n(0)]);

    check("ascii add", "+", .[g(CODEPOINT_ADD)]);
    check("ascii reduce", "/", .[g(CODEPOINT_REDUCE)]);
    check("ascii open paren", "(", .[op()]);
    check("ascii close paren", ")", .[cp()]);

    check("multiply glyph", "\u00d7", .[g(CODEPOINT_MUL)]);
    check("divide glyph", "\u00f7", .[g(CODEPOINT_DIV)]);
    check("range glyph", "\u21e1", .[g(CODEPOINT_IOTA)]);
    check("first glyph", "\u2283", .[g(CODEPOINT_FIRST)]);
    check("binding arrow", "\u2190", .[arrow()]);

    check("pi constant", "\u03c0", .[num_glyph(CODEPOINT_PI)]);
    check("tau constant", "\u03c4", .[num_glyph(CODEPOINT_TAU)]);
    check("eta constant", "\u03b7", .[num_glyph(CODEPOINT_ETA)]);
    check("infinity constant", "\u221e", .[num_glyph(CODEPOINT_INF)]);

    check("simple identifier", "abc", .[id("abc")]);
    check("mixed case identifier", "FooBar", .[id("FooBar")]);

    check("reduce add range",
        "/+\u21e15",
        .[ g(CODEPOINT_REDUCE), g(CODEPOINT_ADD), g(CODEPOINT_IOTA), n(5) ]);

    check("spaces between tokens",
        "1 + 2",
        .[ n(1), g(CODEPOINT_ADD), n(2) ]);

    check("parenthesised expression",
        "(1 + 2)",
        .[ op(), n(1), g(CODEPOINT_ADD), n(2), cp() ]);

    check("binding with arrow",
        "x \u2190 5",
        .[ id("x"), arrow(), n(5) ]);

    check("pi times two",
        "\u03c0 \u00d7 2",
        .[ num_glyph(CODEPOINT_PI), g(CODEPOINT_MUL), n(2) ]);

    check("unknown codepoint fails",
        "\u2318",
        .[],
        expect_success = false);

    print("\nRunning assembler tests\n");
    print("=======================\n");

    check_asm("empty input", "", .[]);
    check_asm("whitespace only", "   ", .[]);

    check_asm("single integer push",
        "5",
        .[ aw_push(5) ]);

    check_asm("single float push",
        "3.14",
        .[ aw_push(3.14) ]);

    check_asm("zero push",
        "0",
        .[ aw_push(0) ]);

    check_asm("single ascii primitive",
        "+",
        .[ aw_prim(CODEPOINT_ADD) ]);

    check_asm("single unicode primitive (multiply)",
        "\u00d7",
        .[ aw_prim(CODEPOINT_MUL) ]);

    check_asm("single unicode primitive (divide)",
        "\u00f7",
        .[ aw_prim(CODEPOINT_DIV) ]);

    check_asm("single unicode primitive (iota)",
        "\u21e1",
        .[ aw_prim(CODEPOINT_IOTA) ]);

    check_asm("single unicode primitive (first)",
        "\u2283",
        .[ aw_prim(CODEPOINT_FIRST) ]);

    check_asm("two numbers",
        "1 2",
        .[ aw_push(1), aw_push(2) ]);

    check_asm("number then primitive",
        "2 +",
        .[ aw_push(2), aw_prim(CODEPOINT_ADD) ]);

    check_asm("primitive then number",
        "+ 2",
        .[ aw_prim(CODEPOINT_ADD), aw_push(2) ]);

    check_asm("add two numbers",
        "1 + 2",
        .[ aw_push(1), aw_prim(CODEPOINT_ADD), aw_push(2) ]);

    check_asm("two primitives in sequence",
        "+ \u00d7",
        .[ aw_prim(CODEPOINT_ADD), aw_prim(CODEPOINT_MUL) ]);

    check_asm("reduce add",
        "/+",
        .[ aw_mod(CODEPOINT_REDUCE, CODEPOINT_ADD) ]);

    check_asm("reduce multiply",
        "/\u00d7",
        .[ aw_mod(CODEPOINT_REDUCE, CODEPOINT_MUL) ]);

    check_asm("reduce add applied to range",
        "/+\u21e15",
        .[ aw_mod(CODEPOINT_REDUCE, CODEPOINT_ADD), aw_prim(CODEPOINT_IOTA), aw_push(5) ]);

    check_asm("number before modifier",
        "10 /+",
        .[ aw_push(10), aw_mod(CODEPOINT_REDUCE, CODEPOINT_ADD) ]);

    check_asm("float then primitive then int",
        "1.5 + 2",
        .[ aw_push(1.5), aw_prim(CODEPOINT_ADD), aw_push(2) ]);

    print("=======================\n");
    print("%/% passed", total_tests - failed_tests, total_tests);
    if failed_tests > 0 {
        print(" (% failed)\n", failed_tests);
        exit(1);
    } else {
        print("\n");
    }
}

#import "POSIX";
