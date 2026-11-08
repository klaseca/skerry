///|
priv enum BindingSource[T] {
  Constant(T)
  Getter(() -> T)
}

///|
/// A readonly value source. Construction does not read the producer or subscribe.
/// Each subscriber owns its effect; constant sources need no effect. A producer
/// restores its construction context in the same root; a foreign mount supplies
/// its own context. Capture model handles when their identity must be retained.
///
/// ```mbt check
/// test {
///   let blocked = @reactive.signal(false)
///   let available = @reactive.bind(fn() { !blocked.get() })
///   assert_true(available.get())
///   blocked.set(true)
///   assert_false(available.get())
/// }
/// ```
pub struct Binding[T] {
  priv source : BindingSource[T]
}

///|
pub fn[T] bind(source : () -> T) -> Binding[T] {
  let scope = Scope::current()
  {
    source: Getter(fn() {
      match scope {
        Some(scope) if !scope.is_disposed() =>
          match Scope::current() {
            Some(current) if !scope.shares_root(current) => source()
            _ => scope.track(source)
          }
        _ => source()
      }
    }),
  }
}

///|
/// Describe a constant. Mounting a constant needs no reactive effect.
pub fn[T] val(value : T) -> Binding[T] {
  { source: Constant(value), }
}

///|
/// Read the current value, tracking dependencies in an active effect.
pub fn[T] Binding::get(self : Binding[T]) -> T {
  match self.source {
    Constant(value) => value
    Getter(source) => source()
  }
}

///|
/// Inspect a constant without evaluating a getter.
pub fn[T] Binding::constant_value(self : Binding[T]) -> T? {
  match self.source {
    Constant(value) => Some(value)
    Getter(_) => None
  }
}

///|
/// Deliver the initial value synchronously, then changed values untracked.
/// The subscription belongs to the current scope; its disposer is idempotent.
pub fn[T : Eq] Binding::subscribe(
  self : Binding[T],
  receive : (T) -> Unit,
) -> () -> Unit {
  match self.source {
    Constant(value) => {
      untracked(fn() { receive(value) })
      fn() { () }
    }
    Getter(source) => {
      let previous : Ref[T?] = Ref(None)
      render_effect(fn() {
        let value = source()
        if previous.val is None || (previous.val is Some(old) && old != value) {
          previous.val = Some(value)
          untracked(fn() { receive(value) })
        }
      })
    }
  }
}
