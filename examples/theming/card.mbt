///|
#derive(Eq, Debug, Default)
pub struct CardStyle {
  surface : @skerry.FlexStyle
  title : @skerry.TextStyle
}

///|
pub fn CardStyle::CardStyle() -> CardStyle {
  Default::default()
}

///|
pub fn CardStyle::surface(
  self : CardStyle,
  value : @skerry.FlexStyle,
) -> CardStyle {
  { ..self, surface: self.surface.merge(value), }
}

///|
pub fn CardStyle::title(
  self : CardStyle,
  value : @skerry.TextStyle,
) -> CardStyle {
  { ..self, title: self.title.merge(value), }
}

///|
pub impl @skerry.StyleSpec for CardStyle with fn merge(self, other) {
  {
    surface: self.surface.merge(other.surface),
    title: self.title.merge(other.title),
  }
}

///|
pub extend CardStyle with @skerry.StyleSpec::{
  merge,
  root_style,
  metrics,
  select,
}

///|
pub extend CardStyle with Eq::{equal, not_equal}

///|
pub extend CardStyle with Debug::{to_repr}

///|
pub fn card(
  title : String,
  children : Array[@skerry.View],
  style~ : CardStyle = CardStyle(),
) -> @skerry.View {
  @skerry.column(
    [@skerry.text(title, style=style.select(s => s.title)), ..children],
    style=style.select(s => s.surface),
  ).component("Card")
}
