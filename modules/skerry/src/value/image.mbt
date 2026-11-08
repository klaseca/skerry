///|
pub(open) trait ImageValue {
  fn to_binding(Self) -> @reactive.Binding[@foundation.Image]
}

///|
pub impl ImageValue for @foundation.Image with fn to_binding(self) {
  @reactive.val(self)
}

///|
pub impl ImageValue for @reactive.Signal[@foundation.Image] with fn to_binding(
  self,
) {
  self.bind()
}

///|
pub impl ImageValue for @reactive.Computed[@foundation.Image] with fn to_binding(
  self,
) {
  self.bind()
}

///|
pub impl ImageValue for @reactive.Binding[@foundation.Image] with fn to_binding(
  self,
) {
  self
}
