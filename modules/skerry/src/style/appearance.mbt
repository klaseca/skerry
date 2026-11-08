///|
/// Paint-only properties shared by normal styles and control states. Unset fields
/// keep the resolved appearance; these properties never affect layout or hit geometry.
#derive(Eq, Debug, Default)
pub struct Appearance {
  background : StyleColor?
  color : StyleColor?
  radius : Double?
  stroke_color : StyleColor?
  stroke_width : Double?
}

///|
pub extend Appearance with Eq::{equal, not_equal}

///|
pub extend Appearance with Debug::{to_repr}

///|
pub fn Appearance::Appearance() -> Appearance {
  Default::default()
}

///|
pub fn Appearance::background(
  self : Appearance,
  color : &ColorValue,
) -> Appearance {
  { ..self, background: Some(color.to_style_color()), }
}

///|
pub fn Appearance::color(self : Appearance, color : &ColorValue) -> Appearance {
  { ..self, color: Some(color.to_style_color()), }
}

///|
pub fn Appearance::radius(self : Appearance, radius : Double) -> Appearance {
  { ..self, radius: Some(radius.max(0.0)), }
}

///|
/// Zero hides the stroke. Stroke width does not reserve layout space.
pub fn Appearance::stroke(
  self : Appearance,
  color : &ColorValue,
  width~ : Double = 1.0,
) -> Appearance {
  {
    ..self,
    stroke_color: Some(color.to_style_color()),
    stroke_width: Some(width.max(0.0)),
  }
}

///|
pub fn Appearance::merge(self : Appearance, other : Appearance) -> Appearance {
  {
    background: merge_option(self.background, other.background),
    color: merge_option(self.color, other.color),
    radius: merge_option(self.radius, other.radius),
    stroke_color: merge_option(self.stroke_color, other.stroke_color),
    stroke_width: merge_option(self.stroke_width, other.stroke_width),
  }
}
