///|
/// Owns the subscriptions created while building a UI root or dynamic branch.
pub struct Scope {
  priv owner : @signals.Owner
}

///|
/// Capture the current component lifetime without creating another owner.
pub fn Scope::current() -> Scope? {
  @signals.get_owner().map(owner => { owner, })
}

///|
/// Create an independent lifetime, even inside another scope.
pub fn Scope::root() -> Scope {
  { owner: @signals.Owner::new(None), }
}

///|
/// Create a scope owned by the current component, if one is active.
pub fn Scope::new() -> Scope {
  let parent = @signals.get_owner()
  let scope = { owner: @signals.Owner::new(parent), }
  if parent is Some(owner) && owner.disposed {
    scope.dispose()
  }
  scope
}

///|
/// Create a child that is disposed with this scope.
pub fn Scope::child(self : Scope) -> Scope {
  let scope = { owner: @signals.Owner::new(Some(self.owner)), }
  if self.is_disposed() {
    scope.dispose()
  }
  scope
}

///|
/// Build without subscribing the caller or inheriting its effect cleanup list.
pub fn[T] Scope::run(self : Scope, build : () -> T) -> T {
  let previous = @signals.set_current_cleanups(None)
  defer ignore(@signals.set_current_cleanups(previous))
  @signals.run_with_owner(self.owner, fn() { @signals.untracked(build) })
}

///|
/// Evaluate a value producer under this owner while preserving the active
/// effect's dependency tracking and cleanup list.
pub fn[T] Scope::track(self : Scope, read : () -> T) -> T {
  @signals.run_with_owner(self.owner, read)
}

///|
pub fn Scope::is_disposed(self : Scope) -> Bool {
  self.owner.disposed
}

///|
fn Scope::shares_root(self : Scope, other : Scope) -> Bool {
  let mut first = self.owner
  while first.parent is Some(parent) {
    first = parent
  }
  let mut second = other.owner
  while second.parent is Some(parent) {
    second = parent
  }
  physical_equal(first, second)
}

///|
/// Stop owned subscriptions and run cleanup once, children before parents.
pub fn Scope::dispose(self : Scope) -> Unit {
  self.run(fn() { self.owner.dispose() })
}

///|
/// Register component teardown, or cleanup before an effect's next run/disposal.
pub fn on_cleanup(cleanup : () -> Unit) -> Unit {
  let scope = Scope::current()
  let pending = Ref(Some((scope, cleanup)))
  let cleanup_once = fn() {
    guard pending.val is Some((scope, cleanup)) else { return }
    // Release captures even if a registry or saved disposer keeps this wrapper.
    // Clear before invoking application code so reentrant disposal is harmless.
    pending.val = None
    match scope {
      Some(scope) => scope.run(cleanup)
      None => @signals.untracked(cleanup)
    }
  }
  match scope {
    Some(scope) if scope.is_disposed() => cleanup_once()
    _ => @signals.on_cleanup(cleanup_once)
  }
}

///|
fn scoped_effect(
  callback : () -> Unit,
  create : (() -> Unit) -> () -> Unit,
) -> () -> Unit {
  let owner = @signals.get_owner()
  let scope = match owner {
    Some(owner) => Scope::{ owner, }
    None => Scope::root()
  }
  guard !scope.is_disposed() else { return fn() { () } }
  let active = Ref(true)
  let dispose = create(fn() {
    guard active.val && !scope.is_disposed() else { return }
    @signals.run_with_owner(scope.owner, callback)
  })
  let stop = fn() {
    guard active.val else { return }
    active.val = false
    if owner is None {
      scope.dispose()
    }
    @signals.untracked(dispose)
  }
  if scope.is_disposed() {
    stop()
  }
  stop
}

///|
/// On native, run immediately and synchronously after dependency updates.
pub fn effect(callback : () -> Unit) -> () -> Unit {
  scoped_effect(callback, @signals.effect)
}

///|
pub fn render_effect(callback : () -> Unit) -> () -> Unit {
  scoped_effect(callback, @signals.render_effect)
}

///|
/// Record the initial value; invoke the callback on subsequent value changes.
pub fn[T : Eq] watch(source : () -> T, callback : (T, T) -> Unit) -> () -> Unit {
  let previous : Ref[T?] = Ref(None)
  render_effect(fn() {
    let value = source()
    match previous.val {
      Some(old) if old != value => {
        callback(value, old)
        previous.val = Some(value)
      }
      None => previous.val = Some(value)
      _ => ()
    }
  })
}
