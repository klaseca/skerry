///|
#derive(Eq, Debug, Default)
pub struct TextAppearance {
  color : @style.StyleColor?
}

///|
pub fn TextAppearance::TextAppearance() -> TextAppearance {
  Default::default()
}

///|
pub fn TextAppearance::color(
  _self : TextAppearance,
  value : &@style.ColorValue,
) -> TextAppearance {
  { color: Some(value.to_style_color()), }
}

///|
pub extend TextAppearance with Eq::{equal, not_equal}

///|
pub extend TextAppearance with Debug::{to_repr}

///|
#derive(Eq, Debug, Default)
pub struct TextStates {
  hovered : TextAppearance?
  pressed : TextAppearance?
  focused : TextAppearance?
  disabled : TextAppearance?
}

///|
pub extend TextStates with Eq::{equal, not_equal}

///|
pub extend TextStates with Debug::{to_repr}

///|
#derive(Eq, Debug, Default)
pub struct TextStyle {
  priv source : @style.StyleSource[TextStyle]?
  frame : @style.BoxStyle
  font : @foundation.FontSpec?
  color : @style.StyleColor?
  align : @foundation.TextAlign?
  controls : TextStates
}

///|
pub fn TextStyle::TextStyle() -> TextStyle {
  Default::default()
}

///|
/// Compose a frame and its text defaults. Explicit font/color/alignment and
/// text-state colors from this fragment override earlier values field by field.
pub fn TextStyle::frame(self : TextStyle, value : @style.BoxStyle) -> TextStyle {
  @style.apply_style_field(self, value, fn(self, value) {
    let text_state = fn(appearance : @style.Appearance) {
      TextAppearance::{ color: appearance.color, }
    }
    self.merge({
      source: None,
      frame: value,
      font: value.text.font,
      color: value.paint.color,
      align: value.text.align,
      controls: {
        hovered: value.controls.hovered.map(text_state),
        pressed: value.controls.pressed.map(text_state),
        focused: value.controls.focused.map(text_state),
        disabled: value.controls.disabled.map(text_state),
      },
    })
  })
}

///|
pub fn TextStyle::font(
  self : TextStyle,
  font : @foundation.FontSpec,
) -> TextStyle {
  { ..self, font: Some(font), }
}

///|
pub fn TextStyle::color(
  self : TextStyle,
  value : &@style.ColorValue,
) -> TextStyle {
  { ..self, color: Some(value.to_style_color()), }
}

///|
pub fn TextStyle::align(
  self : TextStyle,
  align : @foundation.TextAlign,
) -> TextStyle {
  { ..self, align: Some(align), }
}

///|
pub impl @style.StyleSpec for TextStyle with fn merge(self, other) {
  @style.merge_sources(self, other, fn(self, other) {
    {
      source: None,
      frame: self.frame.merge(other.frame),
      font: merge_style_option(self.font, other.font),
      color: merge_style_option(self.color, other.color),
      align: merge_style_option(self.align, other.align),
      controls: {
        hovered: merge_text_appearance(
          self.controls.hovered,
          other.controls.hovered,
        ),
        pressed: merge_text_appearance(
          self.controls.pressed,
          other.controls.pressed,
        ),
        focused: merge_text_appearance(
          self.controls.focused,
          other.controls.focused,
        ),
        disabled: merge_text_appearance(
          self.controls.disabled,
          other.controls.disabled,
        ),
      },
    }
  })
}

///|
fn merge_text_appearance(
  a : TextAppearance?,
  b : TextAppearance?,
) -> TextAppearance? {
  match (a, b) {
    (Some(a), Some(b)) => Some({ color: merge_style_option(a.color, b.color), })
    (_, Some(_)) => b
    _ => a
  }
}

///|
fn[T] merge_style_option(a : T?, b : T?) -> T? {
  match b {
    Some(_) => b
    None => a
  }
}

///|
fn text_root_style(
  surface : @style.BoxStyle,
  text : TextStyle,
) -> @style.BoxStyle {
  let text = @style.style_value(text)
  let surface = match text.font {
    Some(font) => surface.font(font)
    None => surface
  }
  match text.align {
    Some(align) => surface.align(align)
    None => surface
  }
}

