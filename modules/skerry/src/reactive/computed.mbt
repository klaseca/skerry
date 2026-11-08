///|
/// A readonly, lazily cached computation. All readers share one cache, which is
/// refreshed after a dependency changes. Construction does not read the source.
/// Capture model handles when constructing a computation shared across roots;
/// use bind for expressions that must resolve providers separately in each mount.
///
/// ```mbt check
/// test {
///   let count = @reactive.signal(2)
///   let doubled = @reactive.computed(() => count.get() * 2)
///   assert_eq(doubled.get(), 4)
///   count.set(3)
///   assert_eq(doubled.get(), 6)
/// }
/// ```
pub struct Computed[T] {
  priv read : () -> T
}

///|
/// Create a lazy cached value. Dependencies are tracked when get is called.
pub fn[T] computed(read : () -> T) -> Computed[T] {
  { read: @signals.computed(read), }
}

///|
/// Read the current value and track this computation in the active effect.
pub fn[T] Computed::get(self : Computed[T]) -> T {
  (self.read)()
}

///|
/// Describe this computation as a property source without reading it or creating
/// another cache. Each mounted consumer owns its subscription.
pub fn[T] Computed::bind(self : Computed[T]) -> Binding[T] {
  bind(fn() { self.get() })
}
