///|
/// Typed key for values shared by a component scope. Use an optional default
/// (None) for application values that require a provider.
///
/// ```mbt check
/// test {
///   let key = @reactive.Context(0)
///   assert_eq(@reactive.provide([key.provide(4)], fn() { key.get() }), 4)
///   assert_eq(key.get(), 0)
/// }
/// ```
pub struct Context[T] {
  priv default_value : T
  priv entries : Array[ContextEntry[T]?]
}

///|
priv struct ContextEntry[T] {
  scope : Scope
  value : T
  active : Ref[Bool]
}

///|
/// A typed value binding erased only at installation, for heterogeneous lists
/// of root or component providers. Values are owned by their caller.
pub struct ContextBinding {
  priv install : (Scope) -> Unit
}

///|
pub fn[T] Context::Context(default_value : T) -> Context[T] {
  { default_value, entries: [], }
}

///|
/// Read the nearest provider, or the key's default outside a live scope.
/// Lookup itself does not subscribe; provided signals track their own reads.
pub fn[T] Context::get(self : Self[T]) -> T {
  let mut current = @signals.get_owner()
  guard current is Some(owner) && !owner.disposed else {
    return self.default_value
  }
  while current is Some(owner) {
    for offset in 0..<self.entries.length() {
      let index = self.entries.length() - offset - 1
      if self.entries[index] is Some(entry) &&
        entry.active.val &&
        physical_equal(entry.scope.owner, owner) {
        return entry.value
      }
    }
    current = owner.parent
  }
  self.default_value
}

///|
/// Describe a binding; installation and cleanup belong to the consuming scope.
pub fn[T] Context::provide(self : Self[T], value : T) -> ContextBinding {
  {
    install: fn(scope) {
      let active = Ref(true)
      self.entries.push(Some({ scope, value, active, }))
      on_cleanup(fn() {
        active.val = false
        self.entries.retain(entry => {
          entry is Some({ active: { val: true, }, .. })
        })
        // Array.retain truncates length without releasing its backing slots.
        self.entries.release_unused(placeholder=None)
      })
    },
  }
}

///|
/// Build a nested context under this lifetime. An empty list preserves the
/// existing scope. Nonempty bindings live until their child scope is disposed.
pub fn[T] Scope::run_with(
  self : Scope,
  bindings : Array[ContextBinding],
  build : () -> T,
) -> T {
  if bindings.is_empty() || self.is_disposed() {
    return self.run(build)
  }
  let child = self.child()
  child.run(fn() {
    for binding in bindings {
      (binding.install)(child)
    }
    build()
  })
}

///|
/// Provide values while building components under their active lifetime.
/// Outside a scope this is a temporary lexical context, disposed on return;
/// live UI providers should be declared in App or its content builder.
pub fn[T] provide(bindings : Array[ContextBinding], build : () -> T) -> T {
  match Scope::current() {
    Some(scope) => scope.run_with(bindings, build)
    None => {
      let scope = Scope::root()
      defer scope.dispose()
      scope.run_with(bindings, build)
    }
  }
}
