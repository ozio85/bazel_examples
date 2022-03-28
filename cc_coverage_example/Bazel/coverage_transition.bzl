"""Coverage transition switches on some command line parameters needed
when building code coverage, this can of course be refined."""

COVERAGE_TRANSITION = {
    # Enable collection of gcno files.
    "//command_line_option:collect_code_coverage": "True",
    # Disable visibility check (to be able to depend on tests in googletest).
    "//command_line_option:check_visibility": "False",
    # Enable coverage compiler flags, make sure to switch off any optimization (not even Og).
    "//command_line_option:features": ["coverage"],
}

def _coverage_transition_impl(settings, attr):
    return COVERAGE_TRANSITION

coverage_transition = transition(
    implementation = _coverage_transition_impl,
    inputs = [],
    outputs = COVERAGE_TRANSITION.keys(),
)
