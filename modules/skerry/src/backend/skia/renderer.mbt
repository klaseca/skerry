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
