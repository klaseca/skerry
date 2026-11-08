///|
#derive(Eq, Debug, Default)
pub struct ImageStyle {
  priv source : @style.StyleSource[ImageStyle]?
  frame : @style.BoxStyle
  fit : @foundation.ImageFit?
  alignment : @foundation.ImageAlignment?
}

///|
pub fn ImageStyle::ImageStyle() -> ImageStyle {
  Default::default()
}

///|
pub fn ImageStyle::frame(
  self : ImageStyle,
  value : @style.BoxStyle,
) -> ImageStyle {
  @style.apply_style_field(self, value, fn(self, value) {
    { ..self, frame: self.frame.merge(value), }
  })
}

///|
pub fn ImageStyle::fit(
  self : ImageStyle,
  value : @foundation.ImageFit,
) -> ImageStyle {
  { ..self, fit: Some(value), }
}

///|
pub fn ImageStyle::align(
  self : ImageStyle,
  value : @foundation.ImageAlignment,
) -> ImageStyle {
  { ..self, alignment: Some(value), }
}

///|
pub impl @style.StyleSpec for ImageStyle with fn merge(self, other) {
  @style.merge_sources(self, other, fn(self, other) {
    {
      source: None,
      frame: self.frame.merge(other.frame),
      fit: merge_style_option(self.fit, other.fit),
      alignment: merge_style_option(self.alignment, other.alignment),
    }
  })
}

///|
pub impl @style.StyleSpec for ImageStyle with fn root_style(self) {
  self.frame
}

///|
pub impl @style.StyleSpec for ImageStyle with fn split_source(self) {
  ({ ..self, source: None, }, self.source)
}

///|
pub impl @style.SourceStyle for ImageStyle with fn with_source(self, source) {
  { ..self, source, }
}

///|
pub impl @style.StyleSpec for ImageStyle with fn freeze_fields(self, sheet) {
  { ..self, frame: @style.freeze_style(self.frame, sheet), }
}

///|
pub impl @style.StyleSpec for ImageStyle with fn has_source(self) {
  self.source is Some(_) || @style.StyleSpec::has_source(self.frame)
}

///|
pub extend ImageStyle with @style.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
pub extend ImageStyle with @style.SourceStyle::{computed, bind}

///|
pub extend ImageStyle with Eq::{equal, not_equal}

///|
pub extend ImageStyle with Debug::{to_repr}

///|
fn resolved_image_style(
  layers : ReadOnlyArray[@style.StyleDeclaration],
) -> ImageStyle {
  let mut result = ImageStyle()
  let mut frame = @style.BoxStyle()
  for layer in layers {
    let value : ImageStyle? = layer.get()
    if value is Some(value) {
      result = result.merge(value)
    }
    frame = frame.merge(layer.layout)
  }
  { ..result, frame, }
}

///|
pub fn ImageStyle::width(
  self : ImageStyle,
  value : &@value.DoubleValue,
) -> ImageStyle {
  self.frame(self.frame.width(value))
}

///|
pub fn ImageStyle::height(
  self : ImageStyle,
  value : &@value.DoubleValue,
) -> ImageStyle {
  self.frame(self.frame.height(value))
}

///|
pub fn ImageStyle::min_width(
  self : ImageStyle,
  value : &@value.DoubleValue,
) -> ImageStyle {
  self.frame(self.frame.min_width(value))
}

///|
pub fn ImageStyle::max_width(
  self : ImageStyle,
  value : &@value.DoubleValue,
) -> ImageStyle {
  self.frame(self.frame.max_width(value))
}

///|
pub fn ImageStyle::min_height(
  self : ImageStyle,
  value : &@value.DoubleValue,
) -> ImageStyle {
  self.frame(self.frame.min_height(value))
}

///|
pub fn ImageStyle::max_height(
  self : ImageStyle,
  value : &@value.DoubleValue,
) -> ImageStyle {
  self.frame(self.frame.max_height(value))
}

///|
pub fn ImageStyle::grow(
  self : ImageStyle,
  value : &@value.DoubleValue,
) -> ImageStyle {
  self.frame(self.frame.grow(value))
}

///|
pub fn ImageStyle::shrink(
  self : ImageStyle,
  value : &@value.DoubleValue,
) -> ImageStyle {
  self.frame(self.frame.shrink(value))
}

///|
pub fn ImageStyle::padding(
  self : ImageStyle,
  value : @foundation.Insets,
) -> ImageStyle {
  self.frame(self.frame.padding(value))
}

///|
pub fn ImageStyle::align_self(
  self : ImageStyle,
  value : @style.AlignSelf,
) -> ImageStyle {
  self.frame(self.frame.align_self(value))
}
