///|
const TEXTURE_CAPACITY_STEP : Int32 = 256

///|
priv struct RasterSurface {
  sdl_renderer : @sdl_lib.Renderer
  mut texture : @sdl_lib.Texture
  mut texture_width : Int32
  mut texture_height : Int32
}

///|
fn RasterSurface::RasterSurface(
  sdl_renderer : @sdl_lib.Renderer,
) -> RasterSurface raise {
  let size = sdl_renderer.output_size()
  let width = size.width.max(1)
  let height = size.height.max(1)
  {
    sdl_renderer,
    texture: create_texture(sdl_renderer, width, height),
    texture_width: width,
    texture_height: height,
  }
}

///|
impl @backend.Surface for RasterSurface with fn output_size(self) {
  let size = self.sdl_renderer.output_size()
  { width: size.width, height: size.height, }
}

///|
impl @backend.Surface for RasterSurface with fn resize(
  self,
  width,
  height,
  allow_shrink,
) {
  self.sync_texture_size(width, height, allow_shrink)
}

///|
impl @backend.RasterSurface for RasterSurface with fn with_pixels(
  self,
  width,
  height,
  scale,
  paint,
) {
  with_texture_pixels(self.texture, width, height, paint, scale~)
}

///|
impl @backend.Surface for RasterSurface with fn present(self, width, height) {
  present_texture(
    self.sdl_renderer,
    self.texture,
    source_width=width,
    source_height=height,
    width~,
    height~,
  )
}

///|
impl @backend.Surface for RasterSurface with fn restore(self, width, height) {
  @backend.Surface::present(self, width, height)
  true
}

///|
fn RasterSurface::destroy(self : Self) -> Unit {
  self.texture.destroy()
}

///|
fn RasterSurface::sync_texture_size(
  self : RasterSurface,
  width : Int32,
  height : Int32,
  allow_shrink : Bool,
) -> Bool raise {
  let shrink = allow_shrink &&
    (
      self.texture_width - width >= TEXTURE_CAPACITY_STEP ||
      self.texture_height - height >= TEXTURE_CAPACITY_STEP
    )
  let texture_width = if shrink {
    width
  } else {
    grow_capacity(self.texture_width, width)
  }
  let texture_height = if shrink {
    height
  } else {
    grow_capacity(self.texture_height, height)
  }
  if texture_width == self.texture_width &&
    texture_height == self.texture_height {
    false
  } else {
    // Keep the current frame intact if allocating its replacement fails.
    let texture = create_texture(
      self.sdl_renderer,
      texture_width,
      texture_height,
    )
    let old_texture = self.texture
    self.texture = texture
    self.texture_width = texture_width
    self.texture_height = texture_height
    old_texture.destroy()
    true
  }
}

///|
fn grow_capacity(current : Int32, required : Int32) -> Int32 {
  if required <= current {
    current
  } else {
    let remainder = required % TEXTURE_CAPACITY_STEP
    if remainder == 0 {
      required
    } else {
      let extra = TEXTURE_CAPACITY_STEP - remainder
      if required > @int.MAX_VALUE - extra {
        required
      } else {
        required + extra
      }
    }
  }
}

///|
fn create_texture(
  renderer : @sdl_lib.Renderer,
  width : Int32,
  height : Int32,
) -> @sdl_lib.Texture raise {
  let texture = renderer.create_texture(
    width~,
    height~,
    format=Bgra32,
    access=Streaming,
  )
  texture.set_blend_mode(NoBlend)
  texture
}

///|
fn with_texture_pixels(
  texture : @sdl_lib.Texture,
  width : Int32,
  height : Int32,
  paint : (@backend.RasterTarget) -> Unit raise,
  scale~ : Double = 1.0,
) -> Unit raise {
  let pixels = Ref(@sdl_sys.Pointer::null())
  let pitch = Ref(0)
  if !@sdl_sys.lock_texture(
      texture.raw(),
      // The capacity can exceed the visible frame during resize. Lock only
      // the pixels we paint so SDL need not stage/upload the unused capacity.
      Rect(0, 0, width, height),
      true,
      pixels,
      pitch,
    ) {
    let message = @utf8.decode_lossy(@sdl_sys.get_error())
    if message == "" {
      raise @sdl_lib.SdlError("SDL_LockTexture failed")
    } else {
      raise @sdl_lib.SdlError("SDL_LockTexture failed: \{message}")
    }
  }
  defer @sdl_sys.unlock_texture(texture.raw())
  if pixels.val.is_null() {
    raise InvalidTextureMemory(width~, height~, row_bytes=pitch.val)
  }
  paint(
    RasterTarget(
      memory=to_raster_memory(pixels.val),
      width~,
      height~,
      row_bytes=pitch.val,
      format=Bgra8888Premultiplied,
      scale~,
    ),
  )
}

///|
fn to_raster_memory(pointer : @sdl_sys.Pointer) -> @backend.RasterMemory = "%identity"

///|
fn present_texture(
  renderer : @sdl_lib.Renderer,
  texture : @sdl_lib.Texture,
  source_width~ : Int32,
  source_height~ : Int32,
  width~ : Int32,
  height~ : Int32,
) -> Unit raise {
  renderer.set_draw_color(@sdl_lib.Color::rgb(r=18, g=20, b=24))
  renderer.clear()
  renderer.render_texture(
    texture,
    src=FRect(
      x=0.0,
      y=0.0,
      w=Float::from_int(source_width),
      h=Float::from_int(source_height),
    ),
    dst=FRect(x=0.0, y=0.0, w=Float::from_int(width), h=Float::from_int(height)),
  )
  renderer.present()
}
