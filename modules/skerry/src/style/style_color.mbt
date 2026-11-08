///|
/// A fixed paint color or a reference resolved in the consuming view's theme.
#derive(Eq, Debug)
pub(all) enum StyleColor {
  Literal(@foundation.Color)
  Token(ThemeToken[@foundation.Color])
}

///|
pub extend StyleColor with Eq::{equal, not_equal}

///|
pub extend StyleColor with Debug::{to_repr}

///|
/// Paint inputs accept literals and tokens through the same setters.
pub(open) trait ColorValue {
  fn to_style_color(Self) -> StyleColor
}

///|
pub impl ColorValue for @foundation.Color with fn to_style_color(self) {
  Literal(self)
}

///|
pub impl ColorValue for ThemeToken[@foundation.Color] with fn to_style_color(
  self,
) {
  Token(self)
}

///|
pub impl ColorValue for StyleColor with fn to_style_color(self) {
  self
}

///|
pub extend ThemeToken with ColorValue::{to_style_color}

///|
pub extend StyleColor with ColorValue::{to_style_color}

///|
pub fn StyleColor::resolve(
  self : StyleColor,
  theme : Theme,
) -> @foundation.Color {
  match self {
    Literal(color) => color
    Token(key) => theme.resolve(key)
  }
}
