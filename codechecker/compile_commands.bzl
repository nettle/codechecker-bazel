""" compile_commands_aspect

compile_commands_aspect - collects all dependent source files
and compile-time information to create compilation database
ready to be presented as compile_commands.json file.

Implementation is based on two sources:

* compilation_database_aspect - taken from GitHub
  https://github.com/grailbio/bazel-compilation-database
* collect_source_files_aspect - simple solution taken from
  https://stackoverflow.com/questions/50083635/bazel-how-to-get-all-transitive-sources-of-a-target
"""

load(
    "@bazel_tools//tools/cpp:toolchain_utils.bzl",
    "find_cpp_toolchain",
)
load(
    "@bazel_tools//tools/build_defs/cc:action_names.bzl",
    "CPP_COMPILE_ACTION_NAME",
    "C_COMPILE_ACTION_NAME",
)

SourceFilesInfo = provider(
    doc = "Source files and corresponding compilation database (or compile commands)",
    fields = {
        "transitive_source_files": "list of transitive source files of a target",
        "compilation_db": "list of compile commands with parameters: file, command, directory",
        "headers": "list of required header files",
    },
)

_source_attr = [
    "srcs",
    "deps",
    "data",
    "exports",
]

_cpp_extensions = [
    "cc",
    "cpp",
    "cxx",
]

_c_extensions = [
    "c",
]

_c_and_cpp_extensions = _c_extensions + _cpp_extensions

_cc_rules = [
    "cc_library",
    "cc_binary",
    "cc_test",
    "cc_inc_library",
    "cc_proto_library",
]

# Function copied from https://gist.github.com/oquenchil/7e2c2bd761aa1341b458cc25608da50c
# NOTE: added local_defines
def get_compile_flags(dep):
    """ Return a list of compile options

    Returns:
      List of compile options.
    """
    options = []
    compilation_context = dep[CcInfo].compilation_context

    for define in compilation_context.defines.to_list():
        options.append("-D{}".format(define))

    for define in compilation_context.local_defines.to_list():
        options.append("-D{}".format(define))

    for system_include in compilation_context.system_includes.to_list():
        if len(system_include) == 0:
            system_include = "."
        options.append("-isystem {}".format(system_include))

    for include in compilation_context.includes.to_list():
        if len(include) == 0:
            include = "."
        options.append("-I {}".format(include))

    for quote_include in compilation_context.quote_includes.to_list():
        if len(quote_include) == 0:
            quote_include = "."
        options.append("-iquote {}".format(quote_include))

    return options

def get_sources(ctx):
    """ Return a list of source files

    Returns:
      List of source files.
    """
    srcs = []
    if "srcs" in dir(ctx.rule.attr):
        for src in ctx.rule.attr.srcs:
            if CcInfo not in src:
                srcs += src.files.to_list()
    if "hdrs" in dir(ctx.rule.attr):
        for src in ctx.rule.attr.hdrs:
            srcs += src.files.to_list()
    return srcs

def _is_cpp_target(srcs):
    return any([src.extension in _cpp_extensions for src in srcs])

# Function copied from https://github.com/grailbio/bazel-compilation-database/blob/master/aspects.bzl
def _cc_compiler_info(ctx, target, srcs, feature_configuration, cc_toolchain):
    compile_variables = None
    compiler_options = None
    compiler = None
    compile_flags = None
    force_language_mode_option = ""

    # This is useful for compiling .h headers as C++ code.
    if _is_cpp_target(srcs):
        compile_variables = cc_common.create_compile_variables(
            feature_configuration = feature_configuration,
            cc_toolchain = cc_toolchain,
            user_compile_flags = ctx.fragments.cpp.cxxopts +
                                 ctx.fragments.cpp.copts,
            add_legacy_cxx_options = True,
        )
        compiler_options = cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = CPP_COMPILE_ACTION_NAME,
            variables = compile_variables,
        )
        force_language_mode_option = " -x c++"
    else:
        compile_variables = cc_common.create_compile_variables(
            feature_configuration = feature_configuration,
            cc_toolchain = cc_toolchain,
            user_compile_flags = ctx.fragments.cpp.copts,
        )
        compiler_options = cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = C_COMPILE_ACTION_NAME,
            variables = compile_variables,
        )

    compiler = str(
        cc_common.get_tool_for_action(
            feature_configuration = feature_configuration,
            action_name = C_COMPILE_ACTION_NAME,
        ),
    )

    compile_flags = (compiler_options +
                     get_compile_flags(target) +
                     (ctx.rule.attr.copts if "copts" in dir(ctx.rule.attr) else []))

    return struct(
        compile_variables = compile_variables,
        compiler_options = compiler_options,
        compiler = compiler,
        compile_flags = compile_flags,
        force_language_mode_option = force_language_mode_option,
    )

