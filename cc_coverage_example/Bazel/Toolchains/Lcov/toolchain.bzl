LcovInfo = provider(
    fields = [
        "lcov_command",
        "lcov_data",
        "genhtml_command",
        "genhtml_data",
    ],
)

def _local_or_packaged(executable, local_executable):
    if executable:
        command = executable.path
        data = [executable]
    elif local_executable:
        command = local_executable
        data = []
    else:
        fail("Either local executable or executable must be set.")
    return data, command

def _lcov_toolchain_impl(ctx):
    lcov_data, lcov_command = _local_or_packaged(ctx.file.lcov_executable, ctx.attr.local_lcov_executable)
    genhtml_data, genhtml_command = _local_or_packaged(ctx.file.genhtml_executable, ctx.attr.local_genhtml_executable)

    toolchain_info = platform_common.ToolchainInfo(
        lcovinfo = LcovInfo(
            lcov_command = lcov_command,
            lcov_data = lcov_data,
            genhtml_command = genhtml_command,
            genhtml_data = genhtml_data,
        ),
    )
    return [toolchain_info]

lcov_toolchain = rule(
    implementation = _lcov_toolchain_impl,
    attrs = {
        "lcov_executable": attr.label(allow_single_file = True),
        "local_lcov_executable": attr.string(),
        "genhtml_executable": attr.label(allow_single_file = True),
        "local_genhtml_executable": attr.string(),
        "gcov_executable": attr.label(allow_single_file = True),
        "local_gcov_executable": attr.string(),
    },
)