///|
pub impl @style.StyleSpec for TextStyle with fn root_style(self) {
  let mut root = text_root_style(self.frame, self)
  if self.color is Some(color) {
    root = root.color(color)
  }
  if self.controls.hovered is Some({ color: Some(color), }) {
    root = root.hovered(@style.Appearance().color(color))
  }
  if self.controls.pressed is Some({ color: Some(color), }) {
    root = root.pressed(@style.Appearance().color(color))
  }
  if self.controls.focused is Some({ color: Some(color), }) {
    root = root.focused(@style.Appearance().color(color))
  }
  if self.controls.disabled is Some({ color: Some(color), }) {
    root = root.disabled(@style.Appearance().color(color))
  }
  root
}

///|
pub extend TextStyle with @style.StyleSpec::{merge, root_style, metrics, select}

///|
pub extend TextStyle with Eq::{equal, not_equal}

///|
pub extend TextStyle with Debug::{to_repr}

///|
pub fn TextStyle::padding(
  self : TextStyle,
  value : @foundation.Insets,
) -> TextStyle {
  { ..self, frame: self.frame.padding(value), }
}

///|
pub fn TextStyle::width(
  self : TextStyle,
  value : &@value.DoubleValue,
) -> TextStyle {
  self.frame(self.frame.width(value))
}

///|
pub fn TextStyle::height(
  self : TextStyle,
  value : &@value.DoubleValue,
) -> TextStyle {
  self.frame(self.frame.height(value))
}

///|
pub fn TextStyle::min_width(
  self : TextStyle,
  value : &@value.DoubleValue,
) -> TextStyle {
  self.frame(self.frame.min_width(value))
}

///|
pub fn TextStyle::max_width(
  self : TextStyle,
  value : &@value.DoubleValue,
) -> TextStyle {
  self.frame(self.frame.max_width(value))
}

///|
pub fn TextStyle::min_height(
  self : TextStyle,
  value : &@value.DoubleValue,
) -> TextStyle {
  self.frame(self.frame.min_height(value))
}

///|
pub fn TextStyle::max_height(
  self : TextStyle,
  value : &@value.DoubleValue,
) -> TextStyle {
  self.frame(self.frame.max_height(value))
}

///|
pub fn TextStyle::grow(
  self : TextStyle,
  value : &@value.DoubleValue,
) -> TextStyle {
  self.frame(self.frame.grow(value))
}

///|
pub fn TextStyle::shrink(
  self : TextStyle,
  value : &@value.DoubleValue,
) -> TextStyle {
  self.frame(self.frame.shrink(value))
}

///|
pub fn TextStyle::align_self(
  self : TextStyle,
  value : @style.AlignSelf,
) -> TextStyle {
  { ..self, frame: self.frame.align_self(value), }
}

///|
pub fn TextStyle::hovered(
  self : TextStyle,
  value : TextAppearance,
) -> TextStyle {
  {
    ..self,
    controls: {
      ..self.controls,
      hovered: merge_text_appearance(self.controls.hovered, Some(value)),
    },
  }
}

///|
pub fn TextStyle::pressed(
  self : TextStyle,
  value : TextAppearance,
) -> TextStyle {
  {
    ..self,
    controls: {
      ..self.controls,
      pressed: merge_text_appearance(self.controls.pressed, Some(value)),
    },
  }
}

///|
pub fn TextStyle::focused(
  self : TextStyle,
  value : TextAppearance,
) -> TextStyle {
  {
    ..self,
    controls: {
      ..self.controls,
      focused: merge_text_appearance(self.controls.focused, Some(value)),
    },
  }
}

///|
pub fn TextStyle::disabled(
  self : TextStyle,
  value : TextAppearance,
) -> TextStyle {
  {
    ..self,
    controls: {
      ..self.controls,
      disabled: merge_text_appearance(self.controls.disabled, Some(value)),
    },
  }
}

///|
pub impl @style.StyleSpec for TextStyle with fn split_source(self) {
  ({ ..self, source: None, }, self.source)
}

///|
pub impl @style.SourceStyle for TextStyle with fn with_source(self, source) {
  { ..self, source, }
}

///|
pub extend TextStyle with @style.SourceStyle::{computed, bind}

///|
pub impl @style.StyleSpec for TextStyle with fn freeze_fields(self, sheet) {
  { ..self, frame: @style.freeze_style(self.frame, sheet), }
}

///|
pub impl @style.StyleSpec for TextStyle with fn has_source(self) {
  self.source is Some(_) || @style.StyleSpec::has_source(self.frame)
}
