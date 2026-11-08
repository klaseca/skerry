///|
/// Concrete declaration for Checkbox; parts retain their own value types.
#derive(Eq, Debug, Default)
pub struct CheckboxStyle {
  priv source : @style.StyleSource[CheckboxStyle]?
  frame : @style.BoxStyle
  label : @view.TextStyle
  indicator : @style.BoxStyle
  gap : Double?
  marker_color : @style.StyleColor?
}

///|
pub extend CheckboxStyle with Eq::{equal, not_equal}

///|
pub extend CheckboxStyle with Debug::{to_repr}

///|
pub fn CheckboxStyle::CheckboxStyle() -> CheckboxStyle {
  Default::default()
}

///|
pub fn CheckboxStyle::frame(
  self : CheckboxStyle,
  value : @style.BoxStyle,
) -> CheckboxStyle {
  { ..self, frame: self.frame.merge(value), }
}

///|
pub fn CheckboxStyle::label(
  self : CheckboxStyle,
  value : @view.TextStyle,
) -> CheckboxStyle {
  { ..self, label: self.label.merge(value), }
}

///|
pub fn CheckboxStyle::indicator(
  self : CheckboxStyle,
  value : @style.BoxStyle,
) -> CheckboxStyle {
  { ..self, indicator: self.indicator.merge(value), }
}

///|
pub fn CheckboxStyle::marker_color(
  self : CheckboxStyle,
  value : &@style.ColorValue,
) -> CheckboxStyle {
  { ..self, marker_color: Some(value.to_style_color()), }
}

///|
pub impl @style.StyleSpec for CheckboxStyle with fn merge(self, other) {
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
pub fn CheckboxStyle::hovered(
  self : CheckboxStyle,
  value : @style.Appearance,
) -> CheckboxStyle {
  { ..self, indicator: self.indicator.hovered(value), }
}

///|
pub fn CheckboxStyle::focused(
  self : CheckboxStyle,
  value : @style.Appearance,
) -> CheckboxStyle {
  { ..self, indicator: self.indicator.focused(value), }
}

///|
pub fn CheckboxStyle::pressed(
  self : CheckboxStyle,
  value : @style.Appearance,
) -> CheckboxStyle {
  { ..self, indicator: self.indicator.pressed(value), }
}

///|
pub fn CheckboxStyle::disabled(
  self : CheckboxStyle,
  value : @style.Appearance,
) -> CheckboxStyle {
  { ..self, indicator: self.indicator.disabled(value), }
}

///|
pub fn CheckboxStyle::gap(self : CheckboxStyle, gap : Double) -> CheckboxStyle {
  { ..self, gap: Some(gap), }
}

///|
pub impl @style.StyleSpec for CheckboxStyle with fn root_style(self) {
  text_root_style(self.frame, self.label)
}

///|
pub impl @style.StyleSpec for CheckboxStyle with fn metrics(self) {
  StyleMetrics(dimensions=[
    @style.style_value(self.indicator).layout.width,
    @style.style_value(self.indicator).layout.height,
    self.gap,
  ])
}

///|
pub extend CheckboxStyle with @style.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
fn resolved_checkbox_style(
  layers : ReadOnlyArray[@style.StyleDeclaration],
) -> CheckboxStyle {
  let mut result = CheckboxStyle()
  for layer in layers {
    let value : CheckboxStyle? = layer.get()
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
pub impl @style.StyleSpec for CheckboxStyle with fn split_source(self) {
  ({ ..self, source: None, }, self.source)
}

///|
pub impl @style.SourceStyle for CheckboxStyle with fn with_source(self, source) {
  { ..self, source, }
}

///|
pub extend CheckboxStyle with @style.SourceStyle::{computed, bind}

///|
pub impl @style.StyleSpec for CheckboxStyle with fn freeze_fields(self, sheet) {
  {
    ..self,
    frame: @style.freeze_style(self.frame, sheet),
    label: @style.freeze_style(self.label, sheet),
    indicator: @style.freeze_style(self.indicator, sheet),
  }
}

///|
pub impl @style.StyleSpec for CheckboxStyle with fn has_source(self) {
  self.source is Some(_) ||
  @style.StyleSpec::has_source(self.frame) ||
  @style.StyleSpec::has_source(self.label) ||
  @style.StyleSpec::has_source(self.indicator)
}
