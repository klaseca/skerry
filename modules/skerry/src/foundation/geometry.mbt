///|
#derive(Eq, Debug)
pub(all) struct Point {
  x : Double
  y : Double
}

///|
pub extend Point with Eq::{not_equal, equal}

///|
pub extend Point with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct Size {
  width : Double
  height : Double
}

///|
pub extend Size with Eq::{not_equal, equal}

///|
pub extend Size with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct Rect {
  origin : Point
  size : Size
}

///|
pub extend Rect with Eq::{not_equal, equal}

///|
pub extend Rect with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct Insets {
  top : Double
  right : Double
  bottom : Double
  left : Double
}

///|
pub extend Insets with Eq::{not_equal, equal}

///|
pub extend Insets with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) struct Constraints {
  min : Size
  max : Size
}

///|
pub extend Constraints with Eq::{not_equal, equal}

///|
pub extend Constraints with Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum Axis {
  Horizontal
  Vertical
}

///|
pub extend Axis with Eq::{not_equal, equal}

///|
pub extend Axis with Debug::{to_repr}

///|
pub fn Point::Point(x~ : Double, y~ : Double) -> Point {
  { x, y, }
}

///|
pub fn Size::Size(width~ : Double, height~ : Double) -> Size {
  { width, height, }
}

///|
pub fn Size::zero() -> Size {
  Size(width=0.0, height=0.0)
}

///|
pub fn Rect::Rect(
  x~ : Double,
  y~ : Double,
  width~ : Double,
  height~ : Double,
) -> Rect {
  { origin: Point(x~, y~), size: Size(width~, height~), }
}

///|
pub fn Rect::from_size(size : Size) -> Rect {
  Rect(x=0.0, y=0.0, width=size.width, height=size.height)
}

///|
pub fn Insets::all(value : Double) -> Insets {
  { top: value, right: value, bottom: value, left: value, }
}

///|
pub fn Insets::symmetric(
  horizontal~ : Double = 0.0,
  vertical~ : Double = 0.0,
) -> Insets {
  { top: vertical, right: horizontal, bottom: vertical, left: horizontal, }
}

///|
pub fn Constraints::tight(size : Size) -> Constraints {
  { min: size, max: size, }
}

///|
pub fn Constraints::loose(max : Size) -> Constraints {
  { min: Size::zero(), max, }
}

///|
pub fn Constraints::unbounded() -> Constraints {
  { min: Size::zero(), max: Size(width=1000000000.0, height=1000000000.0), }
}

///|
pub fn Constraints::constrain(self : Constraints, size : Size) -> Size {
  Size(
    width=clamp_double(size.width, self.min.width, self.max.width),
    height=clamp_double(size.height, self.min.height, self.max.height),
  )
}

///|
pub fn Constraints::deflate(self : Constraints, insets : Insets) -> Constraints {
  let horizontal = insets.left + insets.right
  let vertical = insets.top + insets.bottom
  {
    min: Size(
      width=max_double(0.0, self.min.width - horizontal),
      height=max_double(0.0, self.min.height - vertical),
    ),
    max: Size(
      width=max_double(0.0, self.max.width - horizontal),
      height=max_double(0.0, self.max.height - vertical),
    ),
  }
}

///|
pub fn Size::inflate(self : Size, insets : Insets) -> Size {
  Size(
    width=self.width + insets.left + insets.right,
    height=self.height + insets.top + insets.bottom,
  )
}

///|
pub fn Rect::inset(self : Rect, insets : Insets) -> Rect {
  Rect(
    x=self.origin.x + insets.left,
    y=self.origin.y + insets.top,
    width=max_double(0.0, self.size.width - insets.left - insets.right),
    height=max_double(0.0, self.size.height - insets.top - insets.bottom),
  )
}

///|
pub fn Rect::contains(self : Rect, point : Point) -> Bool {
  point.x >= self.origin.x &&
  point.y >= self.origin.y &&
  point.x <= self.origin.x + self.size.width &&
  point.y <= self.origin.y + self.size.height
}

///|
/// Intersection of two axis-aligned rectangles; disjoint or empty inputs produce
/// an empty rectangle. Clip and input code share this geometry operation.
pub fn Rect::intersect(self : Rect, other : Rect) -> Rect {
  let x = self.origin.x.max(other.origin.x)
  let y = self.origin.y.max(other.origin.y)
  Rect(
    x~,
    y~,
    width=((self.origin.x + self.size.width).min(
      other.origin.x + other.size.width,
    ) -
    x).max(0.0),
    height=((self.origin.y + self.size.height).min(
      other.origin.y + other.size.height,
    ) -
    y).max(0.0),
  )
}

///|
pub fn Rect::is_empty(self : Rect) -> Bool {
  self.size.width <= 0.0 || self.size.height <= 0.0
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
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
