# cc_binary for simple test_main
load(
    "@rules_cc//cc:defs.bzl",
    "cc_binary",
    "cc_library",
)

# codechecker rules
load(
    "//codechecker:codechecker.bzl",
    "codechecker_suite",
    "codechecker_test",
)

# Test for strip_include_prefix
cc_library(
    name = "test_lib",
    hdrs = glob(["inc/*.h"]),
    strip_include_prefix = "inc",
)

# Simplest C++ test
cc_binary(
    name = "test_main",
    srcs = ["test_main.cc"],
    deps = ["test_lib"],
)

# Simple codechecker rule - performs only "build" phase without "test"
# which verifies results and sends results to online database
codechecker_test(
    name = "codechecker_main_build",
    targets = [
        "test_main",
    ],
)

# Simplest codechecker_suite example for "test_main"
# Can run CodeChecker on targets built for different configs
# This example performs build just for default config
codechecker_suite(
    name = "codechecker_main_multi",
    targets = [
        "test_main",
    ],
)
