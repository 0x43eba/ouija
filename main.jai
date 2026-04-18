#import "POSIX";
#load "src/tokenizer.jai";
#load "src/assembler.jai";

main :: () {
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
        evaluated, evaluated_ok := evaluate(buffer.data, n);
        words, assembled_ok := assemble(evaluated);
        if !(evaluated_ok || assembled_ok) {
            print_tokens(evaluated);
            print_words(words);
            print("Failed. Oops");
        }
        print("\n");
        print_tokens(evaluated);
        print_words(words);
        print("\n");
    }
}
