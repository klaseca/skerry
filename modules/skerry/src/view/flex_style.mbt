///|
/// Full row/column style. Item participation belongs to surface.flex; these
/// properties arrange the children of this particular flex container.
#derive(Eq, Debug, Default)
pub struct FlexStyle {
  priv source : @style.StyleSource[FlexStyle]?
  surface : @style.BoxStyle
  spacing : Double?
  justify_content : @style.JustifyContent?
  align_items : @style.AlignItems?
}

///|
pub fn FlexStyle::FlexStyle() -> FlexStyle {
  Default::default()
}

///|
pub fn FlexStyle::surface(
  self : FlexStyle,
  value : @style.BoxStyle,
) -> FlexStyle {
  { ..self, surface: self.surface.merge(value), }
}

///|
pub impl @style.StyleSpec for FlexStyle with fn merge(self, other) {
  @style.merge_sources(self, other, fn(self, other) {
    {
      source: None,
      surface: self.surface.merge(other.surface),
      spacing: merge_style_option(self.spacing, other.spacing),
      justify_content: merge_style_option(
        self.justify_content,
        other.justify_content,
      ),
      align_items: merge_style_option(self.align_items, other.align_items),
    }
  })
}

///|
pub impl @style.StyleSpec for FlexStyle with fn root_style(self) {
  self.surface
}

///|
pub impl @style.StyleSpec for FlexStyle with fn metrics(self) {
  StyleMetrics(dimensions=[self.spacing], flags=[
    self.justify_content.map(value => {
      match value {
        Start => 0
        Center => 1
        End => 2
        SpaceBetween => 3
        SpaceAround => 4
        SpaceEvenly => 5
      }
    }),
    self.align_items.map(value => {
      match value {
        Start => 0
        Center => 1
        End => 2
        Stretch => 3
      }
    }),
  ])
}

///|
pub extend FlexStyle with @style.StyleSpec::{merge, root_style, metrics, select}

///|
pub extend FlexStyle with Eq::{equal, not_equal}

///|
pub extend FlexStyle with Debug::{to_repr}

///|
pub fn FlexStyle::spacing(
  self : FlexStyle,
  value : &@value.DoubleValue,
) -> FlexStyle {
  @style.apply_style_value(self, value.to_binding(), fn(self, value) {
    { ..self, spacing: Some(value), }
  })
}

///|
pub fn FlexStyle::justify_content(
  self : FlexStyle,
  value : @style.JustifyContent,
) -> FlexStyle {
  { ..self, justify_content: Some(value), }
}

///|
pub fn FlexStyle::align_items(
  self : FlexStyle,
  value : @style.AlignItems,
) -> FlexStyle {
  { ..self, align_items: Some(value), }
}

///|
pub fn FlexStyle::padding(
  self : FlexStyle,
  value : @foundation.Insets,
) -> FlexStyle {
  { ..self, surface: self.surface.padding(value), }
}

///|
pub fn FlexStyle::font(
  self : FlexStyle,
  value : @foundation.FontSpec,
) -> FlexStyle {
  { ..self, surface: self.surface.font(value), }
}

///|
pub fn FlexStyle::width(
  self : FlexStyle,
  value : &@value.DoubleValue,
) -> FlexStyle {
  self.surface(self.surface.width(value))
}

///|
pub fn FlexStyle::height(
  self : FlexStyle,
  value : &@value.DoubleValue,
) -> FlexStyle {
  self.surface(self.surface.height(value))
}

///|
pub fn FlexStyle::min_width(
  self : FlexStyle,
  value : &@value.DoubleValue,
) -> FlexStyle {
  self.surface(self.surface.min_width(value))
}

///|
pub fn FlexStyle::max_width(
  self : FlexStyle,
  value : &@value.DoubleValue,
) -> FlexStyle {
  self.surface(self.surface.max_width(value))
}

///|
pub fn FlexStyle::min_height(
  self : FlexStyle,
  value : &@value.DoubleValue,
) -> FlexStyle {
  self.surface(self.surface.min_height(value))
}

