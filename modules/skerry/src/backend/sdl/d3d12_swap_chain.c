#include <moonbit.h>
#include <stdlib.h>

#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#define COBJMACROS
#include <windows.h>
#include <initguid.h>
#include <d3d12.h>
#include <dxgi1_4.h>

#pragma comment(lib, "dxgi.lib")

enum { buffer_count = 2 };

typedef struct {
  HMODULE library;
  IDXGIAdapter1 *adapter;
  ID3D12Device *device;
  ID3D12CommandQueue *queue;
  IDXGISwapChain3 *chain;
  ID3D12Resource *buffers[buffer_count];
  ID3D12Fence *fence;
  HANDLE completion;
  UINT64 submitted[buffer_count];
  UINT64 serial;
  int32_t width;
  int32_t height;
} D3d12SwapChain;

static HRESULT wait_for(D3d12SwapChain *target, UINT64 serial) {
  HRESULT result = ID3D12Device_GetDeviceRemovedReason(target->device);
  if (FAILED(result)) return result;
  UINT64 completed = ID3D12Fence_GetCompletedValue(target->fence);
  if (completed == UINT64_MAX) return DXGI_ERROR_DEVICE_REMOVED;
  if (completed >= serial) return S_OK;
  result = ID3D12Fence_SetEventOnCompletion(target->fence, serial, target->completion);
  if (FAILED(result)) return result;
  DWORD status = WaitForSingleObject(target->completion, 5000);
  if (status == WAIT_FAILED) return HRESULT_FROM_WIN32(GetLastError());
  if (status != WAIT_OBJECT_0) return HRESULT_FROM_WIN32(ERROR_TIMEOUT);
  result = ID3D12Device_GetDeviceRemovedReason(target->device);
  if (FAILED(result)) return result;
  return ID3D12Fence_GetCompletedValue(target->fence) >= serial ? S_OK : E_FAIL;
}

static void release_buffers(D3d12SwapChain *target) {
  for (UINT index = 0; index < buffer_count; ++index) {
    if (target->buffers[index] != NULL) {
      ID3D12Resource_Release(target->buffers[index]);
      target->buffers[index] = NULL;
    }
  }
}

static HRESULT get_buffers(D3d12SwapChain *target, int32_t width, int32_t height) {
  for (UINT index = 0; index < buffer_count; ++index) {
    HRESULT result = IDXGISwapChain3_GetBuffer(
        target->chain, index, &IID_ID3D12Resource, (void **)&target->buffers[index]);
    if (FAILED(result)) {
      release_buffers(target);
      return result;
    }
  }
  target->width = width;
  target->height = height;
  return S_OK;
}

MOONBIT_FFI_EXPORT
void moonbit_skerry_d3d12_destroy(D3d12SwapChain *target) {
  if (target == NULL) return;
  if (target->serial != 0) wait_for(target, target->serial);
  release_buffers(target);
  if (target->chain) IDXGISwapChain3_Release(target->chain);
  if (target->fence) ID3D12Fence_Release(target->fence);
  if (target->completion) CloseHandle(target->completion);
  if (target->queue) ID3D12CommandQueue_Release(target->queue);
  if (target->device) ID3D12Device_Release(target->device);
  if (target->adapter) IDXGIAdapter1_Release(target->adapter);
  if (target->library) FreeLibrary(target->library);
  free(target);
}

