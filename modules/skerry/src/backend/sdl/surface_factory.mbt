///|
/// Owns the native target, independently of the renderer using it. A new
/// request releases the previous target after failed renderer initialization.
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

///|
impl @backend.SurfaceFactory for SurfaceFactory with fn opengl(self) {
  self.dispose()
  let surface = GlSurface(self.options)
  self.window = Some(surface.window)
  self.release = Some(() => surface.destroy())
  surface
}

///|
impl @backend.SurfaceFactory for SurfaceFactory with fn d3d12(self) {
  self.dispose()
  let surface = D3d12Surface(self.options)
  self.window = Some(surface.window)
  self.release = Some(() => surface.destroy())
  surface
}
