///|
/// Defaults belonging to a mounted root or themed subtree. Font is inherited
/// by text and controls unless a view or its ancestor supplies BoxStyle.font.
/// Class declarations apply directly to matching views, including their font.
#derive(Eq, Debug)
pub(all) struct Theme {
  font : @foundation.FontSpec
  tokens : TokenValues
  styles : Styles
}

///|
pub extend Theme with Eq::{equal, not_equal}

///|
pub extend Theme with Debug::{to_repr}

///|
pub fn Theme::Theme(
  font~ : @foundation.FontSpec = @foundation.FontSpec::default(),
  palette~ : Palette = Palette(),
  styles~ : Styles = Styles(),
  tokens~ : TokenValues = TokenValues(),
) -> Theme {
  { font, tokens: palette.tokens().merge(tokens), styles, }
}

///|
/// Fill the built-in color tokens from a preset. Custom tokens, fonts and styles
/// are retained. Later token assignments replace values in this same collection.
pub fn Theme::palette(self : Theme, palette : Palette) -> Theme {
  { ..self, tokens: self.tokens.merge(palette.tokens()), }
}

///|
/// Copy defaults without retaining reactive rule producers. Materialized rules
/// are available in each painted node's diagnostic style_layers instead.
pub fn Theme::snapshot(self : Theme) -> Theme {
  { ..self, styles: self.styles.snapshot(), }
}
