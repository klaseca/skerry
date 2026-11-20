///|
/// Owns the native target independently of the renderer using it.
priv struct SurfaceFactory {
  options : @runtime.WindowOptions
  mut window : @sdl_lib.Window?
  mut release : (() -> Unit raise)?
}

///|
fn SurfaceFactory::SurfaceFactory(
  options : @runtime.WindowOptions,
) -> SurfaceFactory {
  { options, window: None, release: None, }
}

///|
fn SurfaceFactory::dispose(self : Self) -> Unit raise {
  let release = self.release
  self.release = None
  self.window = None
  if release is Some(release) {
    release()
  }
}

///|
impl @backend.SurfaceFactory for SurfaceFactory with fn raster(self) {
  self.dispose()
  let window = create_window(self.options)
  errdefer window.destroy()
  let renderer = @sdl_lib.Renderer(window, name="software")
  errdefer renderer.destroy()
  let surface = RasterSurface(renderer)
  self.window = Some(window)
  self.release = Some(fn() {
    surface.destroy()
    renderer.destroy()
    window.destroy()
  })
  surface
}
