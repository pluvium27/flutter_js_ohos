# OHOS / HarmonyOS support for flutter_js

This repository tracks upstream [flutter_js](https://github.com/abner/flutter_js)
0.8.7 (MIT) and adds an ohos platform so the package can be used from
Flutter for OpenHarmony / HarmonyOS.

## What is different from upstream

| Area | Change |
|---|---|
| pubspec.yaml | version 0.8.7-ohos.2; adds ohos: pluginClass: FlutterJsPlugin |
| lib/flutter_js.dart | getJavascriptRuntime() selects JsvmRuntime on OHOS (QuickJS bridge via extraArgs) |
| lib/quickjs/ffi.dart | QuickJS bridge loading; optional jsSetMemoryLimit |
| lib/jsvm/ | JSVM (ArkCompiler) FFI backend and runtime |
| ohos/ | HAR plugin shell (FlutterJsPlugin.ets, module.json5, oh-package.json5, build-profile.json5, hvigorfile.ts) and arm64 native libraries |

### Bridge loading on OHOS

The bundled libquickjs_c_bridge.so lives in the HAP native libraries
directory, which is not part of the default dlopen search path. The loader:

1. honours LIBQUICKJSC_PATH when set;
2. resolves the directory from /proc/self/maps (sibling of libflutter.so),
   preloads libc++_shared.so from that directory, then opens
   libquickjs_c_bridge.so by absolute path;
3. falls back to the plain soname.

jsSetMemoryLimit is treated as optional: community bridge builds that do not
export it get a no-op instead of failing during library initialization.

## Requirements

- Flutter OHOS SDK: tested with 3.47.7-ohos-1.0.1 (Dart 3.13.x).
- DevEco Studio / Command Line Tools 26.x, HarmonyOS API 26 device (arm64).
- Hosts: macOS and Windows use the official OH-Flutter SDK. Linux requires a
  host Dart SDK built from the OH-Flutter engine source (the released
  dart-sdk-ohos is Mach-O and there is no upstream Linux host build).
- The application HAP must also package libc++_shared.so next to the bridge
  (this repository includes it under ohos/libs/arm64-v8a/).

## Usage

Use this repository as a path dependency override while the OHOS support is
not part of a published package:

~~~yaml
# pubspec_overrides.yaml
dependency_overrides:
  flutter_js:
    path: ../flutter_js_ohos
~~~

Then build the HAP with the OH-Flutter SDK:

~~~bash
flutter build hap --debug --no-codesign
# sign with hap-sign-tool, install with hdc
~~~

Recursive Lispite templates in the KiriMemo kernel need a larger bridge stack;
create the runtime with IsolateQjs(stackSize: 1024 * 1024). flutter_js already
calls jsSetMaxStackSize when stackSize > 0.

See integration/ for a working KiriMemo setup:

- integration/pubspec_overrides.kirimemo.yaml - dependency overrides for the
  OHOS build.
- integration/ohos-module-snippet.json5 - deviceTypes / supportWindowMode
  needed for tablet layout.
- integration/kirimemo-core-js-runtime.patch - selects the OHOS engine in the
  application runtime factory.

## JSVM backend (default on OHOS)

HarmonyOS exposes the ArkCompiler JSVM engine to native code. The package
ships a thin C shim (ohos/libs/arm64-v8a/libjsvm_bridge.so, source in
ohos/jsvm_bridge/) and a Dart runtime (lib/jsvm/) on top of it. JSVM is the
default engine on OHOS; it is faster than the QuickJS bridge and does not
depend on a community prebuilt QuickJS binary.

The backend supports synchronous evaluation only. It does not provide Dart
channel callbacks, setTimeout, promises or fetch; those extensions are
disabled for JsvmRuntime. This is sufficient for kernels that use a
Dart -> JS -> JSON string protocol.

Build the shim for arm64 with the OHOS NDK:

~~~bash
DEVECO_CLT_HOME=/path/to/command-line-tools   ohos/jsvm_bridge/build_jsvm_bridge.sh
~~~

To keep using the QuickJS bridge on OHOS:

~~~dart
final runtime = getJavascriptRuntime(
  extraArgs: const {'engine': 'quickjs'},
);
~~~

## Validation

Validated on a HarmonyOS 7.0.0.111 (API 26) tablet, arm64, with a KiriMemo HAP
built for OHOS and a 307 KB heurams-core.js kernel (protocolVersion 2):

| Call | Result |
|---|---|
| kernel load | OK |
| inspectRepo (335 KB repo) | OK, ~3.1 s |
| overview | OK, ~57-91 ms |
| plan | OK, ~17 ms |
| createSession | OK, ~274 ms |

With JSVM, the same kernel initializes in ~37 ms and all core calls work; the QuickJS bridge also runs the whole kernel. For
comparison, the system ArkJS/JSVM engine on the same device is roughly 3-10x
faster (it JITs), so applications that need maximum performance on HarmonyOS
may prefer a JSVM backend. This package keeps a single cross-platform engine
(QuickJS) for behavioural consistency.

## Known limitations

- Only arm64-v8a native libraries are bundled; x86_64 emulators are not
  covered.
- The native bridge binary is the prebuilt community OHOS port (Apache-2.0,
  Hunan OpenValley / OpenHarmony ecosystem). It was symbol-checked against the
  QuickJS C API used by flutter_js 0.8.7.
- This repository has no OHOS CI runner; validation was done manually on a
  device.

## Upstreaming

The following pieces are candidates for upstream flutter_js:

1. optional jsSetMemoryLimit (works with trimmed community bridges);
2. a pluggable bridge loader extension point so platform packages can provide
   their own DynamicLibrary resolution;
3. a README link to this package as the community OHOS port.

The ohos/ plugin shell and the native bridge are intentionally kept in this
fork because upstream has no HarmonyOS toolchain in CI.

## License

MIT, same as upstream flutter_js. The OHOS native bridge in
ohos/libs/arm64-v8a/ originates from the Apache-2.0 community OHOS port.
