///|
/// Concrete declaration for Button; parts retain their own value types.
#derive(Eq, Debug, Default)
pub struct ButtonStyle {
  priv source : @style.StyleSource[ButtonStyle]?
  surface : @style.BoxStyle
  label : @view.TextStyle
}

///|
pub extend ButtonStyle with Eq::{equal, not_equal}

///|
pub extend ButtonStyle with Debug::{to_repr}

///|
pub fn ButtonStyle::ButtonStyle() -> ButtonStyle {
  Default::default()
}

///|
pub fn ButtonStyle::surface(
  self : ButtonStyle,
  value : @style.BoxStyle,
) -> ButtonStyle {
  { ..self, surface: self.surface.merge(value), }
}

///|
pub fn ButtonStyle::label(
  self : ButtonStyle,
  value : @view.TextStyle,
) -> ButtonStyle {
  { ..self, label: self.label.merge(value), }
}

///|
pub impl @style.StyleSpec for ButtonStyle with fn merge(self, other) {
  @style.merge_sources(self, other, fn(self, other) {
    {
      source: None,
      surface: self.surface.merge(other.surface),
      label: self.label.merge(other.label),
    }
  })
}

///|
pub fn ButtonStyle::hovered(
  self : ButtonStyle,
  value : @style.Appearance,
) -> ButtonStyle {
  { ..self, surface: self.surface.hovered(value), }
}

///|
pub fn ButtonStyle::focused(
  self : ButtonStyle,
  value : @style.Appearance,
) -> ButtonStyle {
  { ..self, surface: self.surface.focused(value), }
}

///|
pub fn ButtonStyle::pressed(
  self : ButtonStyle,
  value : @style.Appearance,
) -> ButtonStyle {
  { ..self, surface: self.surface.pressed(value), }
}

///|
pub fn ButtonStyle::disabled(
  self : ButtonStyle,
  value : @style.Appearance,
) -> ButtonStyle {
  { ..self, surface: self.surface.disabled(value), }
}

///|
pub impl @style.StyleSpec for ButtonStyle with fn root_style(self) {
  text_root_style(self.surface, self.label)
}

///|
pub extend ButtonStyle with @style.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
pub impl @style.StyleSpec for ButtonStyle with fn split_source(self) {
  ({ ..self, source: None, }, self.source)
}

///|
pub impl @style.SourceStyle for ButtonStyle with fn with_source(self, source) {
  { ..self, source, }
}

///|
pub extend ButtonStyle with @style.SourceStyle::{computed, bind}

///|
pub impl @style.StyleSpec for ButtonStyle with fn freeze_fields(self, sheet) {
  {
    ..self,
    surface: @style.freeze_style(self.surface, sheet),
    label: @style.freeze_style(self.label, sheet),
  }
}

///|
pub impl @style.StyleSpec for ButtonStyle with fn has_source(self) {
  self.source is Some(_) ||
  @style.StyleSpec::has_source(self.surface) ||
  @style.StyleSpec::has_source(self.label)
}
