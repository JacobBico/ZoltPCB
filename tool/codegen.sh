#!/usr/bin/env bash
# Regenerates Drift's database code.
#
# --force-jit is required, not optional: build_runner compiles the build
# script AOT by default, and `dart compile` refuses to do that while any
# dependency in the graph declares native build hooks. path_provider pulls in
# such a package transitively (objective_c, via path_provider_foundation), so
# AOT compilation of the builder always fails here. JIT builds are slower to
# start and otherwise identical.
set -euo pipefail
cd "$(dirname "$0")/.."
exec dart run build_runner build --force-jit "$@"
