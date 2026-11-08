///|
/// Boolean properties accept a constant, a Signal, a Computed, or a Binding.
/// Conversion must describe the source without reading a producer or subscribing.
pub(open) trait BoolValue {
  fn to_binding(Self) -> @reactive.Binding[Bool]
}

///|
pub impl BoolValue for Bool with fn to_binding(self) {
  @reactive.val(self)
}

///|
pub impl BoolValue for @reactive.Signal[Bool] with fn to_binding(self) {
  self.bind()
}

///|
pub impl BoolValue for @reactive.Computed[Bool] with fn to_binding(self) {
  self.bind()
}

///|
pub impl BoolValue for @reactive.Binding[Bool] with fn to_binding(self) {
  self
}

///|
/// A String source. Formatting other types is explicit in the producer.
pub(open) trait StringValue {
  fn to_binding(Self) -> @reactive.Binding[String]
}

///|
pub impl StringValue for String with fn to_binding(self) {
  @reactive.val(self)
}

///|
pub impl StringValue for @reactive.Signal[String] with fn to_binding(self) {
  self.bind()
}

///|
pub impl StringValue for @reactive.Computed[String] with fn to_binding(self) {
  self.bind()
}

///|
pub impl StringValue for @reactive.Binding[String] with fn to_binding(self) {
  self
}

///|
/// A readonly integer source for fixed-type component properties.
pub(open) trait IntValue {
  fn to_binding(Self) -> @reactive.Binding[Int32]
}

///|
pub impl IntValue for Int32 with fn to_binding(self) {
  @reactive.val(self)
}

///|
pub impl IntValue for @reactive.Signal[Int32] with fn to_binding(self) {
  self.bind()
}

///|
pub impl IntValue for @reactive.Computed[Int32] with fn to_binding(self) {
  self.bind()
}

///|
pub impl IntValue for @reactive.Binding[Int32] with fn to_binding(self) {
  self
}

///|
/// A readonly Double source. Numeric conversions are explicit.
pub(open) trait DoubleValue {
  fn to_binding(Self) -> @reactive.Binding[Double]
}

///|
pub impl DoubleValue for Double with fn to_binding(self) {
  @reactive.val(self)
}

///|
pub impl DoubleValue for @reactive.Signal[Double] with fn to_binding(self) {
  self.bind()
}

///|
pub impl DoubleValue for @reactive.Computed[Double] with fn to_binding(self) {
  self.bind()
}

///|
pub impl DoubleValue for @reactive.Binding[Double] with fn to_binding(self) {
  self
}
