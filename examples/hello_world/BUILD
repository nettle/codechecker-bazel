# cc_binary for simple test_main
load(
    "@rules_cc//cc:defs.bzl",
    "cc_binary",
    "cc_library",
)

# codechecker rules
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

# Simple codechecker rule - performs only "build" phase without "test"
# which verifies results and sends results to online database
codechecker_test(
    name = "hello_world_codechecker",
    targets = [
        "hello_world",
    ],
)
