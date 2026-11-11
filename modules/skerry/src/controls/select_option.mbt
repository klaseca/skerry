///|
/// A reusable description of one Select entry. The value belongs to the model;
/// label and disabled accept the same readonly sources as other controls.
/// Constructing an option does not read or subscribe to those sources. Each
/// mounted Select applies them independently and disposes its subscriptions.
/// Use distinct values within one Select; selection compares values through Eq.
pub struct SelectOption[T] {
  value : T
  priv label : @reactive.Binding[String]
  priv disabled : @reactive.Binding[Bool]
}

///|
/// Describe an option without requiring the value to implement Show.
///
/// ```mbt check
/// test {
///   let title = @reactive.signal("Administrator")
///   let blocked = @reactive.signal(false)
///   let option = @controls.SelectOption(1, label=title, disabled=blocked)
///   assert_eq(option.value, 1)
/// }
/// ```
pub fn[T] SelectOption::SelectOption(
  value : T,
  label~ : &@value.StringValue,
  disabled~ : &@value.BoolValue = false,
) -> SelectOption[T] {
  { value, label: label.to_binding(), disabled: disabled.to_binding(), }
}
