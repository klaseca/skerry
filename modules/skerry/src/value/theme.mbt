///|
/// A theme property accepts concrete data or an ordinary readonly reactive source.
/// Conversion does not evaluate a producer. Only the active scheme is read.
pub(open) trait ThemeSource {
  fn to_binding(Self) -> @reactive.Binding[@style.Theme]
}

///|
pub impl ThemeSource for @style.Theme with fn to_binding(self) {
  @reactive.val(self)
}

///|
pub impl ThemeSource for @reactive.Signal[@style.Theme] with fn to_binding(self) {
  self.bind()
}

///|
pub impl ThemeSource for @reactive.Computed[@style.Theme] with fn to_binding(
  self,
) {
  self.bind()
}

///|
pub impl ThemeSource for @reactive.Binding[@style.Theme] with fn to_binding(
  self,
) {
  self
}
