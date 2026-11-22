import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../js_eval_result.dart';

typedef _EvalNative = Int32 Function(
  Pointer<Uint8> src,
  IntPtr len,
  Pointer<Pointer<Uint8>> out,
);
typedef _EvalDart = int Function(
  Pointer<Uint8> src,
  int len,
  Pointer<Pointer<Uint8>> out,
);
typedef _FreeNative = Void Function(Pointer<Uint8> text);
typedef _FreeDart = void Function(Pointer<Uint8> text);
typedef _ResetNative = Void Function();
typedef _ResetDart = void Function();

/// Low-level FFI bridge to the OHOS JSVM C shim (libjsvm_bridge.so).
///
/// The shim wraps the ArkCompiler JSVM C API (OH_JSVM_Init / CreateVM /
/// CompileScript / RunScript) and exposes one synchronous evaluate call.
/// JSVM is the engine behind HarmonyOS ArkTS; it is not QuickJS.
class JsvmBridge {
  JsvmBridge._();

  static final JsvmBridge instance = JsvmBridge._();

  static bool debugEnabled = false;

  DynamicLibrary? _lib;
  _EvalDart? _eval;
  _FreeDart? _free;
  _ResetDart? _reset;
  bool _loaded = false;

  void _load() {
    if (_loaded) {
      return;
    }
    final List<String> candidates = <String>[];
    final String? envPath = Platform.environment['JSVM_BRIDGE_PATH'];
    if (envPath != null && envPath.isNotEmpty) {
      candidates.add(envPath);
    }
    candidates.add('libjsvm_bridge.so');
    try {
      for (final String line in File('/proc/self/maps').readAsLinesSync()) {
        final int marker = line.indexOf('/libflutter.so');
        if (marker > 0) {
          final int space = line.lastIndexOf(' ', marker);
          final String path = line.substring(space + 1);
          final String dir = path.substring(0, path.lastIndexOf('/'));
          candidates.add(dir + '/libjsvm_bridge.so');
          break;
        }
      }
    } catch (_) {
      // best effort
    }
    candidates.add('/data/storage/el1/bundle/libs/arm64/libjsvm_bridge.so');
    Object? lastError;
    for (final String path in candidates) {
      try {
        _lib = DynamicLibrary.open(path);
        break;
      } catch (e) {
        lastError = e;
      }
    }
    final DynamicLibrary? lib = _lib;
    if (lib == null) {
      throw StateError('JSVM bridge load failed: ' + lastError.toString());
    }
    _eval = lib.lookupFunction<_EvalNative, _EvalDart>('jsvm_bridge_eval');
    _free = lib.lookupFunction<_FreeNative, _FreeDart>('jsvm_bridge_free');
    _reset = lib.lookupFunction<_ResetNative, _ResetDart>('jsvm_bridge_reset');
    _loaded = true;
    if (debugEnabled) {
      print('[jsvm] bridge loaded');
    }
  }

  /// Runs [code] synchronously and returns its string result.
  JsEvalResult evaluate(String code) {
    _load();
    final Uint8List bytes = Uint8List.fromList(utf8.encode(code));
    final Pointer<Uint8> src = malloc<Uint8>(bytes.length + 1);
    src.asTypedList(bytes.length + 1).setRange(0, bytes.length, bytes);
    src[bytes.length] = 0;
    final Pointer<Pointer<Uint8>> out = malloc<Pointer<Uint8>>();
    out.value = nullptr;
    final int rc = _eval!(src, bytes.length, out);
    final Pointer<Uint8> raw = out.value;
    String text = '';
    if (raw != nullptr) {
      text = raw.cast<Utf8>().toDartString();
      _free!(raw);
    }
    malloc.free(src);
    malloc.free(out);
    bool isError = rc != 0;
    const String errorPrefix = '__JSVM_ERROR__:';
    if (text.startsWith(errorPrefix)) {
      isError = true;
      text = text.substring(errorPrefix.length);
    }
    return JsEvalResult(text, null, isError: isError);
  }

  void reset() {
    _load();
    _reset?.call();
  }
}
