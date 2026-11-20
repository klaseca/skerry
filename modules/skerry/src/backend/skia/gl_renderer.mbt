///|
/// Skia Ganesh rendering into the current window's OpenGL framebuffer.
/// The host owns the native context and swaps buffers after render returns.
priv struct GlRenderer {
  renderer : Renderer
  context : @skia_lib.GlContext
  mut surface : @skia_lib.GlSurface
  mut width : Int32
  mut height : Int32
  samples : Int32
  stencil_bits : Int32
  framebuffer : UInt32
  mut disposed : Bool
}

///|
fn GlRenderer::GlRenderer(
  width~ : Int32,
  height~ : Int32,
  framebuffer~ : UInt32 = 0,
  samples~ : Int32 = 0,
  stencil_bits~ : Int32 = 8,
) -> GlRenderer raise {
  let context = @skia_lib.GlContext()
  errdefer context.dispose()
  let renderer = Renderer()
  errdefer renderer.dispose()
  let surface = context.surface(
    width~,
    height~,
    framebuffer~,
    samples~,
    stencil_bits~,
  )
  {
    renderer,
    context,
    surface,
    width,
    height,
    samples,
    stencil_bits,
    framebuffer,
    disposed: false,
  }
}

///|
fn GlRenderer::text_layout_system(self : Self) -> @text.TextLayoutSystem {
  self.renderer.text_layout_system()
}

///|
/// Rewrap the window framebuffer when its physical pixel extent changes.
fn GlRenderer::resize(self : Self, width : Int32, height : Int32) -> Bool raise {
  guard !self.disposed else { raise @skia_lib.GlContextAbandoned }
  if width == self.width && height == self.height {
    return false
  }
  let surface = self.context.surface(
    width~,
    height~,
    samples=self.samples,
    stencil_bits=self.stencil_bits,
    framebuffer=self.framebuffer,
  )
  self.surface.dispose()
  self.surface = surface
  self.width = width
  self.height = height
  true
}

///|
fn GlRenderer::render(
  self : Self,
  root : @runtime.UiRoot,
  scale : Double,
  clear : @foundation.Color,
) -> Unit raise {
  guard !self.disposed else { raise @skia_lib.GlContextAbandoned }
  let canvas = self.surface.canvas()
  ignore(canvas.save())
  defer canvas.restore()
  let factor = Float::from_double(scale)
  canvas.scale(factor, factor)
  self.renderer.draw(canvas, scene => {
    root.paint(
      scene,
      size=@foundation.Size(
        width=self.width.to_double() / scale,
        height=self.height.to_double() / scale,
      ),
      clear~,
    )
  })
  self.context.flush()
}

///|
/// Dispose before the native OpenGL context, while it is still current.
fn GlRenderer::dispose(self : Self) -> Unit {
  guard !self.disposed else { return }
  self.disposed = true
  self.renderer.dispose()
  self.surface.dispose()
  self.context.dispose()
}

///|
/// Terminal cleanup when the host can no longer make the GL context current.
fn GlRenderer::abandon(self : Self) -> Unit {
  guard !self.disposed else { return }
  self.context.abandon()
  self.dispose()
}