static HRESULT create_device(D3d12SwapChain *target, IDXGIFactory4 *factory) {
  target->library = LoadLibraryExW(L"d3d12.dll", NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (target->library == NULL) return HRESULT_FROM_WIN32(GetLastError());
  PFN_D3D12_CREATE_DEVICE create = (PFN_D3D12_CREATE_DEVICE)
      GetProcAddress(target->library, "D3D12CreateDevice");
  if (create == NULL) return HRESULT_FROM_WIN32(GetLastError());

  for (UINT index = 0;; ++index) {
    IDXGIAdapter1 *adapter = NULL;
    HRESULT result = IDXGIFactory4_EnumAdapters1(factory, index, &adapter);
    if (result == DXGI_ERROR_NOT_FOUND) return DXGI_ERROR_UNSUPPORTED;
    if (FAILED(result)) return result;
    DXGI_ADAPTER_DESC1 desc;
    if (SUCCEEDED(IDXGIAdapter1_GetDesc1(adapter, &desc)) &&
        !(desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) &&
        SUCCEEDED(create((IUnknown *)adapter, D3D_FEATURE_LEVEL_11_0,
                         &IID_ID3D12Device, (void **)&target->device))) {
      target->adapter = adapter;
      break;
    }
    IDXGIAdapter1_Release(adapter);
  }

  const D3D12_COMMAND_QUEUE_DESC queue = { .Type = D3D12_COMMAND_LIST_TYPE_DIRECT };
  HRESULT result = ID3D12Device_CreateCommandQueue(
      target->device, &queue, &IID_ID3D12CommandQueue, (void **)&target->queue);
  if (FAILED(result)) return result;
  result = ID3D12Device_CreateFence(
      target->device, 0, D3D12_FENCE_FLAG_NONE, &IID_ID3D12Fence, (void **)&target->fence);
  if (FAILED(result)) return result;
  target->completion = CreateEventW(NULL, FALSE, FALSE, NULL);
  return target->completion != NULL ? S_OK : HRESULT_FROM_WIN32(GetLastError());
}

static HRESULT create_swap_chain(D3d12SwapChain *target, IDXGIFactory4 *factory,
                                 HWND hwnd, int32_t width, int32_t height) {
  const DXGI_SWAP_CHAIN_DESC1 desc = {
    .Width = (UINT)width,
    .Height = (UINT)height,
    .Format = DXGI_FORMAT_R8G8B8A8_UNORM,
    .SampleDesc = { .Count = 1 },
    .BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT,
    .BufferCount = buffer_count,
    // Keep the previous frame at its rendered size during live resize.
    .Scaling = DXGI_SCALING_NONE,
    .SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD,
  };
  IDXGISwapChain1 *chain = NULL;
  HRESULT result = IDXGIFactory4_CreateSwapChainForHwnd(
      factory, (IUnknown *)target->queue, hwnd, &desc, NULL, NULL, &chain);
  if (FAILED(result)) return result;
  result = IDXGISwapChain1_QueryInterface(chain, &IID_IDXGISwapChain3, (void **)&target->chain);
  IDXGISwapChain1_Release(chain);
  if (FAILED(result)) return result;
  result = IDXGIFactory4_MakeWindowAssociation(factory, hwnd, DXGI_MWA_NO_ALT_ENTER);
  if (FAILED(result)) return result;
  return get_buffers(target, width, height);
}

MOONBIT_FFI_EXPORT
D3d12SwapChain *moonbit_skerry_d3d12_create(
    HWND hwnd, int32_t width, int32_t height, int32_t *status) {
  if (hwnd == NULL || width <= 0 || height <= 0) {
    *status = E_INVALIDARG;
    return NULL;
  }
  D3d12SwapChain *target = calloc(1, sizeof(*target));
  if (target == NULL) {
    *status = E_OUTOFMEMORY;
    return NULL;
  }
  IDXGIFactory4 *factory = NULL;
  HRESULT result = CreateDXGIFactory1(&IID_IDXGIFactory4, (void **)&factory);
  if (SUCCEEDED(result)) result = create_device(target, factory);
  if (SUCCEEDED(result)) result = create_swap_chain(target, factory, hwnd, width, height);
  if (factory != NULL) IDXGIFactory4_Release(factory);
  *status = result;
  if (FAILED(result)) {
    moonbit_skerry_d3d12_destroy(target);
    return NULL;
  }
  return target;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_skerry_d3d12_resize(D3d12SwapChain *target, int32_t width, int32_t height) {
  if (width <= 0 || height <= 0) return E_INVALIDARG;
  if (target->width == width && target->height == height) return S_OK;
  HRESULT result = wait_for(target, target->serial);
  if (FAILED(result)) return result;
  release_buffers(target);
  target->width = 0;
  target->height = 0;
  result = IDXGISwapChain3_ResizeBuffers(
      target->chain, 0, (UINT)width, (UINT)height, DXGI_FORMAT_UNKNOWN, 0);
  if (FAILED(result)) return result;
  return get_buffers(target, width, height);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_skerry_d3d12_acquire(D3d12SwapChain *target, int32_t *index) {
  UINT current = IDXGISwapChain3_GetCurrentBackBufferIndex(target->chain);
  *index = (int32_t)current;
  return wait_for(target, target->submitted[current]);
}

MOONBIT_FFI_EXPORT
int32_t moonbit_skerry_d3d12_present(D3d12SwapChain *target) {
  UINT index = IDXGISwapChain3_GetCurrentBackBufferIndex(target->chain);
  // UINT64_MAX is reserved for device removal. Reset the timeline only when idle.
  if (target->serial == UINT64_MAX - 1) {
    HRESULT result = wait_for(target, target->serial);
    if (FAILED(result)) return result;
    result = ID3D12Fence_Signal(target->fence, 0);
    if (FAILED(result)) return result;
    target->serial = 0;
    for (UINT i = 0; i < buffer_count; ++i) target->submitted[i] = 0;
  }
  HRESULT present = IDXGISwapChain3_Present(target->chain, 1, 0);
  UINT64 serial = target->serial + 1;
  HRESULT result = ID3D12CommandQueue_Signal(target->queue, target->fence, serial);
  if (FAILED(result)) return result;
  target->submitted[index] = target->serial = serial;
  return FAILED(present) ? present : ID3D12Device_GetDeviceRemovedReason(target->device);
}

MOONBIT_FFI_EXPORT
void *moonbit_skerry_d3d12_adapter(D3d12SwapChain *target) { return target->adapter; }

MOONBIT_FFI_EXPORT
void *moonbit_skerry_d3d12_device(D3d12SwapChain *target) { return target->device; }

MOONBIT_FFI_EXPORT
void *moonbit_skerry_d3d12_queue(D3d12SwapChain *target) { return target->queue; }

MOONBIT_FFI_EXPORT
void *moonbit_skerry_d3d12_buffer(D3d12SwapChain *target, int32_t index) {
  return target->buffers[index];
}

#else

MOONBIT_FFI_EXPORT
void *moonbit_skerry_d3d12_create(void *hwnd, int32_t width, int32_t height, int32_t *status) {
  (void)hwnd;
  (void)width;
  (void)height;
  *status = -1;
  return NULL;
}

MOONBIT_FFI_EXPORT
void moonbit_skerry_d3d12_destroy(void *target) { (void)target; }

MOONBIT_FFI_EXPORT
int32_t moonbit_skerry_d3d12_resize(void *target, int32_t width, int32_t height) {
  (void)target;
  (void)width;
  (void)height;
  return -1;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_skerry_d3d12_acquire(void *target, int32_t *index) {
  (void)target;
  (void)index;
  return -1;
}

MOONBIT_FFI_EXPORT
int32_t moonbit_skerry_d3d12_present(void *target) { (void)target; return -1; }

MOONBIT_FFI_EXPORT
void *moonbit_skerry_d3d12_adapter(void *target) { (void)target; return NULL; }

MOONBIT_FFI_EXPORT
void *moonbit_skerry_d3d12_device(void *target) { (void)target; return NULL; }

MOONBIT_FFI_EXPORT
void *moonbit_skerry_d3d12_queue(void *target) { (void)target; return NULL; }

MOONBIT_FFI_EXPORT
void *moonbit_skerry_d3d12_buffer(void *target, int32_t index) {
  (void)target;
  (void)index;
  return NULL;
}

#endif
