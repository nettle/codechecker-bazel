""" transitive_sources_aspect

collects all dependent source and header files
"""

TransitiveSourcesInfo = provider(
    doc = "All transitive source and header files",
    fields = {
        "source_files": "list of transitive source files of a target",
        "headers": "list of required header files",
    },
)

_source_attr = [
    "srcs",
    "deps",
    "data",
    "exports",
]

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
                if TransitiveSourcesInfo in dep:
                    src = dep[TransitiveSourcesInfo].headers
                    headers.append(src)
            headers = depset(transitive = headers)
    return headers

def _accumulate_transitive_source_files(accumulated, deps):
    sources = [accumulated]
    for dep in deps:
        if TransitiveSourcesInfo in dep:
            src = dep[TransitiveSourcesInfo].source_files
            sources.append(src)
    return depset(transitive = sources)

def _transitive_sources_aspect_impl(target, ctx):
    source_files = get_sources(ctx)
    source_files = depset(source_files)

    for attr in _source_attr:
        if hasattr(ctx.rule.attr, attr):
            source_files = _accumulate_transitive_source_files(
                source_files,
                getattr(ctx.rule.attr, attr),
            )

    return [
        TransitiveSourcesInfo(
            source_files = source_files,
            headers = collect_headers(target, ctx),
        ),
    ]

transitive_sources_aspect = aspect(
    implementation = _transitive_sources_aspect_impl,
    attr_aspects = _source_attr,
    required_aspect_providers = [TransitiveSourcesInfo],
)
