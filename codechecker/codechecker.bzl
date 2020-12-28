load(
    ":compile_commands.bzl",
    "SourceFilesInfo",
    "compile_commands_aspect",
)

def _codechecker_impl(ctx):
    # Collect source files and compilation database
    source_files = []
    compilation_db = []
    headers = []
    for target in ctx.attr.targets:
        src = target[SourceFilesInfo].transitive_source_files
        source_files += src.to_list()
        cdb = target[SourceFilesInfo].compilation_db
        compilation_db += cdb.to_list()
        hdr = target[SourceFilesInfo].headers
        headers += hdr.to_list()

    # Check that compilation database is not empty
    if not len(compilation_db):
        fail("Compilation database is empty!")

    # List all files required at build and run (test) time
    all_files = [
        # ctx.outputs.compile_commands,
        # ctx.outputs.codechecker_skipfile,
        # ctx.outputs.codechecker_files,
        # ctx.outputs.codechecker_script,
        # ctx.outputs.codechecker_log,
    ] + source_files

    # List files required for test
    run_files = [
        # ctx.outputs.codechecker_files,
    ] + source_files

    # Return all files
    return [
        DefaultInfo(
            files = depset(all_files),
            runfiles = ctx.runfiles(files = run_files),
        ),
    ]

codechecker = rule(
    implementation = _codechecker_impl,
    attrs = {
        "targets": attr.label_list(
            aspects = [
                compile_commands_aspect,
            ],
            doc = "List of compilable targets which should be checked.",
        ),
        "skip": attr.string_list(
            default = [],
            doc = "List of skip/ignore file rules. " +
                  "See https://codechecker.readthedocs.io/en/latest/analyzer/user_guide/#skip-file",
        ),
        # "_compile_commands_filter": attr.label(
        #     allow_files = True,
        #     executable = True,
        #     cfg = "host",
        #     default = ":compile_commands_filter",
        # ),
        # "_codechecker_script_template": attr.label(
        #     default = ":codechecker_script.py",
        #     allow_single_file = True,
        # ),
    },
    outputs = {
        # "codechecker_files": "%{name}.codechecker-files",
        # "compile_commands": "%{name}.compile_commands.json",
        # "codechecker_skipfile": "%{name}.codechecker_skipfile.cfg",
        # "codechecker_script": "%{name}.codechecker_script.py",
        # "codechecker_log": "%{name}.codechecker.log",
    },
)
