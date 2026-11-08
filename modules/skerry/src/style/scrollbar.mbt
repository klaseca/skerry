///|
/// Appearance of the scrollbar track and its inset thumb. Dimensions use the
/// same logical units as layout. Zero thickness hides the scrollbar.
#derive(Eq, Debug)
pub struct ScrollbarStyle {
  thickness : Double
  track_color : StyleColor
  track_radius : Double
  thumb_color : StyleColor
  thumb_radius : Double
  thumb_inset : Double
}

///|
pub extend ScrollbarStyle with Eq::{equal, not_equal}

///|
pub extend ScrollbarStyle with Debug::{to_repr}

///|
/// Default: a 12-unit theme-colored track with an 8-unit thumb inset by 2 units.
///
/// ```mbt check
/// test {
///   let style = @style.ScrollbarStyle().thickness(24.0).thumb_inset(3.0)
///   assert_eq(style.thickness, 24.0)
///   assert_eq(style.thumb_inset, 3.0)
///   assert_eq(style.track_radius, 0.0)
/// }
/// ```
pub fn ScrollbarStyle::ScrollbarStyle() -> ScrollbarStyle {
  Default::default()
}

///|
pub impl Default for ScrollbarStyle with fn default() {
  {
    thickness: 12.0,
    track_color: scrollbar_track_token.to_style_color(),
    track_radius: 0.0,
    thumb_color: scrollbar_thumb_token.to_style_color(),
    thumb_radius: 2.0,
    thumb_inset: 2.0,
  }
}

///|
pub fn ScrollbarStyle::thickness(
  self : ScrollbarStyle,
  value : Double,
) -> ScrollbarStyle {
  { ..self, thickness: value.max(0.0), }
}

///|
pub fn ScrollbarStyle::track_radius(
  self : ScrollbarStyle,
  value : Double,
) -> ScrollbarStyle {
  { ..self, track_radius: value.max(0.0), }
}

///|
pub fn ScrollbarStyle::thumb_radius(
  self : ScrollbarStyle,
  value : Double,
) -> ScrollbarStyle {
  { ..self, thumb_radius: value.max(0.0), }
}

///|
pub fn ScrollbarStyle::thumb_inset(
  self : ScrollbarStyle,
  value : Double,
) -> ScrollbarStyle {
  { ..self, thumb_inset: value.max(0.0), }
}

///|
pub fn ScrollbarStyle::track_color(
  self : ScrollbarStyle,
  value : &ColorValue,
) -> ScrollbarStyle {
  { ..self, track_color: value.to_style_color(), }
}

///|
pub fn ScrollbarStyle::thumb_color(
  self : ScrollbarStyle,
  value : &ColorValue,
) -> ScrollbarStyle {
  { ..self, thumb_color: value.to_style_color(), }
}
