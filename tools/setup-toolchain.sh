#!/usr/bin/env bash
# Add a C++ twin of the boilerplate's prospero-clang18 wrapper (same target/sysroot flags,
# clang++-18 driver, exceptions and RTTI enabled as SoH requires).
set -euo pipefail
source "$(dirname "$0")/env.sh"

tooling=$PS5_NATIVE_APP_TEMPLATE/tooling
sed 's/command -v clang-18/command -v clang++-18/; s/PS5_CLANG:-/PS5_CLANGXX:-/; s/-femulated-tls /-femulated-tls -fexceptions -fcxx-exceptions -frtti /' \
    "$tooling/prospero-clang18" > "$tooling/prospero-clang18++"
chmod +x "$tooling/prospero-clang18" "$tooling/prospero-clang18++"
command -v clang++-18 llvm-ar-18 ninja cmake >/dev/null
echo "toolchain ready: $tooling/prospero-clang18++"
