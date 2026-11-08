///|
pub struct Signal[T] {
  priv inner : @signals.Signal[T]
}

///|
pub fn[T] signal(value : T) -> Signal[T] {
  { inner: @signals.signal(value), }
}

///|
pub fn[T] Signal::get(self : Self[T]) -> T {
  self.inner.get()
}

///|
pub fn[T] Signal::peek(self : Self[T]) -> T {
  self.inner.peek()
}

///|
/// Describe this signal as a readonly source, without reading or subscribing.
pub fn[T] Signal::bind(self : Self[T]) -> Binding[T] {
  bind(fn() { self.get() })
}

///|
pub fn[T] Signal::set(self : Self[T], value : T) -> Unit {
  during_update(fn() { self.inner.set(value) })
}

///|
pub fn[T] Signal::update(self : Self[T], update : (T) -> T) -> Unit {
  during_update(fn() { self.inner.update(update) })
}

///|
pub using @signals {untracked}
