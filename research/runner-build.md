# Local llama.cpp runner build notes

TweakStudio 0.4.0 bundles a CPU-only arm64 `llama-server` built from the upstream llama.cpp revision `339f3242c761f16c27e5ffcde1d35dcc31933a55` (revision string `339f324`). The reproducible command and portable CMake toolchain are in `tools/build-llama-server.sh` and `tools/ios-arm64-toolchain.cmake`.

The cross-build used Theos Linux clang/clang++, an installed iPhoneOS SDK, iOS deployment target 15.0, `MinSizeRel`, server-only build targets, and disabled Metal, Accelerate/BLAS, OpenMP, CUDA, Vulkan, RPC, curl, and OpenSSL. The resulting executable is Mach-O arm64/iOS with an iOS 15.0 minimum. It is not a Linux executable and cannot be run in this sandbox.

The server dynamically links seven llama.cpp internal dylibs. The package includes those dylibs and their versioned symlinks beside `llama-server`; each internal install name is rewritten to `@rpath`, and the executable includes `@executable_path` as its rpath. The build helper validates that no temporary build-directory paths remain, then ad-hoc signs the Mach-O images with Theos `ldid`. The app starts the server bound to `127.0.0.1`, CPU-only, with a 6144-token context and a single parallel slot. No GGUF models or model-download links are bundled.

**Verification boundary:** compilation, Mach-O metadata, load names, package structure, and generated UIKit app packaging can be validated in the Linux build environment. Actual iPhone launch, sandbox behavior, model load time, thermals, and RAM suitability still require the intended jailbroken device; this release has not been runtime-tested on that phone.

## Sources

- [llama.cpp pinned source revision](https://github.com/ggml-org/llama.cpp/tree/339f3242c761f16c27e5ffcde1d35dcc31933a55)
- [llama.cpp MIT license](https://github.com/ggml-org/llama.cpp/blob/339f3242c761f16c27e5ffcde1d35dcc31933a55/LICENSE)
- [Theos Linux installation](https://theos.dev/docs/installation-linux)
- [Theos rootless packaging](https://theos.dev/docs/Rootless.html)
- [Apple iOS app transport security](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity)
