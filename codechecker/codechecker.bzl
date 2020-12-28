load(
    ":compilation_database.bzl",
    "CompilationAspect",
    "compilation_database_aspect",
)

def _check_source_files(source_files, compilation_db):
    available_sources = [src.path for src in source_files]
    checking_sources = [item.file for item in compilation_db]

    for src in checking_sources:
        if src not in available_sources:
            fail("File: %s\nNot available in collected source files" % src)

def _compile_commands_json(compilation_db):
    json = "[\n"
    entries = [entry.to_json() for entry in compilation_db]
    json += ",\n".join(entries)
    json += "]\n"
    return json

def _compile_commands_impl(ctx):
    source_files = []
    compilation_db = []
    headers = []
    for target in ctx.attr.targets:
        src = target[OutputGroupInfo].compdb_files
        source_files += src.to_list()
        cdb = target[CompilationAspect].compilation_db
        compilation_db += cdb.to_list()
        hdr = target[OutputGroupInfo].header_files
        headers += hdr.to_list()

    # Check that compilation database is not empty
    if not len(compilation_db):
        fail("Compilation database is empty!")

    # Check that we collect all required source files
    #_check_source_files(source_files, compilation_db)

    # Generate compile_commands.json from compilation database info
    json = _compile_commands_json(compilation_db)

    # Save compile_commands.json file
    ctx.actions.write(
        output = ctx.outputs.compile_commands,
        content = json,
        is_executable = False,
    )

    # List all files required at build and run (test) time
    all_files = [
        ctx.outputs.compile_commands,
    ] + source_files + headers

    # List files required for test
    run_files = all_files

    # Return all files
    return [
        DefaultInfo(
            files = depset(all_files),
            runfiles = ctx.runfiles(files = run_files),
        ),
    ]

compile_commands = rule(
    implementation = _compile_commands_impl,
    attrs = {
        "targets": attr.label_list(
            aspects = [
                compilation_database_aspect,
            ],
            doc = "List of compilable targets which should be checked.",
        ),
    },
    outputs = {
        "compile_commands": "%{name}.compile_commands.json",
    },
)

def _codechecker_impl(ctx):
    # Create compile_commands.json
    info = _compile_commands_impl(ctx)
    all_files = info[0].files.to_list()
    run_files = info[0].default_runfiles.files.to_list()

    # Create CodeChecker skip (ignore) file
    ctx.actions.write(
        output = ctx.outputs.codechecker_skipfile,
        content = "\n".join(ctx.attr.skip),
        is_executable = False,
    )

    # List all files required at build and run (test) time
    # all_files.append(ctx.outputs.codechecker_skipfile)
    all_files = all_files + [
        ctx.outputs.codechecker_skipfile,
        # ctx.outputs.codechecker_files,
        # ctx.outputs.codechecker_script,
        # ctx.outputs.codechecker_log,
    ]

    # List files required for test
    run_files = all_files

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
                compilation_database_aspect,
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
        "compile_commands": "%{name}.compile_commands.json",
        "codechecker_skipfile": "%{name}.codechecker_skipfile.cfg",
        # "codechecker_script": "%{name}.codechecker_script.py",
        # "codechecker_log": "%{name}.codechecker.log",
    },
)
