///|
/// A proposed control value, delivered before its default state update.
pub struct ChangeEvent[T] {
  value : T
  priv mut prevented : Bool
}

///|
pub fn[T] ChangeEvent::ChangeEvent(value : T) -> ChangeEvent[T] {
  { value, prevented: false, }
}

///|
/// Cancel the default update. Calling this again has no additional effect.
pub fn[T] ChangeEvent::prevent_default(self : ChangeEvent[T]) -> Unit {
  self.prevented = true
}

///|
pub fn[T] ChangeEvent::default_prevented(self : ChangeEvent[T]) -> Bool {
  self.prevented
}
