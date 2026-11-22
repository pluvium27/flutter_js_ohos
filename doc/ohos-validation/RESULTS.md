# OHOS bridge validation (2026-11-22)

- Device: HUAWEI AST-W30 tablet, HarmonyOS 7.0.0.111, API 26, arm64.
- App: KiriMemo HAP built with Flutter OHOS 3.47.7-ohos-1.0.1, QuickJS runtime
  from this package.
- Kernel: heurams-core.js 307 KB, protocolVersion 2, 950 units, Chinese IR.

The bridge loaded from the HAP native libs directory and executed the whole
kernel. Core calls from the Dart side succeeded:

| Call | Result |
|---|---|
| load kernel | OK |
| inspectRepo (335 KB repo) | OK, ~3.1 s |
| overview | OK, ~57-91 ms |
| plan | OK, ~17 ms |
| createSession | OK, ~274 ms |

Notes:

- The bridge default stack is too small for recursive Lispite templates; the
  app creates the runtime with IsolateQjs(stackSize: 1024 * 1024).
- Only arm64 was tested.

Reproduce with any Flutter OHOS app that depends on this package, builds a HAP
with flutter build hap --debug --no-codesign, and logs kernel initialization.
