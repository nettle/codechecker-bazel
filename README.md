Bazel CodeChecker
=================

Bazel rules for CodeChecker and other tools for Code Analysis,
including Clang-tidy, Clang analyzer, generating compilation database
(`compile_commands.json`) and others.

> If you would like to report an issue or suggest a change
> please read [CONTRIBUTING.md](CONTRIBUTING.md).

### CodeChecker

CodeChecker rule `codechecker_test()` to run `CodeChecker` tool as a Bazel test.

Read about CodeChecker:

* GitHub: https://github.com/Ericsson/codechecker
* Read the Docs: https://codechecker.readthedocs.io/

Bazel rule for CodeChecker `codechecker_test()` uses
Bazel rule for compilation database (compile_commands.json) `compile_commands()`


### Clang-tidy

Bazel aspect `clang_tidy_aspect` and rule `clang_tidy_test()`
to run `clang-tidy` "linter" tool from Bazel command line or Bazel test.

Find more information about LLVM clang-tidy:

* LLVM: https://clang.llvm.org/extra/clang-tidy
* bazel_clang_tidy: https://github.com/erenon/bazel_clang_tidy


### Clang Static Analyzer

Bazel rule `clang_analyze_test()` runs Clang Static Analyzer (or `clang --analyze`),
the most (and the only?) sophisticated tool for C/C++ code analysis which implements
path-sensitive, inter-procedural analysis based on symbolic execution technique.

Find more information about LLVM Clang Static Analyzer:

* LLVM: https://clang.llvm.org/docs/ClangStaticAnalyzer.html


Prerequisites
-------------

We need the following tools:

- Git 2 or newer (we use 2.36)
- Bazel 4 or newer (we recommend version 6)
- Clang 16 or newer (we use 16), we use clang-tidy
- Python 3.8 or newer (we use 3.11)
- CodeChecker 6.23 or newer (we use 6.23.0)

If, by chance, Environment Modules (https://modules.sourceforge.net/)
are available in your system, you can just add the following modules:

    module add git
    module add bazel/6
    module add clang/16
    module add python/3.11
    module add codechecker/6.23


How to use
----------

To use `codechecker_test()` rule you should include it to your BUILD file:

```python
load(
    "@bazel_codechecker//src:codechecker.bzl",
    "codechecker_test",
)
```

Then use `codechecker_test()` rule passing targets you call CodeChecker for:

```python
codechecker_test(
    name = "your_codechecker_rule_name",
    targets = [
        "your_target",
    ],
)
```

Note that `compile_commands()` rule can be used independently:

```python
load(
    "@bazel_codechecker//src:compile_commands.bzl",
    "compile_commands",
)
```

Then use `compile_commands()` rule passing build targets:

```python
compile_commands(
    name = "your_compile_commands_rule_name",
    targets = [
        "your_target",
    ],
)
```


Examples
--------

In [test/BUILD](test/BUILD) you can find examples for `codechecker_test()`
and for `compile_commands()` rules.

For instance see `codechecker_pass` and `compile_commands_pass`.

Run all test Bazel targets:

    bazel test ...

After that you can find all artifacts in `bazel-bin` directory:

    # All codechecker_pass artifacts
    ls bazel-bin/test/codechecker_pass/
    
    # compile_commands.json for compile_commands_pass
    cat bazel-bin/test/compile_commands_pass/compile_commands.json

To run `clang_tidy_aspect` on all C/C++ code:

    bazel build ... --aspects @bazel_codechecker//src:clang.bzl%clang_tidy_aspect --output_groups=report
