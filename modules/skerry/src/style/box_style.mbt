///|
#derive(Debug, Eq, Default)
pub struct LayoutStyle {
  width : Double?
  height : Double?
  min_width : Double?
  max_width : Double?
  min_height : Double?
  max_height : Double?
  padding : @foundation.Insets?
}

///|
#derive(Debug, Eq, Default)
pub struct TextProperties {
  font : @foundation.FontSpec?
  align : @foundation.TextAlign?
}

///|
#derive(Debug, Eq, Default)
pub struct FlexItemStyle {
  grow : Double?
  shrink : Double?
  align_self : AlignSelf?
}

///|
#derive(Debug, Eq, Default)
pub struct BoxStyle {
  priv source : StyleSource[BoxStyle]?
  layout : LayoutStyle
  paint : Appearance
  text : TextProperties
  flex : FlexItemStyle
  controls : ControlStyles
}

///|
pub extend LayoutStyle with Debug::{to_repr}

///|
pub extend LayoutStyle with Eq::{equal, not_equal}

///|
pub extend TextProperties with Debug::{to_repr}

///|
pub extend TextProperties with Eq::{equal, not_equal}

///|
pub extend FlexItemStyle with Debug::{to_repr}

///|
pub extend FlexItemStyle with Eq::{equal, not_equal}

///|
pub extend BoxStyle with Debug::{to_repr}

///|
pub extend BoxStyle with Eq::{equal, not_equal}

///|
/// Start with unset properties. Setters compose reusable fragments; explicitly
/// supplied fields override earlier values, and merge composes complete styles.
///
/// ```mbt check
/// test {
///   let surface = @style.Appearance()
///     .background(@foundation.Color::accent())
///     .radius(6.0)
///     .stroke(@foundation.Color::black())
///   let base = @style.BoxStyle()
///     .appearance(surface)
///     .width(120.0)
///     .hovered(surface.color(@foundation.Color::white()))
///   let adjusted = base.background(@foundation.Color::black())
///   let merged = base.merge(
///     @style.BoxStyle().appearance(@style.Appearance().radius(0.0)),
///   )
///   assert_eq(base.paint, surface)
///   assert_eq(
///     adjusted.paint.background,
///     Some(Literal(@foundation.Color::black())),
///   )
///   assert_eq(adjusted.paint.radius, Some(6.0))
///   assert_eq(merged.paint.background, surface.background)
///   assert_eq(merged.paint.radius, Some(0.0))
///   assert_eq(merged.layout.width, base.layout.width)
/// }
/// ```
pub fn BoxStyle::BoxStyle() -> BoxStyle {
  Default::default()
}

///|
/// Compose a reusable normal appearance without changing layout or states.
pub fn BoxStyle::appearance(self : BoxStyle, value : Appearance) -> BoxStyle {
  { ..self, paint: self.paint.merge(value), }
}

///|
/// Override only explicitly supplied fields, preserving the original values.
/// Zero remains an explicit value rather than falling back to a default.
///
/// ```mbt check
/// test {
///   let base = @style.BoxStyle().width(80.0).radius(6.0)
///   let merged = base.merge(@style.BoxStyle().radius(0.0))
///   assert_eq(merged.layout.width, Some(80.0))
///   assert_eq(merged.paint.radius, Some(0.0))
///   assert_eq(base.paint.radius, Some(6.0))
/// }
/// ```
pub impl StyleSpec for BoxStyle with fn merge(self, other) {
  merge_sources(self, other, fn(self, other) {
    {
      source: None,
      layout: {
        width: merge_option(self.layout.width, other.layout.width),
        height: merge_option(self.layout.height, other.layout.height),
        min_width: merge_option(self.layout.min_width, other.layout.min_width),
        max_width: merge_option(self.layout.max_width, other.layout.max_width),
        min_height: merge_option(
          self.layout.min_height,
          other.layout.min_height,
        ),
        max_height: merge_option(
          self.layout.max_height,
          other.layout.max_height,
        ),
        padding: merge_option(self.layout.padding, other.layout.padding),
      },
      paint: self.paint.merge(other.paint),
      text: {
        font: merge_option(self.text.font, other.text.font),
        align: merge_option(self.text.align, other.text.align),
      },
      flex: {
        grow: merge_option(self.flex.grow, other.flex.grow),
        shrink: merge_option(self.flex.shrink, other.flex.shrink),
        align_self: merge_option(self.flex.align_self, other.flex.align_self),
      },
      controls: self.controls.merge(other.controls),
    }
  })
}

///|
/// Set the font for this view and its descendants. A closer BoxStyle.font wins;
/// otherwise the nearest theme supplies the default. Color and alignment keep
/// their existing per-view behavior.
pub fn BoxStyle::font(self : BoxStyle, font : @foundation.FontSpec) -> BoxStyle {
  { ..self, text: { ..self.text, font: Some(font), }, }
}

