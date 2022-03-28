import argparse
import os
import re
import subprocess
import sys


def cc_coverage(coverage_dir, coverage_log, coverage_dat, coverage_report, tests):
    returncode = 0
    log_txt = ""

    for test in tests:
        result = subprocess.run([test], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        log_txt += result.stdout + "\n"
        if result.returncode != 0:
            print("Unittest failed:", file=sys.stderr)
            print(result.stderr, file=sys.stderr)
            returncode = result.returncode

    cmd = [
        os.environ["LCOV_EXECUTABLE"],
        "--rc", "lcov_branch_coverage=1",
        "--rc", "geninfo_adjust_src_path=/proc/self/cwd/=>%s/" % os.path.abspath(coverage_dir),
        "--rc", "geninfo_auto_base=1",
        "--capture",
        "--directory", ".",
        "--output-file", os.path.abspath(coverage_dat),
        "--gcov-tool",  os.environ["GCOV_EXECUTABLE"],
        "--base-directory", os.path.abspath(coverage_dir),
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    log_txt += result.stdout + "\n"
    log_txt += result.stderr + "\n"

    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        returncode = result.returncode

    with open(coverage_dat) as f:
        coverage_data = f.read()
    coverage_data = re.sub(r"_coverage/bazel-out\/k8-fastbuild[^/]*\/bin\/", "_coverage/", coverage_data)
    with open(coverage_dat + ".dat", "w") as f:
        f.write(coverage_data)
    with open(coverage_dat, "w") as f:
        f.write(coverage_data)

    cmd = [
        os.environ["GENHTML_EXECUTABLE"],
        os.path.abspath(coverage_dat),
        "--prefix", os.path.abspath(coverage_dir),
        "-o", os.path.abspath(coverage_report),
        "--function-coverage",
        "--branch-coverage",
    ]

    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, cwd=coverage_dir)
    log_txt += result.stdout + "\n"
    log_txt += result.stderr + "\n"

    if result.returncode != 0:
        print(result.stdout, file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        returncode = result.returncode

    with open(coverage_log, "w") as log:
        log.write(log_txt)

    matches = re.findall("([a-z]+)[\.]+: ([0-9\.]+)%", log_txt)
    for m in matches:
        coverage_type = m[0]
        coverage_percent = m[1]
        print("Code Coverage (%s): %s%%" % (coverage_type, coverage_percent), file=sys.stderr)

    return returncode


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--coverage_dir", help='Root to the symlink forest', required=True)
    parser.add_argument("--coverage_log", help='Output path to coverage manifest', required=True)
    parser.add_argument("--coverage_dat", help='Output path to coverage.dat', required=True)
    parser.add_argument("--coverage_report", help='Output directory for the coverage report', required=True)
    parser.add_argument('--tests', nargs="+", default=[], help='All instrumented tests.')

    args = parser.parse_args()
    sys.exit(cc_coverage(
        args.coverage_dir,
        args.coverage_log,
        args.coverage_dat,
        args.coverage_report,
        args.tests,
    ))
