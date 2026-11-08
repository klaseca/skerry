///|
// App dimensions are logical units. SDL window coordinates are pixels on
// Windows/X11 and points on macOS/Wayland; density removes that difference.
fn initial_window_dimension(
  logical : Int32,
  display_scale : Double,
  pixel_density : Double,
) -> Int32 {
  (logical.to_double() * display_scale / pixel_density)
  .round()
  .max(1.0)
  .min(@int.MAX_VALUE.to_double())
  .to_int()
}

///|
priv struct InputGeometry {
  window_size : @foundation.Size
  logical_size : @foundation.Size
}

///|
fn input_geometry(
  renderer : @sdl_lib.Renderer,
  window : @sdl_lib.Window,
) -> InputGeometry raise {
  let output_size = event_size(renderer, window)
  let window_size = window.size()
  let scale = window.display_scale().to_double()
  InputGeometry(
    window_size=Size(
      width=window_size.width.to_double(),
      height=window_size.height.to_double(),
    ),
    pixel_size=Size(
      width=output_size.width.to_double(),
      height=output_size.height.to_double(),
    ),
    scale~,
  )
}

///|
fn InputGeometry::to_logical(
  self : InputGeometry,
  point : @foundation.Point,
) -> @foundation.Point? {
  guard self.window_size.width > 0.0 &&
    self.window_size.height > 0.0 &&
    self.logical_size.width > 0.0 &&
    self.logical_size.height > 0.0 else {
    return None
  }
  // Layout and input use logical UI units; SDL mouse positions use native window
  // coordinates, whose relation to the display scale differs across platforms.
  Some(
    Point(
      x=point.x * self.logical_size.width / self.window_size.width,
      y=point.y * self.logical_size.height / self.window_size.height,
    ),
  )
}

///|
fn event_size(
  renderer : @sdl_lib.Renderer,
  window : @sdl_lib.Window,
) -> @sdl_lib.Size raise {
  renderer.output_size() catch {
    _ => window.size_in_pixels()
  }
}

///|
fn InputGeometry::InputGeometry(
  window_size~ : @foundation.Size,
  pixel_size~ : @foundation.Size,
  scale~ : Double,
) -> InputGeometry {
  {
    window_size,
    logical_size: Size(
      width=pixel_size.width / scale,
      height=pixel_size.height / scale,
    ),
  }
}
