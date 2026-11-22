///|
priv struct D3d12Surface {
  window : @sdl_lib.Window
  swap_chain : D3d12SwapChain
}

///|
priv suberror D3d12PresentationFailed {
  D3d12PresentationFailed(operation~ : String, code~ : Int32)
}

///|
fn check_d3d12(code : Int32, operation : String) -> Unit raise {
  if code < 0 {
    raise D3d12PresentationFailed(operation~, code~)
  }
}

///|
fn D3d12Surface::D3d12Surface(
  options : @runtime.WindowOptions,
) -> D3d12Surface raise {
  let window = create_window(options)
  errdefer window.destroy()
  let hwnd = @sdl_sys.get_pointer_property(
    @sdl_sys.get_window_properties(window.raw()),
    @sdl_sys.PROP_WINDOW_WIN32_HWND_POINTER,
    @sdl_sys.Pointer::null(),
  )
  guard !hwnd.is_null() else { raise @backend.UnsupportedSurface("D3D12") }
  let size = window.size_in_pixels()
  let status = Ref(0)
  let swap_chain = d3d12_create(
    hwnd,
    size.width.max(1),
    size.height.max(1),
    status,
  )
  check_d3d12(status.val, "create swap chain")
  { window, swap_chain, }
}

///|
fn D3d12Surface::destroy(self : Self) -> Unit {
  defer self.window.destroy()
  d3d12_destroy(self.swap_chain)
}

///|
impl @backend.Surface for D3d12Surface with fn output_size(self) {
  let size = self.window.size_in_pixels()
  { width: size.width, height: size.height, }
}

///|
impl @backend.Surface for D3d12Surface with fn resize(_, _, _, _) {
  // The renderer releases its views before it requests new buffers.
  false
}

///|
impl @backend.Surface for D3d12Surface with fn present(self, _, _) {
  check_d3d12(d3d12_present(self.swap_chain), "present")
}

///|
impl @backend.Surface for D3d12Surface with fn restore(_, _, _) {
  false
}

///|
impl @backend.D3d12Surface for D3d12Surface with fn device(self) {
  {
    adapter: d3d12_adapter(self.swap_chain),
    device: d3d12_device(self.swap_chain),
    queue: d3d12_queue(self.swap_chain),
  }
}

///|
impl @backend.D3d12Surface for D3d12Surface with fn buffers(self, width, height) {
  check_d3d12(d3d12_resize(self.swap_chain, width, height), "resize swap chain")
  [d3d12_buffer(self.swap_chain, 0), d3d12_buffer(self.swap_chain, 1)]
}

///|
impl @backend.D3d12Surface for D3d12Surface with fn acquire(self) {
  let index = Ref(0)
  check_d3d12(d3d12_acquire(self.swap_chain, index), "acquire back buffer")
  index.val
}

///|
#external
priv type D3d12SwapChain

///|
#borrow(status)
extern "c" fn d3d12_create(
  hwnd : @sdl_sys.Pointer,
  width : Int32,
  height : Int32,
  status : Ref[Int32],
) -> D3d12SwapChain = "moonbit_skerry_d3d12_create"

///|
extern "c" fn d3d12_destroy(chain : D3d12SwapChain) = "moonbit_skerry_d3d12_destroy"

///|
extern "c" fn d3d12_resize(
  chain : D3d12SwapChain,
  width : Int32,
  height : Int32,
) -> Int32 = "moonbit_skerry_d3d12_resize"

///|
#borrow(index)
extern "c" fn d3d12_acquire(
  chain : D3d12SwapChain,
  index : Ref[Int32],
) -> Int32 = "moonbit_skerry_d3d12_acquire"

///|
extern "c" fn d3d12_present(chain : D3d12SwapChain) -> Int32 = "moonbit_skerry_d3d12_present"

///|
extern "c" fn d3d12_adapter(chain : D3d12SwapChain) -> @backend.D3d12Handle = "moonbit_skerry_d3d12_adapter"

///|
extern "c" fn d3d12_device(chain : D3d12SwapChain) -> @backend.D3d12Handle = "moonbit_skerry_d3d12_device"

///|
extern "c" fn d3d12_queue(chain : D3d12SwapChain) -> @backend.D3d12Handle = "moonbit_skerry_d3d12_queue"

///|
extern "c" fn d3d12_buffer(
  chain : D3d12SwapChain,
  index : Int32,
) -> @backend.D3d12Handle = "moonbit_skerry_d3d12_buffer"