def get_compilation_database(target, ctx):
    """ Return a "compilation database" or "compile commands" ready to create a JSON file

    Returns:
      List of struct(file, command, directory).
    """
    if ctx.rule.kind not in _cc_rules:
        return []

    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    srcs = get_sources(ctx)

    compiler_info = _cc_compiler_info(ctx, target, srcs, feature_configuration, cc_toolchain)

    compile_flags = compiler_info.compile_flags
    compile_flags += [
        # Use -I to indicate that we want to keep the normal position in the system include chain.
        # See https://github.com/grailbio/bazel-compilation-database/issues/36#issuecomment-531971361.
        "-I " + str(d)
        for d in cc_toolchain.built_in_include_directories
    ]
    compile_command = compiler_info.compiler + " " + " ".join(compile_flags) + compiler_info.force_language_mode_option

    directory = "."
    compilation_db = []
    for src in srcs:
        if src.extension not in _c_and_cpp_extensions:
            continue
        command = compile_command + " -c " + src.path
        compilation_db.append(
            struct(
                file = src.path,
                command = command,
                directory = directory,
            ),
        )

    return compilation_db

def collect_headers(target, ctx):
    """ Return list of required header files

    Returns:
      depset of header files
    """
    if CcInfo in target:
        headers = [target[CcInfo].compilation_context.headers]
    else:
        headers = []
    headers = depset(headers)
    for attr in _source_attr:
        if hasattr(ctx.rule.attr, attr):
            deps = getattr(ctx.rule.attr, attr)
            headers = [headers]
            for dep in deps:
                if SourceFilesInfo in dep:
                    src = dep[SourceFilesInfo].headers
                    headers.append(src)
            headers = depset(transitive = headers)
    return headers

def _accumulate_transitive_source_files(accumulated, deps):
    sources = [accumulated]
    for dep in deps:
        if SourceFilesInfo in dep:
            src = dep[SourceFilesInfo].transitive_source_files
            sources.append(src)
    return depset(transitive = sources)

def _accumulate_compilation_database(accumulated, deps):
    if not len(deps):
        return accumulated
    compilation_db = [accumulated]
    for dep in deps:
        if SourceFilesInfo in dep:
            cdb = dep[SourceFilesInfo].compilation_db
            if len(cdb.to_list()):
                compilation_db.append(cdb)
    return depset(transitive = compilation_db)

def _compile_commands_aspect_impl(target, ctx):
    source_files = get_sources(ctx)
    source_files = depset(source_files)
    compilation_db = get_compilation_database(target, ctx)
    compilation_db = depset(compilation_db)

    for attr in _source_attr:
        if hasattr(ctx.rule.attr, attr):
            source_files = _accumulate_transitive_source_files(
                source_files,
                getattr(ctx.rule.attr, attr),
            )
            compilation_db = _accumulate_compilation_database(
                compilation_db,
                getattr(ctx.rule.attr, attr),
            )

    return [
        SourceFilesInfo(
            transitive_source_files = source_files,
            compilation_db = compilation_db,
            headers = collect_headers(target, ctx),
        ),
    ]

compile_commands_aspect = aspect(
    implementation = _compile_commands_aspect_impl,
    attr_aspects = _source_attr,
    attrs = {
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
    },
    fragments = ["cpp"],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)
