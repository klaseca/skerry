///|
/// Resolved properties supplied by the component's diagnostic resolver. None fields are inapplicable. Font/color/align describe the main text;
/// marker_color, placeholder_color, caret_color and selection_color describe
/// decoration palettes, regardless of whether that decoration was visible.
/// Placeholder typography and indicator size/gap describe their separate parts. Colors/stroke reflect control state
/// and appearance overrides at paint time.
/// Sizes and layout insets are available in NodeSnapshot geometry.
#derive(Debug, Eq)
pub(all) struct ComputedStyle {
  font : @foundation.FontSpec?
  color : @foundation.Color?
  background : @foundation.Color?
  radius : Double?
  align : @foundation.TextAlign?
  spacing : Double?
  stroke_color : @foundation.Color?
  stroke_width : Double?
  marker_color : @foundation.Color?
  placeholder_font : @foundation.FontSpec?
  placeholder_align : @foundation.TextAlign?
  indicator_size : @foundation.Size?
  indicator_gap : Double?
  placeholder_color : @foundation.Color?
  caret_color : @foundation.Color?
  selection_color : @foundation.Color?
}

///|
pub extend ComputedStyle with Debug::{to_repr}

///|
pub extend ComputedStyle with Eq::{equal, not_equal}

///|
pub fn ComputedStyle::ComputedStyle(
  font? : @foundation.FontSpec,
  color? : @foundation.Color,
  background? : @foundation.Color,
  radius? : Double,
  align? : @foundation.TextAlign,
  spacing? : Double,
  stroke_color? : @foundation.Color,
  stroke_width? : Double,
  marker_color? : @foundation.Color,
  placeholder_font? : @foundation.FontSpec,
  placeholder_align? : @foundation.TextAlign,
  indicator_size? : @foundation.Size,
  indicator_gap? : Double,
  placeholder_color? : @foundation.Color,
  caret_color? : @foundation.Color,
  selection_color? : @foundation.Color,
) -> ComputedStyle {
  {
    font,
    color,
    background,
    radius,
    align,
    spacing,
    stroke_color,
    stroke_width,
    marker_color,
    placeholder_font,
    placeholder_align,
    indicator_size,
    indicator_gap,
    placeholder_color,
    caret_color,
    selection_color,
  }
}
