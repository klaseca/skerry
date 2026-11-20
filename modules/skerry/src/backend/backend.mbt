///|
#external
pub type RasterMemory

///|
#derive(Debug, Eq)
pub(all) enum RasterFormat {
  Bgra8888Premultiplied
}

///|
pub extend RasterFormat with Debug::{to_repr}

///|
pub extend RasterFormat with Eq::{not_equal, equal}

///|
/// A writable raster buffer borrowed during `RasterSurface::with_pixels`.
/// Renderers must not retain `memory` after its callback returns.
/// Width, height and row_bytes describe physical pixels. Scale maps logical UI
/// units to pixels; renderers paint the root at logical_size() with this transform.
pub struct RasterTarget {
  memory : RasterMemory
  width : Int32
  height : Int32
  row_bytes : Int32
  format : RasterFormat
  scale : Double
}

///|
pub fn RasterTarget::RasterTarget(
  memory~ : RasterMemory,
  width~ : Int32,
  height~ : Int32,
  row_bytes~ : Int32,
  format~ : RasterFormat,
  scale~ : Double = 1.0,
) -> RasterTarget raise RasterTargetError {
  guard scale > 0.0 && scale < @double.infinity else {
    raise InvalidRasterScale(scale~)
  }
  if width <= 0 ||
    height <= 0 ||
    width > @int.MAX_VALUE / 4 ||
    row_bytes < width * 4 {
    raise InvalidRasterTarget(width~, height~, row_bytes~)
  }
  { memory, width, height, row_bytes, format, scale, }
}

///|
/// The viewport used by layout, input and diagnostic geometry.
pub fn RasterTarget::logical_size(self : Self) -> @foundation.Size {
  Size(
    width=self.width.to_double() / self.scale,
    height=self.height.to_double() / self.scale,
  )
}

///|
pub type AppBackend = (@runtime.App, RendererFactory) -> Unit raise

///|
pub type RendererFactory = (&SurfaceFactory) -> &Renderer raise

///|
#derive(Debug, Eq)
pub(all) suberror RasterTargetError {
  InvalidRasterScale(scale~ : Double)
  InvalidRasterTarget(width~ : Int32, height~ : Int32, row_bytes~ : Int32)
}

///|
pub extend RasterTargetError with Debug::{to_repr}

///|
pub extend RasterTargetError with Eq::{not_equal, equal}
