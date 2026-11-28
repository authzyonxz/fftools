#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?output object directory required}"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
PIN=c378d90e52892bc8f3508ea6511d040d89eb5abb
CACHE="$ROOT/.auth-vm-toolchain"
LLVM_PREFIX="${LLVM_PREFIX:-$(brew --prefix llvm@20)}"
CC="$LLVM_PREFIX/bin/clang"
OPT="$LLVM_PREFIX/bin/opt"
mkdir -p "$CACHE" "$OUT"
if [ ! -d "$CACHE/kagura/.git" ]; then
    git init "$CACHE/kagura"
    git -C "$CACHE/kagura" remote add origin https://github.com/qusamulab/kagura.git
fi
git -C "$CACHE/kagura" fetch --depth=1 origin "$PIN"
git -C "$CACHE/kagura" checkout --detach "$PIN"
test "$(git -C "$CACHE/kagura" rev-parse HEAD)" = "$PIN"
cmake -S "$CACHE/kagura" -B "$CACHE/build" -G Ninja \
    -DLLVM_DIR="$LLVM_PREFIX/lib/cmake/llvm" \
    -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$LLVM_PREFIX/bin/clang++" \
    -DCMAKE_BUILD_TYPE=Release -DKAGURA_BUILD_TESTS=OFF -DKAGURA_BITCODE_TOOLS=OFF
cmake --build "$CACHE/build" --target KaguraObfuscator --parallel 3
PLUGIN="$(find "$CACHE/build" -name '*KaguraObfuscator*.dylib' -type f -print -quit)"
test -n "$PLUGIN"
RUNTIME="$CACHE/kagura/runtime/core/vm_interpreter.c"
transform() {
    "$OPT" -load-pass-plugin="$PLUGIN" -kagura-vm \
        -passes='function(kagura-vm),verify' -S "$1" -o "$2"
    # Fail the release if unsupported IR was silently left unvirtualized.
    grep -q '@kagura_vm_bc_' "$2"
    grep -q 'call.*@kagura_vm_execute' "$2"
}
# Execute virtualized host code against boundary and tampered-state cases.
MACSDK="$(xcrun --sdk macosx --show-sdk-path)"
"$CC" -isysroot "$MACSDK" -O1 -S -emit-llvm "$ROOT/Sources/Auth/KAPolicy.c" -o "$OUT/policy-host.ll"
transform "$OUT/policy-host.ll" "$OUT/policy-host-vm.ll"
"$CC" -isysroot "$MACSDK" -O2 -I"$CACHE/kagura/include" -I"$ROOT/Sources/Auth" \
    "$OUT/policy-host-vm.ll" "$RUNTIME" "$ROOT/Tests/auth_policy_test.c" -o "$OUT/auth-policy-test"
"$OUT/auth-policy-test"
# Upstream LLVM produces only this pure C object. UIKit stays on Apple clang.
"$CC" -target arm64-apple-ios15.0 -isysroot "$SDK" -O1 -S -emit-llvm \
    "$ROOT/Sources/Auth/KAPolicy.c" -o "$OUT/policy-ios.ll"
transform "$OUT/policy-ios.ll" "$OUT/policy-ios-vm.ll"
"$CC" -target arm64-apple-ios15.0 -isysroot "$SDK" -O2 -fvisibility=hidden \
    -c "$OUT/policy-ios-vm.ll" -o "$OUT/KAPolicy.o"
"$CC" -target arm64-apple-ios15.0 -isysroot "$SDK" -O2 -fvisibility=hidden \
    -I"$CACHE/kagura/include" -c "$RUNTIME" -o "$OUT/KAVMRuntime.o"
xcrun nm "$OUT/KAPolicy.o" | grep -q '_kagura_vm_execute'
printf 'Kagura %s: host semantic tests passed; arm64 VM bytecode and runtime linked.\n' "$PIN" > "$OUT/auth-vm-validation.txt"
cp "$CACHE/kagura/LICENSE" "$OUT/Kagura-LICENSE.txt"
