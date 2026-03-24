---
name: fix:tests
description: Fix failing Elixir ExUnit tests
disable-model-invocation: true
---

THINK I have issues that I want you to fix. Help me debug these issues.

I want you to fix failing tests. Here is how you reproduce the issues:
    | To run the full test suite: `mix test --warnings-as-errors`
    | To run a single test file: `mix test <file> --max-failures 1 --warnings-as-errors`
    | Fix at most 5 files at a time.

Follow the iterative fix process below using the commands described above.

## Test-Specific Guidance

### Error Categories

Classify test failures by type to determine priority:
1. **Compilation**: CompileError, SyntaxError, UndefinedFunctionError
2. **Dependency**: module not available, dependency errors
3. **Setup**: setup_all failures, fixture issues
4. **Assertion**: ExUnit.AssertionError, MatchError
5. **Timeout**: ExUnit.TimeoutError

Compilation and dependency errors block other tests and take absolute priority.

### Database Tests

Tests that hit the database run inside a transaction that is rolled back after
the test completes. There is no need to drop or reset the database before
running tests.

### Key Constraint

Only modify test files unless the test failure clearly indicates a bug in
application code. When fixing application code, ensure the fix is minimal and
targeted.

## Iterative Fix Process

You are an application-wide issue resolution specialist. Systematically identify
and resolve issues across the entire application using parallel processing.

### Parameters

- **Max parallel files**: 5
- **Max iterations**: 10
- **Convergence requirement**: each iteration must reduce total failure count
- **Tool command**: `mix test --warnings-as-errors`
- **Single-file command**: `mix test <file> --max-failures 1 --warnings-as-errors`
- **Success criteria**: tool returns exit code 0 with all tests passing

### Iteration Cycle

Repeat the following steps until the tool reports zero failures:

#### Step 1: Global Analysis

Run `mix test --warnings-as-errors` for the entire application. Capture complete
output including exit code, test count, failure count, and specific failing test
files with line numbers and error messages.

- If zero failures: **SUCCESS** - terminate the process.
- If failures detected: continue to step 2.

#### Step 2: Issue Prioritization and File Selection

Select up to 5 files with highest-impact failures. Prioritize by:
1. Dependency impact (40%): files that block other tests from running
2. Error severity (35%): compilation errors > dependency > setup > assertion > timeout
3. Failure density (25%): highest ratio of failing tests to total tests in file

Ensure selected files have non-overlapping dependency conflicts. If files share
critical dependencies, select only one per dependency group.

#### Step 3: Parallel Subagent Execution

Deploy subagents to fix selected files simultaneously. Each subagent:
1. Verifies the file exists and is readable
2. Runs the single file to confirm failure: `mix test <file> --max-failures 1 --warnings-as-errors`
3. Analyzes specific error messages and failure patterns
4. Identifies root cause (missing imports, incorrect assertions, fixture issues)
5. Applies minimal fix addressing root cause
6. Tests fix in isolation: `mix test <file> --max-failures 1 --warnings-as-errors`
7. Validates no side effects introduced

If a fix introduces new failures, revert all changes and attempt an alternative
repair strategy. After 3 failed attempts on a file, report it for manual review.

#### Step 4: Integration Validation

Re-run `mix test --warnings-as-errors` for the entire application to assess
progress.

- If zero failures: **SUCCESS** - terminate.
- If failure count reduced with no new failures: **PROGRESS** - return to step 1.
- If no progress after 3 consecutive iterations: **STAGNATION** - escalate.
- If previously passing tests now fail: **REGRESSION** - rollback and retry.
