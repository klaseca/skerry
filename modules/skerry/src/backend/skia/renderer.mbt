///|
/// Create a Skia CPU renderer using memory provided by the backend's surface.
pub fn raster_renderer(
  factory : &@backend.SurfaceFactory,
) -> &@backend.Renderer raise {
  let target = factory.raster()
  let painter = Renderer()
  RasterFrame::{ painter, target, }
}

///|
priv struct RasterFrame {
  painter : Renderer
  target : &@backend.RasterSurface
}

///|
impl @backend.Renderer for RasterFrame with fn surface(self) {
  self.target
}

///|
impl @backend.Renderer for RasterFrame with fn text_layout_system(self) {
  self.painter.text_layout_system()
}

///|
impl @backend.Renderer for RasterFrame with fn render(
  self,
  root,
  width,
  height,
  scale,
  clear,
) {
  self.target.with_pixels(width, height, scale, target => {
    self.painter.render(root, target, clear)
  })
}

///|
impl @backend.Renderer for RasterFrame with fn dispose(self) {
  self.painter.dispose()
}

///|
impl @backend.Renderer for RasterFrame with fn name(_) {
  "Skia/CPU"
}

///|
/// Require OpenGL; report unsupported protocols or context initialization errors.
pub fn opengl_renderer(
  factory : &@backend.SurfaceFactory,
) -> &@backend.Renderer raise {
  let target = factory.opengl()
  target.make_current()
  let size = @backend.Surface::output_size(target)
  let info = target.framebuffer()
  let painter = GlRenderer(
    name => target.get_proc_address(name),
    width=size.width.max(1),
    height=size.height.max(1),
    framebuffer=info.id,
    samples=info.samples,
    stencil_bits=info.stencil_bits,
  )
  GlFrame::{ painter, target, }
}

///|
priv struct GlFrame {
  painter : GlRenderer
  target : &@backend.GlSurface
}

///|
impl @backend.Renderer for GlFrame with fn surface(self) {
  self.target
}

///|
impl @backend.Renderer for GlFrame with fn text_layout_system(self) {
  self.painter.text_layout_system()
}

///|
impl @backend.Renderer for GlFrame with fn render(
  self,
  root,
  width,
  height,
  scale,
  clear,
) {
  self.target.make_current()
  ignore(self.painter.resize(width, height))
  self.painter.render(root, scale, clear)
}

///|
impl @backend.Renderer for GlFrame with fn dispose(self) {
  // If the native context is lost, abandon Skia before its resources are freed.
  self.target.make_current() catch {
    _ => {
      self.painter.abandon()
      return
    }
  }
  self.painter.dispose()
}

///|
impl @backend.Renderer for GlFrame with fn name(_) {
  "Skia/OpenGL"
}

///|
fn Renderer::paint_gpu_frame(
  self : Self,
  canvas : @skia_lib.Canvas,
  root : @runtime.UiRoot,
  width : Int32,
  height : Int32,
  scale : Double,
  clear : @foundation.Color,
) -> Unit raise {
  ignore(canvas.save())
  defer canvas.restore()
  let factor = Float::from_double(scale)
  canvas.scale(factor, factor)
  self.draw(canvas, scene => {
    root.paint(
      scene,
      size=@foundation.Size(
        width=width.to_double() / scale,
        height=height.to_double() / scale,
      ),
      clear~,
    )
  })
}
