Bazel rules for CodeChecker
===========================

`codechecker_test` and `codechecker_suite` rules to run CodeChecker as Bazel test.

> NOTE: Alpha version! Supports only Linux with a number of limitations

What is Bazel?
--------------

Bazel is a build system developed by Google,
see https://bazel.build/


What is CodeChecker?
--------------------

CodeChecker is a static analysis framework for C and C++ code developed by Ericsson,
see https://github.com/Ericsson/codechecker, and https://codechecker.readthedocs.io/
CodeChecker is based on LLVM/Clang static analyzer,
see https://clang-analyzer.llvm.org/


How to use?
-----------

1. Add codechecker-bazel to WORKSPACE

WORKSPACE:
```py
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "codechecker-bazel",
    strip_prefix = "codechecker-bazel-main",
    urls = ["https://github.com/nettle/codechecker-bazel/archive/main.tar.gz"],
)
```

2. Load codechecker rules to BUILD

BUILD:
```py
# codechecker rules
load(
    "@codechecker-bazel//codechecker:codechecker.bzl",
    "codechecker_suite",
    "codechecker_test",
)
```

3. Add codechecker rules for your targets

BUILD:
```py
codechecker_test(
    name = "hello_world_codechecker",
    targets = [
        "hello_world",
    ],
)
```

See [examples](examples)


How to test?
------------

Just run:

    bazel test ...


Known Issues
------------

* Windows is not supported yet
* MacOS is not supported yet
* Checkers configuration is not supported yet


TODO
----

[ ] Move CodeChecker analyze to Bazel test stage
[ ] Checkers configuration
[ ] Bazel version compatibility
[ ] CodeChecker version compatibility
[ ] Windows + VS support
[ ] MacOS + Xcode support
