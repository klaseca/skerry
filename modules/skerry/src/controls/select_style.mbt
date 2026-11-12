///|
/// Styles for the field, floating list and its options. `selected` is layered
/// over `option` for the committed value. Focus uses background feedback for
/// keyboard navigation. The list defaults to four logical pixels of padding;
/// theme and local list padding override it, including zero.
#derive(Eq, Debug, Default)
pub struct SelectStyle {
  priv source : @style.StyleSource[SelectStyle]?
  surface : @style.BoxStyle
  label : @view.TextStyle
  placeholder : @view.TextStyle
  list : @style.BoxStyle
  option : ButtonStyle
  selected : ButtonStyle
}

///|
pub extend SelectStyle with Eq::{equal, not_equal}

///|
pub extend SelectStyle with Debug::{to_repr}

///|
pub fn SelectStyle::SelectStyle() -> SelectStyle {
  Default::default()
}

///|
pub fn SelectStyle::surface(
  self : SelectStyle,
  value : @style.BoxStyle,
) -> SelectStyle {
  { ..self, surface: self.surface.merge(value), }
}

///|
pub fn SelectStyle::label(
  self : SelectStyle,
  value : @view.TextStyle,
) -> SelectStyle {
  { ..self, label: self.label.merge(value), }
}

///|
pub fn SelectStyle::placeholder(
  self : SelectStyle,
  value : @view.TextStyle,
) -> SelectStyle {
  { ..self, placeholder: self.placeholder.merge(value), }
}

///|
pub fn SelectStyle::list(
  self : SelectStyle,
  value : @style.BoxStyle,
) -> SelectStyle {
  { ..self, list: self.list.merge(value), }
}

///|
pub fn SelectStyle::option(
  self : SelectStyle,
  value : ButtonStyle,
) -> SelectStyle {
  { ..self, option: self.option.merge(value), }
}

///|
pub fn SelectStyle::selected(
  self : SelectStyle,
  value : ButtonStyle,
) -> SelectStyle {
  { ..self, selected: self.selected.merge(value), }
}

///|
pub fn SelectStyle::hovered(
  self : SelectStyle,
  value : @style.Appearance,
) -> SelectStyle {
  { ..self, surface: self.surface.hovered(value), }
}

///|
pub fn SelectStyle::focused(
  self : SelectStyle,
  value : @style.Appearance,
) -> SelectStyle {
  { ..self, surface: self.surface.focused(value), }
}

///|
pub fn SelectStyle::pressed(
  self : SelectStyle,
  value : @style.Appearance,
) -> SelectStyle {
  { ..self, surface: self.surface.pressed(value), }
}

///|
pub fn SelectStyle::disabled(
  self : SelectStyle,
  value : @style.Appearance,
) -> SelectStyle {
  { ..self, surface: self.surface.disabled(value), }
}

///|
pub impl @style.StyleSpec for SelectStyle with fn merge(self, other) {
  @style.merge_sources(self, other, fn(a, b) {
    {
      source: None,
      surface: a.surface.merge(b.surface),
      label: a.label.merge(b.label),
      placeholder: a.placeholder.merge(b.placeholder),
      list: a.list.merge(b.list),
      option: a.option.merge(b.option),
      selected: a.selected.merge(b.selected),
    }
  })
}

///|
pub impl @style.StyleSpec for SelectStyle with fn root_style(self) {
  text_root_style(self.surface, self.label)
}

///|
pub impl @style.StyleSpec for SelectStyle with fn metrics(self) {
  StyleMetrics(fonts=[@style.style_value(self.placeholder).font])
}

///|
pub impl @style.StyleSpec for SelectStyle with fn split_source(self) {
  ({ ..self, source: None, }, self.source)
}

///|
pub impl @style.StyleSpec for SelectStyle with fn freeze_fields(self, sheet) {
  {
    ..self,
    surface: @style.freeze_style(self.surface, sheet),
    label: @style.freeze_style(self.label, sheet),
    placeholder: @style.freeze_style(self.placeholder, sheet),
    list: @style.freeze_style(self.list, sheet),
    option: @style.freeze_style(self.option, sheet),
    selected: @style.freeze_style(self.selected, sheet),
  }
}

///|
pub impl @style.StyleSpec for SelectStyle with fn has_source(self) {
  self.source is Some(_) ||
  @style.StyleSpec::has_source(self.surface) ||
  @style.StyleSpec::has_source(self.label) ||
  @style.StyleSpec::has_source(self.placeholder) ||
  @style.StyleSpec::has_source(self.list) ||
  @style.StyleSpec::has_source(self.option) ||
  @style.StyleSpec::has_source(self.selected)
}

///|
pub impl @style.SourceStyle for SelectStyle with fn with_source(self, source) {
  { ..self, source, }
}

///|
pub extend SelectStyle with @style.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
pub extend SelectStyle with @style.SourceStyle::{computed, bind}
