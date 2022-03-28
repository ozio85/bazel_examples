load("@bazel_skylib//lib:paths.bzl", "paths")
load(":coverage_transition.bzl", "coverage_transition")
load(":collect_file_aspect.bzl", "collect_file_aspect", "FileInfo")

def _strip_bazel_out(path):
    if path.startswith("bazel-out"):
        # Remove bazel-out/k8-fastbuild-ST-632351/bin
        return path.split("/", 3)[3]
    else:
        return path

def _cc_coverage_impl(ctx, **kwargs):
    cc_toolchain = ctx.toolchains["@bazel_tools//tools/cpp:toolchain_type"].cc
    lcov_toolchain = ctx.toolchains["//Bazel/Toolchains/Lcov:lcov_toolchain_type"].lcovinfo

    # Set up a symlink forest (runfiles tree), so lcov can find all files where is assumes them to be.
    coverage_base_dir = "_" + ctx.attr.name
    symlink_forest = []
    for dep in ctx.attr.deps:
        # The gcov gcno files are retrieved from the InstrumentedFilesInfo
        for target_file in dep[InstrumentedFilesInfo].metadata_files.to_list():
            symlink = ctx.actions.declare_file(paths.join(coverage_base_dir, _strip_bazel_out(target_file.path)))
            symlink_forest.append(symlink)
            ctx.actions.symlink(
                output = symlink,
                target_file = target_file,
            )
        # However, generated sources are missing in InstrumentedFilesInfo, so here is a
        # replacement aspect for it :)
        for target_file in dep[FileInfo].srcs.to_list() + dep[FileInfo].hdrs.to_list():
            symlink = ctx.actions.declare_file(paths.join(coverage_base_dir, _strip_bazel_out(target_file.path)))
            symlink_forest.append(symlink)
            ctx.actions.symlink(
                output = symlink,
                target_file = target_file,
            )
            # Generated sources needs to exist on their original path since gcov will search for the exact matching source file.
            # The shorter path (without bazel-out) is needed for nice display in the report.
            if target_file.path.startswith("bazel-out"):
                symlink = ctx.actions.declare_file(paths.join(coverage_base_dir, target_file.path))
                symlink_forest.append(symlink)
                ctx.actions.symlink(
                    output = symlink,
                    target_file = target_file,
                )

    # Include test-runfiles (runtime .so libs).
    runfile_depsets = []
    for target in ctx.attr.tests:
        runfile_depsets.append(target[DefaultInfo].default_runfiles.files)
    runfiles = depset(transitive = runfile_depsets).to_list()

    coverage_log = ctx.actions.declare_file(paths.join(coverage_base_dir, ctx.attr.name + ".log"))
    coverage_dat = ctx.actions.declare_file(paths.join(coverage_base_dir, "coverage.dat"))
    coverage_report = ctx.actions.declare_directory(paths.join(coverage_base_dir, "coverage_report"))

    env = {
        # Set path to symlink forest.
        "GCOV_PREFIX": coverage_dat.dirname,
        # Strip /proc/self/pwd/bazel-out/k8-fastbuild/bin
        "GCOV_PREFIX_STRIP": "6",
        "LCOV_EXECUTABLE": lcov_toolchain.lcov_command,
        "GENHTML_EXECUTABLE": lcov_toolchain.genhtml_command,
        # The Gcov tool should normally be retrieved from the cc_toolchain, but
        # then you need a fully configured cc toolchain :) If it is interresting
        # I can add one in this example.
        #"GCOV_EXECUTABLE": cc_toolchain.gcov_executable,
        "GCOV_EXECUTABLE": "/usr/bin/gcov",
        # All Bazel .so libs are located in _solib_k8
        "LD_LIBRARY_PATH": runfiles[0].dirname if len(runfiles) > 0 else "."
    }
    args = ctx.actions.args()
    args.add_all([
        "--coverage_dir",
        coverage_dat.dirname,
        "--coverage_log",
        coverage_log,
        "--coverage_dat",
        coverage_dat,
        "--coverage_report",
        coverage_report.path,
        "--tests",
    ] + ctx.files.tests)

    ctx.actions.run(
        inputs = ctx.files.tests + symlink_forest + lcov_toolchain.genhtml_data + lcov_toolchain.lcov_data + runfiles,
        outputs = [coverage_log, coverage_dat, coverage_report],
        mnemonic = "CoverageReport",
        arguments = [args],
        progress_message = "Run coverage %{output}",
        env = env,
        executable = ctx.executable._coverage_tool,
    )

    return [DefaultInfo(files = depset([coverage_log, coverage_dat, coverage_report]))]

_cc_coverage = rule(
    implementation = _cc_coverage_impl,
    cfg = coverage_transition,
    attrs = {
        "deps": attr.label_list(
            doc = "CcInfo compatible targets",
            aspects = [collect_file_aspect],
            providers = [CcInfo, InstrumentedFilesInfo],
        ),
        "tests": attr.label_list(
            doc = "Instrumented tests"
        ),
        "_coverage_tool": attr.label(
            executable = True,
            cfg = "exec",
            allow_files = True,
            default = Label("//Bazel:cc_coverage"),
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
        "//Bazel/Toolchains/Lcov:lcov_toolchain_type",
    ],
)

def cc_coverage(name, **kwargs):
    if not name.endswith("coverage"):
        fail("All coverage rule names must end with 'coverage'")

    _cc_coverage(
        name = name,
        testonly = True,
        **kwargs
    )