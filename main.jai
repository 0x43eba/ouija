#import "POSIX";
#load "src/tokenizer.jai";
#load "src/assembler.jai";
#load "src/evaluator.jai";

main :: () {
    stack: [..] Value;
    buffer: [1024] u8;
    while true {
        print(">>> ");
        n := read(STDIN_FILENO, buffer.data, cast(u64) buffer.count);
        if n <= 0 break;
        while n > 0 && (buffer[n-1] == #char "\n" || buffer[n-1] == #char "\r") {
            n -= 1;
        }
        print("raw bytes (% total):", n);
        for 0..n-1 print(" %", formatInt(buffer[it], base=16, minimum_digits=2));
        print("\n");

        tokens, parse_ok := parse(buffer.data, n);
        if !parse_ok {
            print("Tokenize failed.\n");
            print_tokens(tokens);
            array_free(tokens);
            continue;
        }

        words, assembled_ok := assemble(tokens);
        array_free(tokens);
        if !assembled_ok {
            print("Assemble failed.\n");
            print_words(words);
            array_free(words);
            continue;
        }
        result, eval_ok := evaluate(*words, *stack);
        array_free(words);
        array_free(stack);

        if !eval_ok {
            print("Eval failed: %\n", result.error);
            continue;
        }

        print("=> %\n\n", result.number);
    }
}
