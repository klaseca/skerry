///|
priv struct GlSurface {
  window : @sdl_lib.Window
  context : @sdl_lib.GlContext
  framebuffer : @backend.GlFramebuffer
}

///|
fn GlSurface::GlSurface(options : @runtime.WindowOptions) -> GlSurface raise {
  @sdl_sys.gl_reset_attributes()
  defer @sdl_sys.gl_reset_attributes()
  for
    (attribute, value) in [
      (@sdl_sys.GL_CONTEXT_MAJOR_VERSION, 3),
      (@sdl_sys.GL_CONTEXT_MINOR_VERSION, 2),
      (@sdl_sys.GL_CONTEXT_PROFILE_MASK, @sdl_sys.GL_CONTEXT_PROFILE_CORE),
      (@sdl_sys.GL_CONTEXT_FLAGS, @sdl_sys.GL_CONTEXT_FORWARD_COMPATIBLE_FLAG),
      (@sdl_sys.GL_RED_SIZE, 8),
      (@sdl_sys.GL_GREEN_SIZE, 8),
      (@sdl_sys.GL_BLUE_SIZE, 8),
      (@sdl_sys.GL_ALPHA_SIZE, 8),
      (@sdl_sys.GL_STENCIL_SIZE, 8),
      (@sdl_sys.GL_DEPTH_SIZE, 0),
      (@sdl_sys.GL_DOUBLEBUFFER, 1),
      (@sdl_sys.GL_MULTISAMPLEBUFFERS, 0),
      (@sdl_sys.GL_MULTISAMPLESAMPLES, 0),
    ] {
    if !@sdl_sys.gl_set_attribute(attribute, value) {
      raise_gl_error("SDL_GL_SetAttribute")
    }
  }
  let window = create_window(options, opengl=true)
  errdefer window.destroy()
  let context = @sdl_lib.GlContext(window)
  errdefer context.destroy()
  context.make_current()
  // Some drivers do not expose configurable vsync. This does not prevent GPU
  // rendering; the event-driven host still sleeps when there is no UI work.
  context.set_swap_interval(1) catch {
    _ => ()
  }
  for
    attribute in [
      @sdl_sys.GL_RED_SIZE,
      @sdl_sys.GL_GREEN_SIZE,
      @sdl_sys.GL_BLUE_SIZE,
      @sdl_sys.GL_ALPHA_SIZE,
    ] {
    if gl_attribute(attribute) != 8 {
      raise @sdl_lib.SdlError(
        "OpenGL presentation requires an RGBA8 framebuffer",
      )
    }
  }
  let samples = gl_attribute(@sdl_sys.GL_MULTISAMPLESAMPLES)
  let stencil_bits = gl_attribute(@sdl_sys.GL_STENCIL_SIZE)
  { window, context, framebuffer: { id: 0, samples, stencil_bits, }, }
}

///|
fn GlSurface::destroy(self : Self) -> Unit raise {
  defer self.window.destroy()
  self.context.destroy()
}

///|
impl @backend.Surface for GlSurface with fn output_size(self) {
  let size = self.window.size_in_pixels()
  { width: size.width, height: size.height, }
}

///|
impl @backend.Surface for GlSurface with fn resize(
  _self,
  _width,
  _height,
  _allow_shrink,
) {
  false
}

///|
impl @backend.Surface for GlSurface with fn present(self, _width, _height) {
  self.context.swap()
}

///|
impl @backend.Surface for GlSurface with fn restore(_self, _width, _height) {
  false
}

///|
impl @backend.GlSurface for GlSurface with fn make_current(self) {
  self.context.make_current()
}

///|
impl @backend.GlSurface for GlSurface with fn framebuffer(self) {
  self.framebuffer
}

///|
fn gl_attribute(attribute : Int32) -> Int32 raise {
  let value = Ref(0)
  if !@sdl_sys.gl_get_attribute(attribute, value) {
    raise_gl_error("SDL_GL_GetAttribute")
  }
  value.val
}

///|
fn raise_gl_error(operation : String) -> Unit raise @sdl_lib.SdlError {
  raise @sdl_lib.SdlError(
    "\{operation}: \{@utf8.decode_lossy(@sdl_sys.get_error())}",
  )
}
