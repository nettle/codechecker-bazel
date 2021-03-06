Bazel rules for CodeChecker
===========================

`codechecker_test` and `codechecker_suite` rules to run CodeChecker as Bazel test.

> NOTE: This is Alpha version! Works for Linux only with a number of limitations


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

**WORKSPACE:**
```py
# We need http_archive
load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)

# Fetch codechecker-bazel
http_archive(
    name = "codechecker-bazel",
    strip_prefix = "codechecker-bazel-main",
    urls = ["https://github.com/nettle/codechecker-bazel/archive/main.tar.gz"],
)
```

2. Load codechecker rules to BUILD

**BUILD:**
```py
# Load codechecker rules
load(
    "@codechecker-bazel//codechecker:codechecker.bzl",
    "codechecker_suite",
    "codechecker_test",
)
```

3. Add codechecker rules for your targets

**BUILD:**
```py
# Use codechecker_test rule to check "hello_world"
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

add option `--test_output=all` to see CodeChecker parse output:

    bazel test ... --test_output=all

Known Issues
------------

* Checkers configuration is not supported yet
* Windows is not supported by CodeChecker


TODO
----

- [ ] Checkers configuration
- [ ] Paths to clang and CodeChecker
- [ ] Move CodeChecker analyze to Bazel test stage?
- [ ] Bazel version compatibility
- [ ] CodeChecker version compatibility
- [ ] MacOS + Xcode support
