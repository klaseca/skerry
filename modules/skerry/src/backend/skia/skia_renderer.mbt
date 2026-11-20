///|
priv struct Renderer {
  typeface : @skia_lib.Typeface
  font : @skia_lib.Font
  paint : @skia_lib.Paint
  surface_props : @skia_sys.Surfaceprops
  mut images : Map[@foundation.Image, CachedImage]
  image_error : Ref[SkiaRendererError?]
  mut disposed : Bool
}

///|
fn Renderer::Renderer() -> Renderer raise {
  let typeface = @skia_lib.Typeface::default()
  errdefer typeface.dispose()
  let font = @skia_lib.Font(typeface, size=16.0)
  errdefer font.dispose()
  let paint = @skia_lib.Paint()
  errdefer paint.dispose()
  paint.set_antialias(true)
  let surface_props = @skia_sys.surfaceprops_new(0, 0)
  if surface_props.is_null() {
    raise SurfacePropsCreateFailed
  }
  {
    typeface,
    font,
    paint,
    surface_props,
    images: Map([]),
    image_error: Ref(None),
    disposed: false,
  }
}

///|
fn Renderer::dispose(self : Self) -> Unit {
  guard !self.disposed else { return }
  self.disposed = true
  self.images = Map([])
  @skia_sys.surfaceprops_delete(self.surface_props)
  self.paint.dispose()
  self.font.dispose()
  self.typeface.dispose()
}

///|
fn Renderer::text_layout_system(self : Self) -> @text.TextLayoutSystem {
  @text.TextLayoutSystem::from_metrics(skia_text_metrics_provider(self.font))
}

///|
fn Renderer::render(
  self : Self,
  root : @runtime.UiRoot,
  target : @backend.RasterTarget,
  clear : @foundation.Color,
) -> Unit raise {
  self.render_to_raster(target, scene_renderer => {
    root.paint(scene_renderer, size=target.logical_size(), clear~)
  })
}

///|
fn Renderer::render_to_raster(
  self : Self,
  target : @backend.RasterTarget,
  paint : (&@foundation.SceneRenderer) -> Unit raise,
) -> Unit raise {
  let info = match target.format {
    Bgra8888Premultiplied =>
      @skia_sys.imageinfo_bgra8888_premul(target.width, target.height)
  }
  let canvas = @skia_sys.canvas_new_from_raster_pointer(
    info,
    to_skia_pointer(target.memory),
    target.row_bytes.to_uint64(),
    self.surface_props,
  )
  if canvas.is_null() {
    raise CanvasCreateFailed(width=target.width, height=target.height)
  }
  defer @skia_sys.canvas_destroy(canvas)
  let scale = Float::from_double(target.scale)
  @skia_sys.canvas_scale(canvas, scale, scale)
  self.draw(@skia_lib.Canvas::from_sys(canvas), paint)
}

///|
fn Renderer::draw(
  self : Self,
  canvas : @skia_lib.Canvas,
  paint_scene : (&@foundation.SceneRenderer) -> Unit raise,
) -> Unit raise {
  self.image_error.val = None
  for _, entry in self.images {
    entry.used = false
  }
  defer self.release_unused_images()
  paint_scene({
    canvas,
    paint: self.paint,
    font: self.font,
    images: self.images,
    image_error: self.image_error,
  })
  if self.image_error.val is Some(error) {
    raise error
  }
}

///|
priv struct SkiaSceneRenderer {
  canvas : @skia_lib.Canvas
  paint : @skia_lib.Paint
  font : @skia_lib.Font
  images : Map[@foundation.Image, CachedImage]
  image_error : Ref[SkiaRendererError?]
}

///|
impl @foundation.SceneRenderer for SkiaSceneRenderer with fn clear(self, color) {
  self.canvas.clear(to_skia_color(color))
}

///|
impl @foundation.SceneRenderer for SkiaSceneRenderer with fn fill_rect(
  self,
  rect,
  color,
) {
  self.paint.set_style(Fill)
  self.paint.set_color(to_skia_color(color))
  // Adjacent axis-aligned backgrounds must share a hard pixel edge. Separate
  // antialiased fills otherwise leave seams at fractional positions/scales.
  self.paint.set_antialias(false)
  self.canvas.draw_round_rect(to_skia_rect(rect), 0.0, 0.0, self.paint)
  self.paint.set_antialias(true)
}

///|
impl @foundation.SceneRenderer for SkiaSceneRenderer with fn draw_line(
  self,
  start,
  end,
  color,
  width,
) {
  guard width > 0.0 else { return }
  self.paint.set_style(Stroke)
  self.paint.set_stroke_width(Float::from_double(width))
  self.paint.set_color(to_skia_color(color))
  self.canvas.draw_line(
    Float::from_double(start.x),
    Float::from_double(start.y),
    Float::from_double(end.x),
    Float::from_double(end.y),
    self.paint,
  )
}

