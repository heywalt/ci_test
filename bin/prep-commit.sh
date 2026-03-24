#!/usr/bin/env bash
set -uo pipefail

# Get script directory and project root for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECKS_DIR="$SCRIPT_DIR/checks"
ARTIFACTS_DIR="$PROJECT_ROOT/ai-artifacts"

# Create artifacts directory if it doesn't exist
mkdir -p "$ARTIFACTS_DIR"

# Create log file with timestamp in artifacts directory
LOG_FILE="$ARTIFACTS_DIR/prep-commit-$(date +%Y%m%d-%H%M%S).log"

# Signal handling for clean exit
trap 'echo "Interrupted" | tee -a "$LOG_FILE"; exit 130' INT

echo "Starting pre-commit checks..." | tee -a "$LOG_FILE"
echo "Logging to: $LOG_FILE" | tee -a "$LOG_FILE"

# Start PLT generation in background to speed up later dialyzer run
echo "Pre-building dialyzer PLT cache..." | tee -a "$LOG_FILE"
"$CHECKS_DIR/dialyzer.sh" --plt &>/dev/null &
PLT_PID=$!

COMPLETE="false"
until [[ "${COMPLETE}" == "true" ]]; do
  COMPLETE="true"

  # Format check/fix
  echo "Formatting code..." | tee -a "$LOG_FILE"
  if "$CHECKS_DIR/fmt.sh" fix 2>&1 | tee -a "$LOG_FILE"; then
    echo "✓ Code formatted" | tee -a "$LOG_FILE"
  fi

  # Compile check with inner retry loop
  COMPILE_FIXED="false"
  echo "Running compilation..." | tee -a "$LOG_FILE"
  until "$CHECKS_DIR/compile.sh" 2>&1 | tee -a "$LOG_FILE"; do
    echo "✗ Compilation failed, requesting fixes..." | tee -a "$LOG_FILE"
    if ! claude -p --dangerously-skip-permissions "/fix:compilation" 2>&1 | tee -a "$LOG_FILE"; then
      echo "Error: Failed to run claude fix command" | tee -a "$LOG_FILE" >&2
      exit 1
    fi
    echo "Retrying compilation..." | tee -a "$LOG_FILE"
    COMPILE_FIXED="true"
  done
  echo "✓ Compilation passed" | tee -a "$LOG_FILE"
  if [[ "${COMPILE_FIXED}" == "true" ]]; then
    echo "⟳ Restarting checks after compilation fixes..." | tee -a "$LOG_FILE"
    COMPLETE="false"
    continue
  fi

  # Credo check with inner retry loop
  CREDO_FIXED="false"
  echo "Running credo..." | tee -a "$LOG_FILE"
  until "$CHECKS_DIR/credo.sh" 2>&1 | tee -a "$LOG_FILE"; do
    echo "✗ Credo failed, requesting fixes..." | tee -a "$LOG_FILE"
    if ! claude -p --dangerously-skip-permissions "/fix:credo" 2>&1 | tee -a "$LOG_FILE"; then
      echo "Error: Failed to run claude fix command" | tee -a "$LOG_FILE" >&2
      exit 1
    fi
    echo "Retrying credo..." | tee -a "$LOG_FILE"
    CREDO_FIXED="true"
  done
  echo "✓ Credo passed" | tee -a "$LOG_FILE"
  if [[ "${CREDO_FIXED}" == "true" ]]; then
    echo "⟳ Restarting checks after credo fixes..." | tee -a "$LOG_FILE"
    COMPLETE="false"
    continue
  fi

  # Tests check with inner retry loop
  TESTS_FIXED="false"
  echo "Running tests..." | tee -a "$LOG_FILE"
  until "$CHECKS_DIR/test.sh" 2>&1 | tee -a "$LOG_FILE"; do
    echo "✗ Tests failed, requesting fixes..." | tee -a "$LOG_FILE"
    if ! claude -p --dangerously-skip-permissions "/fix:tests" 2>&1 | tee -a "$LOG_FILE"; then
      echo "Error: Failed to run claude fix command" | tee -a "$LOG_FILE" >&2
      exit 1
    fi
    echo "Retrying tests..." | tee -a "$LOG_FILE"
    TESTS_FIXED="true"
  done
  echo "✓ Tests passed" | tee -a "$LOG_FILE"
  if [[ "${TESTS_FIXED}" == "true" ]]; then
    echo "⟳ Restarting checks after test fixes..." | tee -a "$LOG_FILE"
    COMPLETE="false"
    continue
  fi

  exit

  # Dialyzer check with inner retry loop
  DIALYZER_FIXED="false"
  echo "Running dialyzer..." | tee -a "$LOG_FILE"
  # Wait for PLT generation to complete if still running
  if kill -0 "$PLT_PID" 2>/dev/null; then
    echo "Waiting for PLT cache to finish..." | tee -a "$LOG_FILE"
    wait "$PLT_PID"
  fi
  until "$CHECKS_DIR/dialyzer.sh" 2>&1 | tee -a "$LOG_FILE"; do
    echo "✗ Dialyzer failed, requesting fixes..." | tee -a "$LOG_FILE"
    if ! claude -p --dangerously-skip-permissions "/fix:dialyzer" 2>&1 | tee -a "$LOG_FILE"; then
      echo "Error: Failed to run claude fix command" | tee -a "$LOG_FILE" >&2
      exit 1
    fi
    echo "Retrying dialyzer..." | tee -a "$LOG_FILE"
    DIALYZER_FIXED="true"
  done
  echo "✓ Dialyzer passed" | tee -a "$LOG_FILE"
  if [[ "${DIALYZER_FIXED}" == "true" ]]; then
    echo "⟳ Restarting checks after dialyzer fixes..." | tee -a "$LOG_FILE"
    COMPLETE="false"
    continue
  fi
done

echo "All checks passed!" | tee -a "$LOG_FILE"
