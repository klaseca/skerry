///|
priv struct D3d12Frame {
  painter : Renderer
  target : &@backend.D3d12Surface
  context : @skia_lib.D3d12Context
  mut width : Int32
  mut height : Int32
  mut buffers : Array[@skia_lib.Surface]
}

///|
priv suberror D3d12BackBufferUnavailable {
  D3d12BackBufferUnavailable
}

///|
/// Require a D3D12 presentation surface and a Skia build with D3D12 support.
pub fn d3d12_renderer(
  factory : &@backend.SurfaceFactory,
) -> &@backend.Renderer raise {
  let target = factory.d3d12()
  let device = target.device()
  let context = @skia_lib.D3d12Context(
    adapter=d3d12_pointer(device.adapter),
    device=d3d12_pointer(device.device),
    queue=d3d12_pointer(device.queue),
  )
  errdefer context.dispose()
  let painter = Renderer()
  errdefer painter.dispose()
  let size = @backend.Surface::output_size(target)
  let width = size.width.max(1)
  let height = size.height.max(1)
  let buffers = wrap_d3d12_buffers(target, context, width, height)
  D3d12Frame::{ painter, target, context, width, height, buffers, }
}

///|
fn d3d12_pointer(handle : @backend.D3d12Handle) -> @skia_sys.Pointer = "%identity"

///|
fn wrap_d3d12_buffers(
  target : &@backend.D3d12Surface,
  context : @skia_lib.D3d12Context,
  width : Int32,
  height : Int32,
) -> Array[@skia_lib.Surface] raise {
  let buffers = target.buffers(width, height)
  guard !buffers.is_empty() else { raise D3d12BackBufferUnavailable }
  let wrapped : Array[@skia_lib.Surface] = []
  errdefer (for surface in wrapped {
    surface.dispose()
  })
  for buffer in buffers {
    wrapped.push(context.surface(d3d12_pointer(buffer), width~, height~))
  }
  wrapped
}

///|
fn D3d12Frame::release_buffers(self : Self) -> Unit {
  for buffer in self.buffers {
    buffer.dispose()
  }
  self.buffers.clear()
}

///|
impl @backend.Renderer for D3d12Frame with fn surface(self) {
  self.target
}

///|
impl @backend.Renderer for D3d12Frame with fn text_layout_system(self) {
  self.painter.text_layout_system()
}

///|
impl @backend.Renderer for D3d12Frame with fn render(
  self,
  root,
  width,
  height,
  scale,
  clear,
) {
  if self.width != width || self.height != height {
    self.context.sync()
    self.release_buffers()
    self.buffers = wrap_d3d12_buffers(self.target, self.context, width, height)
    self.width = width
    self.height = height
  }
  let index = self.target.acquire()
  guard self.buffers.get(index) is Some(buffer) else {
    raise D3d12BackBufferUnavailable
  }
  self.painter.paint_gpu_frame(
    buffer.canvas(),
    root,
    width,
    height,
    scale,
    clear,
  )
  self.context.flush_for_present(buffer)
}

///|
impl @backend.Renderer for D3d12Frame with fn dispose(self) {
  self.painter.dispose()
  self.release_buffers()
  self.context.dispose()
}

///|
impl @backend.Renderer for D3d12Frame with fn name(_) {
  "Skia/D3D12"
}