///|
impl @foundation.SceneRenderer for SkiaSceneRenderer with fn stroke_rect(
  self,
  rect,
  color,
  width,
) {
  self.paint.set_style(Stroke)
  self.paint.set_stroke_width(Float::from_double(width))
  self.paint.set_color(to_skia_color(color))
  self.canvas.draw_round_rect(to_skia_rect(rect), 0.0, 0.0, self.paint)
}

///|
impl @foundation.SceneRenderer for SkiaSceneRenderer with fn fill_rounded_rect(
  self,
  rounded,
  color,
) {
  self.paint.set_style(Fill)
  self.paint.set_color(to_skia_color(color))
  let radius = Float::from_double(rounded.radius)
  self.canvas.draw_round_rect(
    to_skia_rect(rounded.rect),
    radius,
    radius,
    self.paint,
  )
}

///|
impl @foundation.SceneRenderer for SkiaSceneRenderer with fn stroke_rounded_rect(
  self,
  rounded,
  color,
  width,
) {
  self.paint.set_style(Stroke)
  self.paint.set_stroke_width(Float::from_double(width))
  self.paint.set_color(to_skia_color(color))
  let radius = Float::from_double(rounded.radius)
  self.canvas.draw_round_rect(
    to_skia_rect(rounded.rect),
    radius,
    radius,
    self.paint,
  )
}

///|
impl @foundation.SceneRenderer for SkiaSceneRenderer with fn draw_text(
  self,
  run,
) {
  draw_skia_text(self.canvas, self.paint, self.font, run)
}

///|
impl @foundation.SceneRenderer for SkiaSceneRenderer with fn push_clip(
  self,
  rect,
) {
  ignore(self.canvas.save())
  self.canvas.clip_rect(to_skia_rect(rect))
}

///|
impl @foundation.SceneRenderer for SkiaSceneRenderer with fn pop_clip(self) {
  self.canvas.restore()
}

///|
fn draw_skia_text(
  canvas : @skia_lib.Canvas,
  paint : @skia_lib.Paint,
  font : @skia_lib.Font,
  run : @foundation.TextRun,
) -> Unit {
  paint.set_style(Fill)
  paint.set_color(to_skia_color(run.color))
  font.set_size(Float::from_double(run.font.point_size()))
  canvas.draw_text(
    @utf8.encode(run.text),
    x=Float::from_double(text_x(run, font)),
    y=Float::from_double(text_baseline(run, font)),
    font,
    paint,
  )
}

///|
fn text_x(run : @foundation.TextRun, font : @skia_lib.Font) -> Double {
  match run.align {
    TextStart => run.frame.origin.x
    TextCenter => {
      let width = skia_text_width(font, run.text)
      run.frame.origin.x + (run.frame.size.width - width) * 0.5
    }
    TextEnd => {
      let width = skia_text_width(font, run.text)
      run.frame.origin.x + run.frame.size.width - width
    }
  }
}

///|
fn text_baseline(run : @foundation.TextRun, _font : @skia_lib.Font) -> Double {
  run.frame.origin.y + run.baseline
}

///|
fn to_skia_rect(rect : @foundation.Rect) -> @skia_lib.Rect {
  Rect(
    left=Float::from_double(rect.origin.x),
    top=Float::from_double(rect.origin.y),
    right=Float::from_double(rect.origin.x + rect.size.width),
    bottom=Float::from_double(rect.origin.y + rect.size.height),
  )
}

///|
fn to_skia_color(color : @foundation.Color) -> @skia_lib.Color {
  Color(
    a=color_component_to_byte(color.a),
    r=color_component_to_byte(color.r),
    g=color_component_to_byte(color.g),
    b=color_component_to_byte(color.b),
  )
}

///|
fn color_component_to_byte(value : Double) -> Byte {
  let scaled = clamp_double(value, 0.0, 1.0) * 255.0
  scaled.round().to_uint().to_byte()
}

///|
fn clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
#derive(Debug, Eq)
pub(all) suberror SkiaRendererError {
  SurfacePropsCreateFailed
  CanvasCreateFailed(width~ : Int32, height~ : Int32)
  ImageCreateFailed(width~ : Int32, height~ : Int32)
}

///|
pub extend SkiaRendererError with Debug::{to_repr}

///|
pub extend SkiaRendererError with Eq::{not_equal, equal}

///|
fn to_skia_pointer(pointer : @backend.RasterMemory) -> @skia_sys.Pointer = "%identity"
