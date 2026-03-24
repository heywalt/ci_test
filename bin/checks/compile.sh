#!/bin/bash
set -e

# Run mix compile with warnings as errors and force recompilation
mix compile --warnings-as-errors --force
