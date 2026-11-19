///|
/// The dialog surface and full-window backdrop. Backdrop padding controls the
/// space between the surface and window edges. Surface content scrolls when it
/// exceeds the available height. Empty styles preserve the component defaults.
#derive(Eq, Debug, Default)
pub struct DialogStyle {
  priv source : @style.StyleSource[DialogStyle]?
  surface : @style.BoxStyle
  backdrop : @style.BoxStyle
}

///|
pub extend DialogStyle with Eq::{equal, not_equal}

///|
pub extend DialogStyle with Debug::{to_repr}

///|
pub fn DialogStyle::DialogStyle() -> DialogStyle {
  Default::default()
}

///|
pub fn DialogStyle::surface(
  self : DialogStyle,
  value : @style.BoxStyle,
) -> DialogStyle {
  { ..self, surface: self.surface.merge(value), }
}

///|
pub fn DialogStyle::backdrop(
  self : DialogStyle,
  value : @style.BoxStyle,
) -> DialogStyle {
  { ..self, backdrop: self.backdrop.merge(value), }
}

///|
pub impl @style.StyleSpec for DialogStyle with fn merge(self, other) {
  @style.merge_sources(self, other, fn(a, b) {
    {
      source: None,
      surface: a.surface.merge(b.surface),
      backdrop: a.backdrop.merge(b.backdrop),
    }
  })
}

///|
pub impl @style.StyleSpec for DialogStyle with fn root_style(self) {
  @style.style_value(self.surface)
}

///|
pub impl @style.StyleSpec for DialogStyle with fn split_source(self) {
  ({ ..self, source: None, }, self.source)
}

///|
pub impl @style.StyleSpec for DialogStyle with fn freeze_fields(self, sheet) {
  {
    ..self,
    surface: @style.freeze_style(self.surface, sheet),
    backdrop: @style.freeze_style(self.backdrop, sheet),
  }
}

///|
pub impl @style.StyleSpec for DialogStyle with fn has_source(self) {
  self.source is Some(_) ||
  @style.StyleSpec::has_source(self.surface) ||
  @style.StyleSpec::has_source(self.backdrop)
}

///|
pub impl @style.SourceStyle for DialogStyle with fn with_source(self, source) {
  { ..self, source, }
}

///|
pub extend DialogStyle with @style.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
pub extend DialogStyle with @style.SourceStyle::{computed, bind}
