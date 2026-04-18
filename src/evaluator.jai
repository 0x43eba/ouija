ValueKind :: enum {
    NUMBER;
    ARRAY;
    FUNCTION;
    INTERNAL;
}

InternalInstruction :: enum {
    SHOW_STACK;
}

Value :: struct {
    kind: ValueKind;
    using payload: union {
        number: float64;
        array: [..]float64;
        function: *Word;
        internal_instruction: InternalInstruction;
    }
    is_error: bool;
    error: string;
}

apply_primitive :: (codepoint: u32, a: Value, b: Value) -> Value, bool {
    result: Value;
    result.kind = .NUMBER;
    if codepoint == {
        case CODEPOINT_ADD;
            result.number = a.number + b.number;
        case CODEPOINT_SUB;
            result.number = a.number - b.number;
        case CODEPOINT_MUL;
            result.number = a.number * b.number;
        case CODEPOINT_DIV;
            result.number = a.number / b.number;
        case CODEPOINT_STAR;
            result.internal_instruction = .SHOW_STACK
        case;
            return result, false;
    }
    return result, true;
}

pop :: (stack: *[..] Value) -> Value, bool {
    if stack.count == 0 return .{}, false;
    v := (stack.*)[stack.count - 1];
    stack.count -= 1;
    return v, true;
}

evaluate :: (words: *[] Word, stack: *[..] Value) -> Value, bool {
    cursor := words.count - 1;
    while true {
        word := (words.*)[cursor];
        if word.kind == {
            case .PUSH;
                v: Value;
                v.kind = .NUMBER;
                v.number = word.value;
                array_add(stack, v);
            case .PRIMITIVE;
                b, ok1 := pop(stack);
                a, ok2 := pop(stack);
                if !(ok1 && ok2) {
                    v: Value;
                    v.is_error = true;
                    v.error = "Illegal operation. Not enough values on stack.";
                    return v, false;
                }
                result, ok := apply_primitive(word.glyph, a, b);
                if result.kind == .INTERNAL {
                    ok3 := dispatch_internal(words, stack);
                    if !ok {
                        return v, false;
                    }
                }
                if !ok {
                    result.is_error = true;
                    result.error = "Unknown primitive applied";
                    return result, false;
                }
                array_add(stack, result);
            case .MODIFIED;
                arr, ok := pop(stack);
                v: Value;
                if !ok {
                    v.is_error = true;
                    v.error = "Illegal operation. Not enough values on the stack";
                    return v, false;
                }
                if arr.kind != .ARRAY {
                        v: Value;
                        v.is_error = true;
                        v.error = "Modifier expected array on stack.";
                        return v, false;
                    }
                accumulator := arr.array[0];
                for i: 1..arr.array.count - 1 {
                    a: Value;
                    a.kind = .NUMBER;
                    a.number = accumulator;
                    b: Value;
                    b.kind = .NUMBER;
                    b.number = arr.array[i];
                    result, rok := apply_primitive(word.modified.operand.glyph, a, b);
                    if !rok {
                        result.is_error = true;
                        result.error = "Unknown primitive in modifier.";
                        return result, false;
                    }
                    accumulator = result.number;
                }
                v.kind = .NUMBER;
                v.number = accumulator;
                array_add(stack, v);
        }
        if cursor == 0 break;
        cursor -= 1;
    }
    if stack.count > 0 return (stack.*)[stack.count - 1], true;
    v: Value;
    v.is_error = true;
    v.error = "Stack empty after evaluation.";
    return v, false;
}
