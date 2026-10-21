#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
THEOS="${THEOS:-$HOME/theos}"
export THEOS
SDK="${IOS_SDK:-$THEOS/sdks/iPhoneOS16.5.sdk}"
PIN="339f3242c761f16c27e5ffcde1d35dcc31933a55"
WORK="${LLAMA_WORK_DIR:-$ROOT/tools/.llama-build}"
SRC="$WORK/source"
BUILD="$WORK/build"
STAGE="$WORK/stage"
DEST="$ROOT/layout/usr/libexec/tweakstudio"
BIN="$THEOS/toolchain/linux/iphone/bin"

for tool in git cmake make; do command -v "$tool" >/dev/null || { echo "Missing host tool: $tool" >&2; exit 1; }; done
for tool in clang clang++ llvm-ar llvm-ranlib llvm-strip install_name_tool otool ldid; do [[ -x "$BIN/$tool" ]] || { echo "Missing Theos tool: $BIN/$tool" >&2; exit 1; }; done
[[ -d "$SDK" ]] || { echo "Missing iOS SDK: $SDK (set IOS_SDK to override)" >&2; exit 1; }

mkdir -p "$WORK"
if [[ ! -d "$SRC/.git" ]]; then git clone --no-checkout https://github.com/ggml-org/llama.cpp.git "$SRC"; fi
git -C "$SRC" fetch --depth 1 origin "$PIN"
git -C "$SRC" checkout --detach FETCH_HEAD
rm -rf "$BUILD" "$STAGE"

cmake -S "$SRC" -B "$BUILD" -G 'Unix Makefiles' \
  -DCMAKE_TOOLCHAIN_FILE="$ROOT/tools/ios-arm64-toolchain.cmake" \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_COMMON=ON -DLLAMA_BUILD_UI=OFF \
  -DLLAMA_USE_PREBUILT_UI=OFF -DLLAMA_CURL=OFF -DLLAMA_OPENSSL=OFF \
  -DLLAMA_SUBPROCESS=OFF -DBUILD_SHARED_LIBS=ON \
  -DGGML_NATIVE=OFF -DGGML_METAL=OFF -DGGML_OPENMP=OFF \
  -DGGML_ACCELERATE=OFF -DGGML_BLAS=OFF -DGGML_VULKAN=OFF \
  -DGGML_CUDA=OFF -DGGML_RPC=OFF -DCMAKE_MACOSX_BUNDLE=OFF
cmake --build "$BUILD" --target llama-server -- -j"${JOBS:-2}"

mkdir -p "$STAGE"
cp -P "$BUILD/bin/llama-server" "$BUILD"/bin/*.dylib "$STAGE/"
shopt -s nullglob
libs=("$STAGE"/*.dylib)
real_libs=()
(( ${#libs[@]} >= 1 )) || { echo "Expected llama.cpp dylibs were not built." >&2; exit 1; }
for dylib in "${libs[@]}"; do
  [[ -L "$dylib" ]] && continue
  real_libs+=("$dylib")
  old_id="$("$BIN/otool" -D "$dylib" | tail -n 1 | sed "s#^$BUILD/bin/##")"
  [[ -n "$old_id" ]] || { echo "No Mach-O install ID for $dylib" >&2; exit 1; }
  "$BIN/install_name_tool" -id "@rpath/$old_id" "$dylib"
done
for image in "$STAGE/llama-server" "${real_libs[@]}"; do
  for dylib in "${libs[@]}"; do
    name="$(basename "$dylib")"
    "$BIN/install_name_tool" -change "$BUILD/bin/$name" "@rpath/$name" "$image" 2>/dev/null || true
  done
done
"$BIN/install_name_tool" -add_rpath '@executable_path' "$STAGE/llama-server"
for image in "$STAGE/llama-server" "${real_libs[@]}"; do "$BIN/ldid" -S "$image"; done
if "$BIN/otool" -L "$STAGE/llama-server" "${real_libs[@]}" | grep -F "$BUILD/bin/"; then
  echo "A Mach-O load command still points into the build directory." >&2
  exit 1
fi

mkdir -p "$DEST"
rm -f "$DEST/llama-server" "$DEST"/*.dylib
cp -P "$STAGE/llama-server" "${libs[@]}" "$DEST/"
chmod 755 "$DEST/llama-server" "$DEST"/*.dylib
"$BIN/otool" -L "$DEST/llama-server"
echo "Staged the iOS arm64 runner, ${#real_libs[@]} dylibs, and version symlinks at $DEST"
