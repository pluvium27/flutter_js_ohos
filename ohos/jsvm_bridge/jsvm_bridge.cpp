#include "ark_runtime/jsvm.h"

#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace {
JSVM_VM g_vm = nullptr;
JSVM_Env g_env = nullptr;
JSVM_VMScope g_vmScope = nullptr;
JSVM_EnvScope g_envScope = nullptr;
bool g_engineInit = false;
bool g_vmReady = false;

bool InitVm() {
  if (g_vmReady) return true;
  if (!g_engineInit) {
    JSVM_InitOptions initOptions = {0};
    if (OH_JSVM_Init(&initOptions) != JSVM_OK) return false;
    g_engineInit = true;
  }
  if (OH_JSVM_CreateVM(nullptr, &g_vm) != JSVM_OK) return false;
  if (OH_JSVM_OpenVMScope(g_vm, &g_vmScope) != JSVM_OK) return false;
  if (OH_JSVM_CreateEnv(g_vm, 0, nullptr, &g_env) != JSVM_OK) return false;
  if (OH_JSVM_OpenEnvScope(g_env, &g_envScope) != JSVM_OK) return false;
  g_vmReady = true;
  return true;
}

bool CoerceToUtf8(JSVM_Value value, std::string* out) {
  JSVM_Value str = nullptr;
  if (OH_JSVM_CoerceToString(g_env, value, &str) != JSVM_OK) return false;
  size_t len = 0;
  if (OH_JSVM_GetValueStringUtf8(g_env, str, nullptr, 0, &len) != JSVM_OK) return false;
  std::vector<char> buf(len + 1, 0);
  size_t written = 0;
  if (OH_JSVM_GetValueStringUtf8(g_env, str, buf.data(), buf.size(), &written) != JSVM_OK) return false;
  out->assign(buf.data(), written);
  return true;
}

std::string TakeException() {
  JSVM_Value exc = nullptr;
  if (OH_JSVM_GetAndClearLastException(g_env, &exc) != JSVM_OK || exc == nullptr) {
    return "unknown JSVM exception";
  }
  std::string msg;
  if (!CoerceToUtf8(exc, &msg)) return "unprintable JSVM exception";
  return msg;
}

char* CopyString(const std::string& text) {
  char* buf = static_cast<char*>(malloc(text.size() + 1));
  if (buf == nullptr) return nullptr;
  if (!text.empty()) memcpy(buf, text.data(), text.size());
  buf[text.size()] = 0;
  return buf;
}
}  // namespace

extern "C" {

// Evaluate JS source. Returns 0 on success (out = UTF-8 result), 1 on JS error
// (out = "__JSVM_ERROR__:<message>"), 2 on VM init failure.
int jsvm_bridge_eval(const char* src, size_t len, char** out) {
  if (out == nullptr) return 3;
  *out = nullptr;
  if (!InitVm()) {
    *out = CopyString("__JSVM_ERROR__:jsvm init failed");
    return 2;
  }
  JSVM_HandleScope handleScope = nullptr;
  if (OH_JSVM_OpenHandleScope(g_env, &handleScope) != JSVM_OK) {
    *out = CopyString("__JSVM_ERROR__:open handle scope failed");
    return 2;
  }
  std::string result;
  bool ok = false;
  JSVM_Value jsSrc = nullptr;
  if (OH_JSVM_CreateStringUtf8(g_env, src, len, &jsSrc) == JSVM_OK) {
    JSVM_Script script = nullptr;
    if (OH_JSVM_CompileScript(g_env, jsSrc, nullptr, 0, true, nullptr, &script) == JSVM_OK) {
      JSVM_Value value = nullptr;
      if (OH_JSVM_RunScript(g_env, script, &value) == JSVM_OK) {
        ok = CoerceToUtf8(value, &result);
      }
    }
  }
  OH_JSVM_CloseHandleScope(g_env, handleScope);
  int rc = 0;
  if (!ok) {
    result = "__JSVM_ERROR__:" + TakeException();
    rc = 1;
  }
  *out = CopyString(result);
  return (*out == nullptr) ? 3 : rc;
}

void jsvm_bridge_free(char* text) { free(text); }

void jsvm_bridge_reset(void) {
  if (!g_vmReady) return;
  OH_JSVM_CloseEnvScope(g_env, g_envScope);
  OH_JSVM_DestroyEnv(g_env);
  OH_JSVM_CloseVMScope(g_vm, g_vmScope);
  OH_JSVM_DestroyVM(g_vm);
  g_env = nullptr;
  g_vm = nullptr;
  g_vmReady = false;
}
}  // extern "C"
