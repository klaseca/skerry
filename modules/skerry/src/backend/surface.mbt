///|
/// Physical pixel extent, independent of a windowing library.
pub(all) struct PixelSize {
  width : Int32
  height : Int32
}

///|
/// Window-system presentation resources. The backend owns their lifetime.
/// resize returns true if the previous frame was invalidated (for example, when
/// shrinking a CPU texture). restore returns false if an expose needs repaint.
pub(open) trait Surface {
  fn output_size(Self) -> PixelSize raise
  fn resize(Self, Int32, Int32, Bool) -> Bool raise
  fn present(Self, Int32, Int32) -> Unit raise
  fn restore(Self, Int32, Int32) -> Bool raise
}

///|
pub(open) trait RasterSurface: Surface {
  /// Memory is writable only for the duration of the callback.
  fn with_pixels(Self, Int32, Int32, Double, (RasterTarget) -> Unit raise) -> Unit raise
}

///|
/// The current RGBA8 OpenGL framebuffer, with its actual native attributes.
pub(all) struct GlFramebuffer {
  id : UInt32
  samples : Int32
  stencil_bits : Int32
}

///|
pub(open) trait GlSurface: Surface {
  fn make_current(Self) -> Unit raise
  fn framebuffer(Self) -> GlFramebuffer
  fn get_proc_address(Self, Bytes) -> FuncRef[() -> Unit]
}

///|
/// Borrowed COM pointer. Its lifetime is tied to the providing surface.
#external
pub type D3d12Handle

///|
pub(all) struct D3d12Device {
  adapter : D3d12Handle
  device : D3d12Handle
  queue : D3d12Handle
}

///|
/// The host owns the device, graphics queue and RGBA8 swap chain. The renderer
/// wraps the borrowed back buffers and submits to that same queue before present.
pub(open) trait D3d12Surface: Surface {
  fn device(Self) -> D3d12Device
  /// Returns the buffers at the requested physical size, replacing them if
  /// necessary. Release any renderer views before requesting a different size.
  fn buffers(Self, Int32, Int32) -> Array[D3d12Handle] raise
  /// Waits for the current buffer to be reusable and returns its index.
  fn acquire(Self) -> Int32 raise
}

///|
/// Renderers request a supported presentation protocol before App::mount.
/// Returned surfaces are borrowed from the backend until it is disposed or
/// another surface is requested. Failed renderer initialization must release
/// renderer resources before attempting another protocol on this factory.
pub(open) trait SurfaceFactory {
  fn raster(Self) -> &RasterSurface raise = _
  fn opengl(Self) -> &GlSurface raise = _
  fn d3d12(Self) -> &D3d12Surface raise = _
}

///|
impl SurfaceFactory with fn raster(_) {
  raise UnsupportedSurface("raster")
}

///|
impl SurfaceFactory with fn opengl(_) {
  raise UnsupportedSurface("OpenGL")
}

///|
impl SurfaceFactory with fn d3d12(_) {
  raise UnsupportedSurface("D3D12")
}

///|
pub(all) suberror SurfaceError {
  UnsupportedSurface(String)
}

///|
/// A renderer attached to a backend-owned surface. Its drawing resources are
/// disposed before the backend releases the native context and window.
pub(open) trait Renderer {
  fn surface(Self) -> &Surface
  fn text_layout_system(Self) -> @text.TextLayoutSystem
  fn render(Self, @runtime.UiRoot, Int32, Int32, Double, @foundation.Color) -> Unit raise
  /// Release renderer-owned resources while its surface is still alive.
  fn dispose(Self) -> Unit
  /// Identifies the renderer in diagnostics.
  fn name(Self) -> String
}
