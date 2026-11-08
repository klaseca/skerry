///|
/// Concrete declaration for Radio; parts retain their own value types.
#derive(Eq, Debug, Default)
pub struct RadioStyle {
  priv source : @style.StyleSource[RadioStyle]?
  frame : @style.BoxStyle
  label : @view.TextStyle
  indicator : @style.BoxStyle
  gap : Double?
  marker_color : @style.StyleColor?
}

///|
pub extend RadioStyle with Eq::{equal, not_equal}

///|
pub extend RadioStyle with Debug::{to_repr}

///|
pub fn RadioStyle::RadioStyle() -> RadioStyle {
  Default::default()
}

///|
pub fn RadioStyle::frame(
  self : RadioStyle,
  value : @style.BoxStyle,
) -> RadioStyle {
  { ..self, frame: self.frame.merge(value), }
}

///|
pub fn RadioStyle::label(
  self : RadioStyle,
  value : @view.TextStyle,
) -> RadioStyle {
  { ..self, label: self.label.merge(value), }
}

///|
pub fn RadioStyle::indicator(
  self : RadioStyle,
  value : @style.BoxStyle,
) -> RadioStyle {
  { ..self, indicator: self.indicator.merge(value), }
}

///|
pub fn RadioStyle::marker_color(
  self : RadioStyle,
  value : &@style.ColorValue,
) -> RadioStyle {
  { ..self, marker_color: Some(value.to_style_color()), }
}

///|
pub impl @style.StyleSpec for RadioStyle with fn merge(self, other) {
  @style.merge_sources(self, other, fn(self, other) {
    {
      source: None,
      frame: self.frame.merge(other.frame),
      label: self.label.merge(other.label),
      indicator: self.indicator.merge(other.indicator),
      gap: merge_style_option(self.gap, other.gap),
      marker_color: merge_style_option(self.marker_color, other.marker_color),
    }
  })
}

///|
pub fn RadioStyle::hovered(
  self : RadioStyle,
  value : @style.Appearance,
) -> RadioStyle {
  { ..self, indicator: self.indicator.hovered(value), }
}

///|
pub fn RadioStyle::focused(
  self : RadioStyle,
  value : @style.Appearance,
) -> RadioStyle {
  { ..self, indicator: self.indicator.focused(value), }
}

///|
pub fn RadioStyle::pressed(
  self : RadioStyle,
  value : @style.Appearance,
) -> RadioStyle {
  { ..self, indicator: self.indicator.pressed(value), }
}

///|
pub fn RadioStyle::disabled(
  self : RadioStyle,
  value : @style.Appearance,
) -> RadioStyle {
  { ..self, indicator: self.indicator.disabled(value), }
}

///|
pub fn RadioStyle::gap(self : RadioStyle, gap : Double) -> RadioStyle {
  { ..self, gap: Some(gap), }
}

///|
pub impl @style.StyleSpec for RadioStyle with fn root_style(self) {
  text_root_style(self.frame, self.label)
}

///|
pub impl @style.StyleSpec for RadioStyle with fn metrics(self) {
  StyleMetrics(dimensions=[
    @style.style_value(self.indicator).layout.width,
    @style.style_value(self.indicator).layout.height,
    self.gap,
  ])
}

///|
pub extend RadioStyle with @style.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
fn resolved_radio_style(
  layers : ReadOnlyArray[@style.StyleDeclaration],
) -> RadioStyle {
  let mut result = RadioStyle()
  for layer in layers {
    let value : RadioStyle? = layer.get()
    if value is Some(value) {
      result = result.merge(value)
    }
  }
  {
    ..result,
    frame: @style.style_value(result.frame),
    label: @style.style_value(result.label),
    indicator: @style.style_value(result.indicator),
  }
}

///|
pub impl @style.StyleSpec for RadioStyle with fn split_source(self) {
  ({ ..self, source: None, }, self.source)
}

///|
pub impl @style.SourceStyle for RadioStyle with fn with_source(self, source) {
  { ..self, source, }
}

///|
pub extend RadioStyle with @style.SourceStyle::{computed, bind}

///|
pub impl @style.StyleSpec for RadioStyle with fn freeze_fields(self, sheet) {
  {
    ..self,
    frame: @style.freeze_style(self.frame, sheet),
    label: @style.freeze_style(self.label, sheet),
    indicator: @style.freeze_style(self.indicator, sheet),
  }
}

///|
pub impl @style.StyleSpec for RadioStyle with fn has_source(self) {
  self.source is Some(_) ||
  @style.StyleSpec::has_source(self.frame) ||
  @style.StyleSpec::has_source(self.label) ||
  @style.StyleSpec::has_source(self.indicator)
}
