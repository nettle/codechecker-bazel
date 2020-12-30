"""
TODO:
[ ] absolute path in directory
[ ] log file?
[ ] path to CodeChecker
[ ] local defines in aspects.bzl
[ ] compile_commands.json postprocessing
[ ] _check_source_files?
[ ] rename to aspects.bzl?
"""

load(
    ":compilation_database.bzl",
    "CompilationAspect",
    "compilation_database_aspect",
)

load(
    ":transitive_sources.bzl",
    "transitive_sources_aspect",
    "TransitiveSourcesInfo",
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
    # source_files = []
    # compilation_db = []
    # headers = []
    # for target in ctx.attr.targets:
    #     src = target[OutputGroupInfo].compdb_files
    #     source_files += src.to_list()
    #     cdb = target[CompilationAspect].compilation_db
    #     compilation_db += cdb.to_list()
    #     hdr = target[OutputGroupInfo].header_files
    #     headers += hdr.to_list()

    source_files = []
    compilation_db = []
    headers = []
    for target in ctx.attr.targets:
        source_files.append(target[TransitiveSourcesInfo].source_files)
        # source_files.append(target[OutputGroupInfo].compdb_files)
        # compilation_db.append(target[CompilationAspect].compilation_db)
        # headers.append(target[OutputGroupInfo].header_files)

    source_files = depset(transitive = source_files)
    compilation_db = depset(transitive = compilation_db)
    headers = depset(transitive = headers)

    source_files = source_files.to_list()
    compilation_db = compilation_db.to_list()
    headers = headers.to_list()

    # Check that compilation database is not empty
    if not len(compilation_db):
        fail("Compilation database is empty!")

    # Check that we collect all required source files
    #_check_source_files(source_files, compilation_db)
    print(">>> source_files=%s" % str(source_files))
    print(">>> headers=%s" % str(headers))
    print(">>> compilation_db=%s" % str(compilation_db))

    # Generate compile_commands.json from compilation database info
    json = _compile_commands_json(compilation_db)
    # json = json.replace("__EXEC_ROOT__", "/home/ezkraal/.cache/bazel/_bazel_ezkraal/348e8dd3460626e2b00e2c97f4a69383/execroot/__main__")  # "/repo/ezkraal/codechecker/bazel")

    # Save compile_commands.json file
    ctx.actions.write(
        output = ctx.outputs.compile_commands,
        content = json,
        is_executable = False,
    )

    # # Save as initial compile_commands.json file
    # initial_compile_commands = ctx.actions.declare_file("initial." + ctx.outputs.compile_commands.short_path)
    # ctx.actions.write(
    #     output = initial_compile_commands,
    #     content = json,
    #     is_executable = False,
    # )
    # # Now convert flacc calls to clang
    # ctx.actions.run(
    #     inputs = [initial_compile_commands],
    #     outputs = [ctx.outputs.compile_commands],
    #     executable = ctx.executable._compile_commands_filter,
    #     arguments = [
    #         # "-v",  # -vv for debug
    #         "--input=" + initial_compile_commands.path,
    #         "--output=" + ctx.outputs.compile_commands.path,
    #     ],
    #     progress_message = "Filtering %s" % str(ctx.label),
    # )

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

_compile_commands = rule(
    implementation = _compile_commands_impl,
    attrs = {
        "targets": attr.label_list(
            aspects = [
                transitive_sources_aspect,
                # compilation_database_aspect,
            ],
            doc = "List of compilable targets which should be checked.",
        ),
    },
    outputs = {
        "compile_commands": "compile_commands.json",
    },
)

def _codechecker_test_impl(ctx):
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

    # Create log file
    ctx.actions.write(
        output = ctx.outputs.codechecker_log,
        content = "",
        is_executable = False,
    )

    # Create folder for CodeChecker data
    ctx.actions.run_shell(
        outputs = [ctx.outputs.codechecker_files],
        command = "mkdir {}".format(ctx.outputs.codechecker_files.path),
    )

    ctx.actions.expand_template(
        template = ctx.file._codechecker_script_template,
        output = ctx.outputs.codechecker_script,
        is_executable = True,
        substitutions = {
            "{Verbosity}": "DEBUG",
            "{codecheckerPATH}": "CodeChecker",
            "{compile_commands}": ctx.outputs.compile_commands.short_path,
            "{codechecker_skipfile}": ctx.outputs.codechecker_skipfile.short_path,
            "{codechecker_files}": ctx.outputs.codechecker_files.short_path,
            # "{codechecker_log}": ctx.outputs.codechecker_log.short_path,
            # "{codechecker_severities}": " ".join(ctx.attr.severities),
        },
    )

    # List all files required at build and run (test) time
    # all_files.append(ctx.outputs.codechecker_skipfile)
    all_files = all_files + run_files + [
        ctx.outputs.codechecker_skipfile,
        ctx.outputs.codechecker_script,
        ctx.outputs.codechecker_files,
        ctx.outputs.codechecker_log,
    ]

    # List files required for test
    run_files = all_files + [
    ]
    print(">>> run_files=%s" % str(run_files))

    # Return all files
    return [
        DefaultInfo(
            files = depset(all_files),
            runfiles = ctx.runfiles(files = run_files),
            executable = ctx.outputs.codechecker_script,  # ctx.outputs.codechecker_test_script,
        ),
    ]

codechecker_test = rule(
    implementation = _codechecker_test_impl,
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
        "_codechecker_script_template": attr.label(
            default = ":codechecker_script.py",
            allow_single_file = True,
        ),
    },
    outputs = {
        "codechecker_files": "%{name}.codechecker-files",
        "compile_commands": "compile_commands.json",
        "codechecker_skipfile": "%{name}.codechecker_skipfile.cfg",
        "codechecker_script": "%{name}.codechecker_script.py",
        "codechecker_log": "%{name}.codechecker.log",
    },
    test = True,
)
