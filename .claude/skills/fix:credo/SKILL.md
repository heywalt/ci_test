---
name: fix:credo
description: Fix Credo static analysis violations in strict mode
disable-model-invocation: true
---

THINK I have issues that I want you to fix. Help me debug these issues.

I want you to fix Credo violations in strict mode. Here is how you reproduce
the issues:
    | To see violations for the entire application: `mix credo --strict`
    | To see violations for a single file: `mix credo --strict <file>`
    | The --strict flag is mandatory for comprehensive violation detection.
    | Fix at most 5 files at a time.

Follow the iterative fix process below using the commands described above.

## Credo-Specific Guidance

### Violation Categories

Credo groups violations into these categories:
- **Consistency**: code style and formatting issues
- **Design**: architectural and design pattern violations
- **Readability**: code clarity and comprehension issues
- **Refactor**: code complexity and maintainability issues
- **Warning**: potential bugs and performance issues

### Handling ok/error Tuple Pattern Conflicts

When both `NoTupleMatchInHead` and `CaseOnBareArg` violations appear for
functions handling `:ok`/`:error` tuple responses, resolve by moving case logic
to the calling function and eliminating the wrapper:

**Before** (violates either NoTupleMatchInHead or CaseOnBareArg):
```elixir
defp do_api_call(params, opts) do
  response = make_request(params, opts)
  handle_response(response)
end

defp handle_response(response) do
  case response do
    {:ok, data} -> process_success(data)
    {:error, err} -> handle_error(err)
  end
end
```

**After** (inline the case, remove the wrapper):
```elixir
defp do_api_call(params, opts) do
  case make_request(params, opts) do
    {:ok, data} -> process_success(data)
    {:error, err} -> handle_error(err)
  end
end
```

If this creates `SingleControlFlow` violations from a pipe + case combination,
extract the pipe chain to a dedicated helper function.

## Iterative Fix Process

You are an application-wide issue resolution specialist. Systematically identify
and resolve issues across the entire application using parallel processing.

### Parameters

- **Max parallel files**: 5
- **Max iterations**: 10
- **Convergence requirement**: each iteration must reduce total violation count
- **Tool command**: `mix credo --strict`
- **Single-file command**: `mix credo --strict <file>`
- **Success criteria**: tool returns zero violations

### Iteration Cycle

Repeat the following steps until the tool reports zero violations:

#### Step 1: Global Analysis

Run `mix credo --strict` for the entire application. Capture complete output
including exit code, violation counts by severity (critical, high, normal, low),
and file-specific details with line numbers and rule names.

- If zero violations: **SUCCESS** - terminate the process.
- If violations detected: continue to step 2.

#### Step 2: Issue Prioritization and File Selection

Select up to 5 files with highest-impact violations. Prioritize by:
1. Severity impact (50%): critical/high-severity violations first
2. Fix complexity (25%): auto-fixable violations processed first
3. File importance (15%): core business logic over support files
4. Violation density (10%): highest ratio of violations to lines of code

Ensure selected files can be modified independently. If files share `use` or
`import` relationships, select only one per dependency group. Avoid simultaneous
modification of macro-defining and macro-using files.

#### Step 3: Parallel Subagent Execution

Deploy subagents to fix selected files simultaneously. Each subagent:
1. Validates the file compiles: `mix compile`
2. Establishes baseline: `mix credo --strict <file>`
3. Fixes violations in priority order (critical > high > normal > low)
4. Validates the file still compiles after each change
5. Verifies violation resolution: `mix credo --strict <file>`
6. Confirms no new violations introduced
7. Preserves code semantics and functionality

If a fix breaks compilation or introduces new violations, revert and try a more
conservative approach. After 3 failed attempts on a file, report it for manual
review.

#### Step 4: Integration Validation

Re-run `mix credo --strict` for the entire application to assess progress.
Also run `mix compile` to ensure code integrity.

- If zero violations: **SUCCESS** - terminate.
- If violation count reduced with no new violations: **PROGRESS** - return to step 1.
- If no progress after 3 consecutive iterations: **STAGNATION** - escalate.
- If new violations introduced or compilation broken: **REGRESSION** - rollback and retry.
