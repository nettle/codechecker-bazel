# cc_binary for simple test_main
load(
    "@rules_cc//cc:defs.bzl",
    "cc_binary",
    "cc_library",
)

# Load codechecker rules
load(
    "@codechecker-bazel//codechecker:codechecker.bzl",
    "codechecker_suite",
    "codechecker_test",
)

# Simplest C++ test
cc_binary(
    name = "hello_world",
    srcs = ["hello_world.cc"],
)

# Use codechecker_test rule to check "hello_world" code
codechecker_test(
    name = "hello_world_codechecker",
    targets = [
        "hello_world",
    ],
)
