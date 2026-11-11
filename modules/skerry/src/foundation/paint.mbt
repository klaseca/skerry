///|
#derive(Eq, Debug)
pub(all) struct Color {
  r : Double
  g : Double
  b : Double
  a : Double
}

///|
pub extend Color with Eq::{not_equal, equal}

///|
pub extend Color with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub struct FontSpec {
  priv size : Double
}

///|
pub extend FontSpec with Eq::{not_equal, equal}

///|
pub extend FontSpec with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum TextAlign {
  TextStart
  TextCenter
  TextEnd
}

///|
pub extend TextAlign with Eq::{not_equal, equal}

///|
pub extend TextAlign with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct TextRun {
  text : String
  frame : Rect
  baseline : Double
  font : FontSpec
  color : Color
  align : TextAlign
}

///|
pub extend TextRun with Eq::{not_equal, equal}

///|
pub extend TextRun with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct RoundedRect {
  rect : Rect
  radius : Double
}

///|
pub extend RoundedRect with Eq::{not_equal, equal}

///|
pub extend RoundedRect with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum Brush {
  Solid(Color)
}

///|
pub extend Brush with Eq::{not_equal, equal}

///|
pub extend Brush with Debug::{to_repr}

///|
pub(open) trait SceneRenderer {
  fn clear(Self, Color) -> Unit
  fn fill_rect(Self, Rect, Color) -> Unit
  fn stroke_rect(Self, Rect, Color, Double) -> Unit
  fn fill_rounded_rect(Self, RoundedRect, Color) -> Unit
  fn stroke_rounded_rect(Self, RoundedRect, Color, Double) -> Unit
  /// Stroke a segment in logical coordinates, independently of font coverage.
  fn draw_line(Self, Point, Point, Color, Double) -> Unit
  fn draw_text(Self, TextRun) -> Unit
  fn draw_image(Self, Image, ImagePlacement) -> Unit
  fn push_clip(Self, Rect) -> Unit
  fn pop_clip(Self) -> Unit
}

///|
pub fn Color::rgba(
  r~ : Int32,
  g~ : Int32,
  b~ : Int32,
  a~ : Int32 = 255,
) -> Color {
  {
    r: color_byte_to_unit(r),
    g: color_byte_to_unit(g),
    b: color_byte_to_unit(b),
    a: color_byte_to_unit(a),
  }
}

///|
pub fn Color::rgb(r~ : Int32, g~ : Int32, b~ : Int32) -> Color {
  Color::rgba(r~, g~, b~)
}

///|
pub fn Color::transparent() -> Color {
  Color::rgba(r=0, g=0, b=0, a=0)
}

///|
pub fn Color::black() -> Color {
  Color::rgb(r=0, g=0, b=0)
}

///|
pub fn Color::white() -> Color {
  Color::rgb(r=255, g=255, b=255)
}

///|
pub fn Color::surface() -> Color {
  Color::rgb(r=245, g=247, b=252)
}

///|
pub fn Color::accent() -> Color {
  Color::rgb(r=28, g=115, b=219)
}

///|
fn color_byte_to_unit(value : Int32) -> Double {
  clamp_double(value.to_double(), 0.0, 255.0) / 255.0
}

///|
pub fn FontSpec::default() -> FontSpec {
  { size: 16.0, }
}

///|
pub fn FontSpec::size(_self : FontSpec, size : Double) -> FontSpec {
  { size, }
}

///|
pub fn FontSpec::point_size(self : Self) -> Double {
  self.size
}

///|
pub fn RoundedRect::RoundedRect(rect~ : Rect, radius~ : Double) -> RoundedRect {
  { rect, radius: max_double(0.0, radius), }
}
