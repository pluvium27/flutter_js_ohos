# libjsvm_bridge.so (OHOS JSVM C shim)

Thin C++ wrapper around the HarmonyOS JSVM C API from the OHOS NDK:

- OH_JSVM_Init / OH_JSVM_CreateVM / OH_JSVM_OpenVMScope / OH_JSVM_CreateEnv
- OH_JSVM_CompileScript / OH_JSVM_RunScript / exception handling

It exposes three C symbols to Dart FFI:

- jsvm_bridge_eval(src, len, char** out) -> 0 ok / 1 JS error / 2 init error
- jsvm_bridge_free(char* text)
- jsvm_bridge_reset()

Build (arm64, OHOS NDK from DevEco CLT 26.x):

    DEVECO_CLT_HOME=/path/to/command-line-tools ./build_jsvm_bridge.sh

The prebuilt arm64 binary is committed under ohos/libs/arm64-v8a so an OHOS
app can use the backend without a local NDK build.

The shim links only libjsvm.so and libc.so (libc++ is linked statically);
it does not depend on libc++_shared.so.
