///|
/// Concrete declaration for TextInput; parts retain their own value types.
#derive(Eq, Debug, Default)
pub struct TextInputStyle {
  priv source : @style.StyleSource[TextInputStyle]?
  surface : @style.BoxStyle
  text : @view.TextStyle
  placeholder : @view.TextStyle
  caret_color : @style.StyleColor?
  selection_color : @style.StyleColor?
}

///|
pub extend TextInputStyle with Eq::{equal, not_equal}

///|
pub extend TextInputStyle with Debug::{to_repr}

///|
pub fn TextInputStyle::TextInputStyle() -> TextInputStyle {
  Default::default()
}

///|
pub fn TextInputStyle::surface(
  self : TextInputStyle,
  value : @style.BoxStyle,
) -> TextInputStyle {
  { ..self, surface: self.surface.merge(value), }
}

///|
pub fn TextInputStyle::text(
  self : TextInputStyle,
  value : @view.TextStyle,
) -> TextInputStyle {
  { ..self, text: self.text.merge(value), }
}

///|
pub fn TextInputStyle::placeholder(
  self : TextInputStyle,
  value : @view.TextStyle,
) -> TextInputStyle {
  { ..self, placeholder: self.placeholder.merge(value), }
}

///|
pub fn TextInputStyle::caret_color(
  self : TextInputStyle,
  value : &@style.ColorValue,
) -> TextInputStyle {
  { ..self, caret_color: Some(value.to_style_color()), }
}

///|
pub fn TextInputStyle::selection_color(
  self : TextInputStyle,
  value : &@style.ColorValue,
) -> TextInputStyle {
  { ..self, selection_color: Some(value.to_style_color()), }
}

///|
pub impl @style.StyleSpec for TextInputStyle with fn merge(self, other) {
  @style.merge_sources(self, other, fn(self, other) {
    {
      source: None,
      surface: self.surface.merge(other.surface),
      text: self.text.merge(other.text),
      placeholder: self.placeholder.merge(other.placeholder),
      caret_color: merge_style_option(self.caret_color, other.caret_color),
      selection_color: merge_style_option(
        self.selection_color,
        other.selection_color,
      ),
    }
  })
}

///|
pub fn TextInputStyle::hovered(
  self : TextInputStyle,
  value : @style.Appearance,
) -> TextInputStyle {
  { ..self, surface: self.surface.hovered(value), }
}

///|
pub fn TextInputStyle::focused(
  self : TextInputStyle,
  value : @style.Appearance,
) -> TextInputStyle {
  { ..self, surface: self.surface.focused(value), }
}

///|
pub fn TextInputStyle::pressed(
  self : TextInputStyle,
  value : @style.Appearance,
) -> TextInputStyle {
  { ..self, surface: self.surface.pressed(value), }
}

///|
pub fn TextInputStyle::disabled(
  self : TextInputStyle,
  value : @style.Appearance,
) -> TextInputStyle {
  { ..self, surface: self.surface.disabled(value), }
}

///|
pub impl @style.StyleSpec for TextInputStyle with fn root_style(self) {
  text_root_style(self.surface, self.text)
}

///|
pub impl @style.StyleSpec for TextInputStyle with fn metrics(self) {
  StyleMetrics(fonts=[@style.style_value(self.placeholder).font])
}

///|
pub extend TextInputStyle with @style.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
fn resolved_text_input_style(
  layers : ReadOnlyArray[@style.StyleDeclaration],
) -> TextInputStyle {
  let mut result = TextInputStyle()
  for layer in layers {
    let value : TextInputStyle? = layer.get()
    if value is Some(value) {
      result = result.merge(value)
    }
  }
  {
    ..result,
    surface: @style.style_value(result.surface),
    text: @style.style_value(result.text),
    placeholder: @style.style_value(result.placeholder),
  }
}

///|
pub impl @style.StyleSpec for TextInputStyle with fn split_source(self) {
  ({ ..self, source: None, }, self.source)
}

///|
pub impl @style.SourceStyle for TextInputStyle with fn with_source(self, source) {
  { ..self, source, }
}

///|
pub extend TextInputStyle with @style.SourceStyle::{computed, bind}

///|
pub impl @style.StyleSpec for TextInputStyle with fn freeze_fields(self, sheet) {
  {
    ..self,
    surface: @style.freeze_style(self.surface, sheet),
    text: @style.freeze_style(self.text, sheet),
    placeholder: @style.freeze_style(self.placeholder, sheet),
  }
}

///|
pub impl @style.StyleSpec for TextInputStyle with fn has_source(self) {
  self.source is Some(_) ||
  @style.StyleSpec::has_source(self.surface) ||
  @style.StyleSpec::has_source(self.text) ||
  @style.StyleSpec::has_source(self.placeholder)
}
