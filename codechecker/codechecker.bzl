""" Bazel test rules for CodeChecker """

load(
    ":compile_commands.bzl",
    "SourceFilesInfo",
    "compile_commands_aspect",
)

def _platforms_transition_impl(settings, attr):
    if attr.config not in ["", "host", "target"]:
        fail("Unknown ploatform/config: %s" % attr.config)
    else:
        platforms = settings["//command_line_option:platforms"]
    return {
        "//command_line_option:platforms": platforms,
    }

platforms_transition = transition(
    implementation = _platforms_transition_impl,
    inputs = [
        "//command_line_option:platforms",
    ],
    outputs = [
        "//command_line_option:platforms",
    ],
)

CodeCheckerStoreInfo = provider(
    doc = "Describe CodeChecker online database parameters for store command",
    fields = {
        "url": "Online database URL + product name",
        "valid_users": "List of users who have a right to store",
    },
)

def _codechecker_online_database_impl(ctx):
    return [
        CodeCheckerStoreInfo(
            url = ctx.attr.url,
            valid_users = ctx.attr.valid_users,
        ),
    ]

codechecker_online_database = rule(
    implementation = _codechecker_online_database_impl,
    attrs = {
        "url": attr.string(
            default = "",
            doc = "CodeChecker online database URL to store results",
        ),
        "valid_users": attr.string_list(
            default = [],
            doc = "List of valid users of CodeChecker online database to store results",
        ),
    },
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

    # Check that we collect all required source files
    _check_source_files(source_files, compilation_db)

    # Generate compile_commands.json from compilation database info
    json = _compile_commands_json(compilation_db)

    # Save as initial compile_commands.json file
    initial_compile_commands = ctx.actions.declare_file("initial." + ctx.outputs.compile_commands.short_path)
    ctx.actions.write(
        output = initial_compile_commands,
        content = json,
        is_executable = False,
    )

    # Now convert flacc calls to clang
    ctx.actions.run(
        inputs = [initial_compile_commands],
        outputs = [ctx.outputs.compile_commands],
        executable = ctx.executable._compile_commands_filter,
        arguments = [
            # "-v",  # -vv for debug
            "--input=" + initial_compile_commands.path,
            "--output=" + ctx.outputs.compile_commands.path,
        ],
        progress_message = "Filtering %s" % str(ctx.label),
        use_default_shell_env = True,  # NOTE: workaround to find python3 in the PATH
    )

    # Create CodeChecker skip (ignore) file
    ctx.actions.write(
        output = ctx.outputs.codechecker_skipfile,
        content = "\n".join(ctx.attr.skip),
        is_executable = False,
    )

    # List all files required at build and run (test) time
    all_files = [
        ctx.outputs.compile_commands,
        ctx.outputs.codechecker_skipfile,
    ] + source_files + headers

    # Pass headers as transitive files
    transitive_files = depset(source_files + headers)

    # Return all files
    return [
        DefaultInfo(
            files = depset(all_files),
            runfiles = ctx.runfiles(
                files = all_files,
                transitive_files = transitive_files,
            ),
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
        "_compile_commands_filter": attr.label(
            allow_files = True,
            executable = True,
            cfg = "host",
            default = ":compile_commands_filter",
        ),
    },
    outputs = {
        "compile_commands": "%{name}.compile_commands.json",
        "codechecker_skipfile": "%{name}.codechecker_skipfile.cfg",
    },
)

def _codechecker_test_impl(ctx):
    # Run CodeChecker at build step
    info = _codechecker_impl(ctx)

    # # Create empty log file for CodeChecker
    # ctx.actions.write(
    #     output = ctx.outputs.codechecker_log,
    #     content = "",
    #     is_executable = False,
    # )

    # Create empty folder for CodeChecker data files
    ctx.actions.run_shell(
        outputs = [ctx.outputs.codechecker_files],
        command = "mkdir " + ctx.outputs.codechecker_files.path,
    )
    # codechecker_files = ctx.actions.declare_directory(ctx.attr.name + ".codechecker-files")
    # ctx.actions.run_shell(
    #     outputs = [codechecker_files],
    #     command = "mkdir -p " + codechecker_files.path,
    # )

    # Get CodeChecker online database parameters
    if ctx.attr.online_database:
        store_url = ctx.attr.online_database[CodeCheckerStoreInfo].url
        store_users = ctx.attr.online_database[CodeCheckerStoreInfo].valid_users
    else:
        store_url = ""
        store_users = []
    store_name = ctx.attr.run_name
    store_tag = ctx.attr.run_tag

    # Create test script from template
    ctx.actions.expand_template(
        template = ctx.file._codechecker_script_template,
        output = ctx.outputs.codechecker_test_script,
        is_executable = True,
        substitutions = {
            "{Mode}": "Full",  # "Test" "Run"
            "{Verbosity}": "DEBUG",  # "INFO"
            "{codecheckerPATH}": "CodeChecker",
            "{compile_commands}": ctx.outputs.compile_commands.short_path,
            "{codechecker_skipfile}": ctx.outputs.codechecker_skipfile.short_path,
            # "{codechecker_log}": ctx.outputs.codechecker_log.short_path,
            # "{codechecker_log}": ctx.outputs.codechecker_files.short_path + "/codechecker.log",
            "{codechecker_files}": ctx.outputs.codechecker_files.short_path,
            # "{codechecker_files}": codechecker_files.short_path,
            "{Severities}": " ".join(ctx.attr.severities),
            "{store_url}": store_url,
            "{store_users}": " ".join(store_users),
            "{store_name}": store_name,
            "{store_tag}": store_tag,
        },
    )

    # Return test script and all required files
    all_files = info[0].files.to_list()
    run_files = info[0].default_runfiles.files.to_list() + [
        ctx.outputs.codechecker_test_script,
        ctx.outputs.codechecker_files,
        # ctx.outputs.codechecker_log,
        # codechecker_files,
    ]
    return [
        DefaultInfo(
            files = depset(all_files),
            runfiles = ctx.runfiles(files = run_files),
            executable = ctx.outputs.codechecker_test_script,
        ),
    ]

codechecker_test = rule(
    implementation = _codechecker_test_impl,
    attrs = {
        "config": attr.string(
            default = "host",
            doc = "Configuration",
        ),
        "targets": attr.label_list(
            aspects = [
                compile_commands_aspect,
            ],
            cfg = platforms_transition,
            doc = "List of compilable targets which should be checked.",
        ),
        "_whitelist_function_transition": attr.label(
            default = "@bazel_tools//tools/whitelists/function_transition_whitelist",
            doc = "needed for transitions",
        ),
        "_compile_commands_filter": attr.label(
            allow_files = True,
            executable = True,
            cfg = "host",
            default = ":compile_commands_filter",
        ),
        "_codechecker_script_template": attr.label(
            default = ":codechecker_script.py",
            allow_single_file = True,
        ),
        "severities": attr.string_list(
            default = ["HIGH"],
            doc = "List of defect severities: HIGH, MEDIUM, LOW, STYLE etc",
        ),
        "skip": attr.string_list(
            default = [],
            doc = "List of skip/ignore file rules. " +
                  "See https://codechecker.readthedocs.io/en/latest/analyzer/user_guide/#skip-file",
        ),
        "online_database": attr.label(
            default = None,
            doc = "Parameters for CodeChecker store",
        ),
        "run_name": attr.string(
            default = "",
            doc = "Run name to store results to CodeChecker online database",
        ),
        "run_tag": attr.string(
            default = "%TIMESTAMP%",
            doc = "Tag to store results to CodeChecker online database",
        ),
    },
    outputs = {
        "codechecker_files": "%{name}.codechecker-files",
        "compile_commands": "%{name}.compile_commands.json",
        "codechecker_skipfile": "%{name}.codechecker_skipfile.cfg",
        # "codechecker_log": "%{name}.codechecker.log",
        "codechecker_test_script": "%{name}.codechecker_test_script.py",
    },
    test = True,
)

def codechecker_suite(
        name,
        targets,
        configs = ["host"],
        severities = ["HIGH"],
        skip = [],
        tags = [],
        **kwargs):
    """ Bazel test suite to run CodeChecker for different configs """
    tests = []
    for cfg in configs:
        test_name = name + "." + cfg
        tests.append(test_name)
        codechecker_test(
            name = test_name,
            config = cfg,
            targets = targets,
            severities = severities,
            skip = skip,
            tags = tags,
        )
    native.test_suite(
        name = name,
        tests = tests,
        tags = tags,
        **kwargs
    )
