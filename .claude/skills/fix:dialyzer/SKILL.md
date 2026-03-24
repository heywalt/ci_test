---
name: fix:dialyzer
description: Fix Dialyzer type analysis issues
disable-model-invocation: true
---

THINK I have issues that I want you to fix. Help me debug these issues.

I want you to fix Dialyzer type analysis issues. Here is how you reproduce
the issues:
    | To run Dialyzer for the entire application: `mix dialyzer`
    | Dialyzer cannot be run against single files - it always analyzes the entire application.
    | Fix at most 5 issues per iteration - always the first 5 issues in the output.
    | If PLT build fails, rebuild with: `mix dialyzer --plt`

Follow the iterative fix process below using the commands described above.

## Dialyzer-Specific Guidance

### Issue Types

Dialyzer reports these categories of issues:
- **Type mismatch**: function return types don't match specifications
- **Missing specs**: functions lack proper @spec declarations
- **Contract violation**: type contracts violated by implementation
- **Unreachable code**: dead code or impossible execution paths
- **Pattern matching**: incomplete or impossible pattern matches
- **External calls**: issues with external library function calls

### Fix Strategies

For each issue type, apply the appropriate strategy:
1. **Add type specs**: add missing @spec declarations with correct types
2. **Correct existing specs**: fix incorrect type specifications to match actual behavior
3. **Refine implementation**: adjust code to match intended type contracts
4. **Pattern match completion**: add missing pattern match clauses
5. **Guard clause addition**: add guard clauses for type safety
6. **External type handling**: properly handle external library types

When deciding between fixing the @spec or fixing the implementation, determine
which one reflects the intended behavior. Prefer fixing the spec when the
implementation is correct; prefer fixing the implementation when the spec
represents the desired contract.

## Iterative Fix Process

You are an application-wide issue resolution specialist. Systematically identify
and resolve issues across the entire application using parallel processing.

### Parameters

- **Max parallel files**: 5 (one per targeted issue)
- **Max iterations**: 20
- **Batch size**: 5 (always the first 5 issues in Dialyzer output)
- **Convergence requirement**: each iteration must resolve at least 1 issue
- **Tool command**: `mix dialyzer`
- **Success criteria**: tool returns zero issues

### Iteration Cycle

Repeat the following steps until the tool reports zero issues:

#### Step 1: Global Analysis

Run `mix dialyzer` for the entire application. Capture complete output including
exit code, PLT build status, total issue count, and details for each issue
(file, line number, issue type, message, function context).

- If zero issues: **SUCCESS** - terminate the process.
- If issues detected: select the **first 5 issues** in the order they appear in
  Dialyzer's output. Do not reorder them.

#### Step 2: Issue Analysis and Planning

For each of the 5 targeted issues:
1. Parse the Dialyzer error message to understand root cause
2. Examine function implementation and current type specifications
3. Identify type inconsistencies or missing contracts
4. Assess impact of potential fix on dependent code
5. Determine the appropriate fix strategy

Group issues by affected file. No more than one subagent per file simultaneously.

#### Step 3: Parallel Subagent Execution

Deploy subagents to fix targeted issues simultaneously. Each subagent:
1. Validates the file compiles: `mix compile`
2. Confirms the issue still exists in current codebase
3. Applies minimal fix preserving function semantics
4. Validates the file still compiles after changes
5. Ensures type specifications are accurate and complete

If a fix breaks compilation, revert and try a more conservative approach. After
3 failed attempts on an issue, report it for manual review.

#### Step 4: Integration Validation

Re-run `mix dialyzer` for the entire application to assess progress. Also run
`mix compile` to ensure code integrity.

- If zero issues: **SUCCESS** - terminate.
- If at least 1 targeted issue resolved with no new issues: **PROGRESS** - return to step 1.
- If no progress after 3 consecutive iterations: **STAGNATION** - escalate.
- If new issues introduced or compilation broken: **REGRESSION** - rollback and retry.
