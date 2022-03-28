"""This FileInfo aspect is a replacement for Bazel's 'InstrumentedFilesInfo'
provider. Unfortunately, there the generated files are missing, but can be modified
according to this pull request:
https://github.com/bazelbuild/bazel/pull/11350
"""

FileInfo = provider(
    fields = {
        "hdrs": "Public header files",
        "srcs": "Source files",
    }
)

def _collect_file_aspect_impl(target, ctx):
    srcs_depsets = []
    hdrs_depsets = []

    if hasattr(ctx.rule.attr, "hdrs"):
        for src in ctx.rule.attr.hdrs:
            hdrs_depsets.append(src.files)

    if hasattr(ctx.rule.attr, "srcs"):
        for src in ctx.rule.attr.srcs:
            srcs_depsets.append(src.files)

    # Retrive recursive source files.
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            # Only from CC rules.
            if CcInfo in dep:
                # Recursively append all sources.
                srcs_depsets.append(dep[FileInfo].srcs)
                hdrs_depsets.append(dep[FileInfo].hdrs)

    return [FileInfo(
        hdrs = depset(transitive = hdrs_depsets),
        srcs = depset(transitive = srcs_depsets),
    )]

collect_file_aspect = aspect(
    implementation = _collect_file_aspect_impl,
    attr_aspects = ['deps'],
)
