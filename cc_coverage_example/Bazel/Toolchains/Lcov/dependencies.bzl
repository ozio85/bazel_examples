load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Workspace rules.
def register_lcov_toolchain():
    # Register toolchain so it can be found by Bazel.
    native.register_toolchains(
        "@//Bazel/Toolchains/Lcov:lcov_linux_toolchain",
    )
