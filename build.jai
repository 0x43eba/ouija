#import "Basic";
#import "Compiler";

build :: () {
    build_one("OUIJA", "main.jai", "ouija");
    build_one("OUIJA_TESTS", "tests/tests.jai", "ouija_tests");
    set_build_options_dc(.{do_output=false});
}

build_one :: (workspace_name: string, source: string, exe: string) {
    w := compiler_create_workspace(workspace_name);
    if !w {
        print("Workspace creation failed for %.\n", workspace_name);
        return;
    }
    options := get_build_options(w);
    options.output_executable_name = exe;
    options.output_path = "build/";
    options.intermediate_path = "build/";
    set_build_options(options, w);
    add_build_file(source, w);
}

#run build();