///|
pub fn BoxStyle::color(self : BoxStyle, color : &ColorValue) -> BoxStyle {
  { ..self, paint: self.paint.color(color), }
}

///|
pub fn BoxStyle::background(self : BoxStyle, color : &ColorValue) -> BoxStyle {
  { ..self, paint: self.paint.background(color), }
}

///|
pub fn BoxStyle::align(
  self : BoxStyle,
  align : @foundation.TextAlign,
) -> BoxStyle {
  { ..self, text: { ..self.text, align: Some(align), }, }
}

///|
pub fn BoxStyle::radius(self : BoxStyle, radius : Double) -> BoxStyle {
  { ..self, paint: self.paint.radius(radius), }
}

///|
/// Paint an outline without reserving layout space. Zero hides it.
pub fn BoxStyle::stroke(
  self : BoxStyle,
  color : &ColorValue,
  width~ : Double = 1.0,
) -> BoxStyle {
  { ..self, paint: self.paint.stroke(color, width~), }
}

///|
pub fn BoxStyle::padding(
  self : BoxStyle,
  padding : @foundation.Insets,
) -> BoxStyle {
  { ..self, layout: { ..self.layout, padding: Some(padding), }, }
}

///|
pub fn BoxStyle::width(
  self : BoxStyle,
  width : &@value.DoubleValue,
) -> BoxStyle {
  apply_style_value(self, width.to_binding(), fn(self, width) {
    { ..self, layout: { ..self.layout, width: Some(width), }, }
  })
}

///|
pub fn BoxStyle::height(
  self : BoxStyle,
  height : &@value.DoubleValue,
) -> BoxStyle {
  apply_style_value(self, height.to_binding(), fn(self, height) {
    { ..self, layout: { ..self.layout, height: Some(height), }, }
  })
}

///|
/// Minimum outer width in logical UI units, including padding. Use zero to allow a flex
/// item to shrink below its automatic content minimum.
pub fn BoxStyle::min_width(
  self : BoxStyle,
  width : &@value.DoubleValue,
) -> BoxStyle {
  apply_style_value(self, width.to_binding(), fn(self, width) {
    { ..self, layout: { ..self.layout, min_width: Some(width), }, }
  })
}

///|
/// Maximum outer width in logical UI units, including padding.
pub fn BoxStyle::max_width(
  self : BoxStyle,
  width : &@value.DoubleValue,
) -> BoxStyle {
  apply_style_value(self, width.to_binding(), fn(self, width) {
    { ..self, layout: { ..self.layout, max_width: Some(width), }, }
  })
}

///|
/// Minimum outer height in logical UI units, including padding.
pub fn BoxStyle::min_height(
  self : BoxStyle,
  height : &@value.DoubleValue,
) -> BoxStyle {
  apply_style_value(self, height.to_binding(), fn(self, height) {
    { ..self, layout: { ..self.layout, min_height: Some(height), }, }
  })
}

///|
/// Maximum outer height in logical UI units, including padding.
pub fn BoxStyle::max_height(
  self : BoxStyle,
  height : &@value.DoubleValue,
) -> BoxStyle {
  apply_style_value(self, height.to_binding(), fn(self, height) {
    { ..self, layout: { ..self.layout, max_height: Some(height), }, }
  })
}

///|
/// Share positive free space on the parent row/column's main axis. The default
/// is zero; the item's preferred size remains its flex basis.
pub fn BoxStyle::grow(
  self : BoxStyle,
  weight : &@value.DoubleValue,
) -> BoxStyle {
  apply_style_value(self, weight.to_binding(), fn(self, weight) {
    { ..self, flex: { ..self.flex, grow: Some(weight), }, }
  })
}

///|
/// Share a space deficit on the parent row/column's main axis, weighted by the
/// item's preferred size. The default is one; zero preserves that size.
pub fn BoxStyle::shrink(
  self : BoxStyle,
  weight : &@value.DoubleValue,
) -> BoxStyle {
  apply_style_value(self, weight.to_binding(), fn(self, weight) {
    { ..self, flex: { ..self.flex, shrink: Some(weight), }, }
  })
}

///|
fn[T] merge_option(base : T?, next : T?) -> T? {
  match next {
    Some(_) => next
    None => base
  }
}

///|
pub impl StyleSpec for BoxStyle with fn root_style(self) {
  self
}

///|
pub extend BoxStyle with StyleSpec::{merge, root_style, metrics, select}

///|
pub impl StyleSpec for BoxStyle with fn split_source(self) {
  ({ ..self, source: None, }, self.source)
}

///|
pub impl SourceStyle for BoxStyle with fn with_source(self, source) {
  { ..self, source, }
}

///|
pub extend BoxStyle with SourceStyle::{computed, bind}
