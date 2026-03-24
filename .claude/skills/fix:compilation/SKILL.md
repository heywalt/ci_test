---
name: fix:compilation
description: Fix Elixir compilation errors and warnings
disable-model-invocation: true
---

THINK I have issues that I want you to fix. Help me debug these issues.

I want you to fix compilation issues, including warnings. Here is how you
reproduce the issues:
    | To see compilation issues for the entire application: `mix compile --warnings-as-errors --force`
    | Compilation warnings can not be checked against just a single file.
    |  - However, you should still only try to fix at most 5 files at a time.

Follow the iterative fix process below using the commands described above.

## Iterative Fix Process

You are an application-wide issue resolution specialist. Systematically identify
and resolve issues across the entire application using parallel processing.

### Parameters

- **Max parallel files**: 5
- **Max iterations**: unlimited (continue until zero issues remain)
- **Convergence requirement**: each iteration must reduce total issue count
- **Tool command**: `mix compile --warnings-as-errors --force`
- **Success criteria**: tool returns zero issues

### Iteration Cycle

Repeat the following steps until the tool reports zero issues:

#### Step 1: Global Analysis

Run the analysis tool for the entire application. Capture complete output
including exit code, issue count, severity breakdown, and file-specific details
with line numbers.

- If zero issues: **SUCCESS** - terminate the process.
- If issues detected: continue to step 2.

#### Step 2: Issue Prioritization and File Selection

Select up to 5 files with highest-impact issues. Prioritize by:
1. Severity impact (40%): critical/high-severity issues first
2. Issue density (30%): highest ratio of issues to lines of code
3. File importance (20%): core business logic over support files
4. Fix complexity (10%): prefer files with more auto-fixable issues

Ensure selected files can be modified independently without dependency conflicts.

#### Step 3: Parallel Subagent Execution

Deploy subagents to fix selected files simultaneously. Each subagent:
1. Validates the file compiles before modification
2. Fixes issues in priority order (critical > high > medium > low)
3. Validates the file still compiles after each change
4. Ensures no new issues are introduced
5. Preserves code semantics and functionality

If a fix breaks compilation, revert and try a more conservative approach.

#### Step 4: Integration Validation

Re-run the analysis tool for the entire application to assess progress.

- If zero issues: **SUCCESS** - terminate.
- If issue count reduced with no new issues: **PROGRESS** - return to step 1.
- If no progress after 3 consecutive iterations: **STAGNATION** - escalate.
- If new issues introduced or compilation broken: **REGRESSION** - rollback and retry.
