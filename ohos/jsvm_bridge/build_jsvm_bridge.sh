#!/usr/bin/env bash
# Build libjsvm_bridge.so (OHOS arm64) for the JSVM backend.
# Requires DevEco command-line-tools 26.x (OHOS NDK with libjsvm.so).
set -euo pipefail
if [ -z "$DEVECO_CLT_HOME" ]; then
  echo "set DEVECO_CLT_HOME to the DevEco command-line-tools directory" >&2
  exit 1
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
N="$DEVECO_CLT_HOME/sdk/default/openharmony/native"
OUT="$HERE/../libs/arm64-v8a/libjsvm_bridge.so"
"$N/llvm/bin/clang++" --target=aarch64-linux-ohos --sysroot="$N/sysroot"   -I"$N/sysroot/usr/include" -fPIC -shared -O2 -std=c++17 -static-libstdc++   "$HERE/jsvm_bridge.cpp" -o "$OUT"   -L"$N/sysroot/usr/lib/aarch64-linux-ohos" -ljsvm
echo "built: $OUT"