///|
pub fn FlexStyle::max_height(
  self : FlexStyle,
  value : &@value.DoubleValue,
) -> FlexStyle {
  self.surface(self.surface.max_height(value))
}

///|
pub fn FlexStyle::grow(
  self : FlexStyle,
  value : &@value.DoubleValue,
) -> FlexStyle {
  self.surface(self.surface.grow(value))
}

///|
pub fn FlexStyle::shrink(
  self : FlexStyle,
  value : &@value.DoubleValue,
) -> FlexStyle {
  self.surface(self.surface.shrink(value))
}

///|
pub fn FlexStyle::align_self(
  self : FlexStyle,
  value : @style.AlignSelf,
) -> FlexStyle {
  { ..self, surface: self.surface.align_self(value), }
}

///|
pub fn FlexStyle::background(
  self : FlexStyle,
  value : &@style.ColorValue,
) -> FlexStyle {
  { ..self, surface: self.surface.background(value), }
}

///|
pub fn FlexStyle::color(
  self : FlexStyle,
  value : &@style.ColorValue,
) -> FlexStyle {
  { ..self, surface: self.surface.color(value), }
}

///|
pub fn FlexStyle::radius(self : FlexStyle, value : Double) -> FlexStyle {
  { ..self, surface: self.surface.radius(value), }
}

///|
pub fn FlexStyle::align(
  self : FlexStyle,
  value : @foundation.TextAlign,
) -> FlexStyle {
  { ..self, surface: self.surface.align(value), }
}

///|
pub fn FlexStyle::hovered(
  self : FlexStyle,
  value : @style.Appearance,
) -> FlexStyle {
  { ..self, surface: self.surface.hovered(value), }
}

///|
pub fn FlexStyle::pressed(
  self : FlexStyle,
  value : @style.Appearance,
) -> FlexStyle {
  { ..self, surface: self.surface.pressed(value), }
}

///|
pub fn FlexStyle::focused(
  self : FlexStyle,
  value : @style.Appearance,
) -> FlexStyle {
  { ..self, surface: self.surface.focused(value), }
}

///|
pub fn FlexStyle::disabled(
  self : FlexStyle,
  value : @style.Appearance,
) -> FlexStyle {
  { ..self, surface: self.surface.disabled(value), }
}

///|
pub fn FlexStyle::stroke(
  self : FlexStyle,
  color : &@style.ColorValue,
  width~ : Double = 1.0,
) -> FlexStyle {
  { ..self, surface: self.surface.stroke(color, width~), }
}

///|
pub fn FlexStyle::outline(
  self : FlexStyle,
  color : &@style.ColorValue,
  width~ : Double = 2.0,
  offset~ : Double = 2.0,
) -> FlexStyle {
  { ..self, surface: self.surface.outline(color, width~, offset~), }
}

///|
fn resolved_flex_style(
  layers : ReadOnlyArray[@style.StyleDeclaration],
) -> FlexStyle {
  let mut result = FlexStyle()
  let mut surface = @style.BoxStyle()
  for layer in layers {
    let value : FlexStyle? = layer.get()
    if value is Some(value) {
      result = result.merge(value)
    }
    // A wrapping component can also supply common root geometry. Keep it in
    // the same order used by paint, inherited fonts and layout invalidation.
    surface = surface.merge(layer.layout)
  }
  { ..result, surface, }
}

///|
pub impl @style.StyleSpec for FlexStyle with fn split_source(self) {
  ({ ..self, source: None, }, self.source)
}

///|
pub impl @style.SourceStyle for FlexStyle with fn with_source(self, source) {
  { ..self, source, }
}

///|
pub extend FlexStyle with @style.SourceStyle::{computed, bind}

///|
pub impl @style.StyleSpec for FlexStyle with fn freeze_fields(self, sheet) {
  { ..self, surface: @style.freeze_style(self.surface, sheet), }
}

///|
pub impl @style.StyleSpec for FlexStyle with fn has_source(self) {
  self.source is Some(_) || @style.StyleSpec::has_source(self.surface)
}
