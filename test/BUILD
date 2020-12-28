# # cc_binary for simple test_main
# load(
#     "@rules_cc//cc:defs.bzl",
#     "cc_binary",
#     "cc_library",
# )

# # codechecker rules
load(
    "//codechecker:codechecker.bzl",
    "codechecker",
#     "codechecker_online_database",
#     "codechecker_suite",
#     "codechecker_test",
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
codechecker(
    name = "codechecker_main_build",
    targets = [
        "test_main",
    ],
)

# # Example of how CodeChecker online database can be defined
# codechecker_online_database(
#     name = "codechecker_store",
#     url = "https://test.codechecker.gic.ericsson.se/PD_BBI/",
#     valid_users = [
#         "valid-user",
#     ],
# )

# # Simplest codechecker_test example
# # Runs CodeChecker on "test_main" target
# # Sends results to online database "codechecker_store" (defined above)
# # However to perform store the username must be "valid-user"
# codechecker_test(
#     name = "codechecker_main",
#     online_database = "codechecker_store",
#     run_name = "Bazel-main-test",
#     # run_tag = "my-tag",
#     targets = [
#         "test_main",
#     ],
# )

# # Simplest codechecker_suite example for "test_main"
# # Can run CodeChecker on targets built for different configs
# # This example performs build just for default config
# codechecker_suite(
#     name = "codechecker_main_multi",
#     targets = [
#         "test_main",
#     ],
# )

