import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import '../javascript_runtime.dart';
import '../js_eval_result.dart';
import 'ffi.dart';

/// JSVM (HarmonyOS ArkCompiler) backend for flutter_js.
///
/// This runtime uses the system JSVM through a small C shim
/// (libjsvm_bridge.so). It supports synchronous script evaluation, which is
/// enough for the KiriMemo kernel (Dart -> JS -> JSON string). It does not
/// implement the native QuickJS value model, Dart channel callbacks, or JS
/// timers/promises; those methods throw or are no-ops.
class JsvmRuntime extends JavascriptRuntime {
  JsvmRuntime() {
    init();
  }

  static int _sequence = 0;
  final int _id = ++_sequence;
  bool _disposed = false;

  @override
  JavascriptRuntime init() {
    initChannelFunctions();
    return this;
  }

  @override
  void initChannelFunctions() {
    JavascriptRuntime.channelFunctionsRegistered[getEngineInstanceId()] =
        <String, Function(dynamic)>{};
    evaluate("""
      if (typeof globalThis === 'undefined') { var globalThis = this; }
      if (typeof globalThis.console === 'undefined') {
        globalThis.console = {
          log: function() {},
          warn: function() {},
          error: function() {}
        };
      }
      if (typeof globalThis.sendMessage !== 'function') {
        globalThis.sendMessage = function(channelName, args, uuid) {};
      }
      if (typeof globalThis.setTimeout !== 'function') {
        globalThis.setTimeout = function(fn, timeout) { return 0; };
      }
    """);
  }

  @override
  JsEvalResult evaluate(String code, {String? sourceUrl}) {
    return JsvmBridge.instance.evaluate(code);
  }

  @override
  Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl}) {
    return Future<JsEvalResult>.value(evaluate(code, sourceUrl: sourceUrl));
  }

  @override
  JsEvalResult callFunction(Pointer<NativeType> fn, Pointer<NativeType> obj) {
    throw UnsupportedError(
      'JSVM backend does not expose QuickJS native values',
    );
  }

  @override
  T? convertValue<T>(JsEvalResult jsValue) {
    if (jsValue.rawResult is T) {
      return jsValue.rawResult as T?;
    }
    final String text = jsValue.stringResult;
    if (T == String) {
      return text as T?;
    }
    try {
      final dynamic value = jsonDecode(text);
      if (value is T) {
        return value;
      }
    } catch (_) {
      // not JSON
    }
    return null;
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    JsvmBridge.instance.reset();
  }

  @override
  int executePendingJob() => 0;

  @override
  String getEngineInstanceId() => 'jsvm-' + _id.toString();

  @override
  String jsonStringify(JsEvalResult jsValue) => jsValue.stringResult;

  @override
  bool setupBridge(String channelName, void Function(dynamic args) fn) {
    final Map<String, Function(dynamic)>? callbacks =
        JavascriptRuntime.channelFunctionsRegistered[getEngineInstanceId()];
    if (callbacks == null) {
      return false;
    }
    callbacks[channelName] = fn;
    return true;
  }

  @override
  void setInspectable(bool inspectable) {}

  @override
  void sendMessage({
    required String channelName,
    required List<String> args,
    String? uuid,
  }) {
    // JSVM backend has no host callback bridge; messages are dropped.
  }
}
