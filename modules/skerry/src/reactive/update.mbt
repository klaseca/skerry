///|
let updating : Ref[Bool] = Ref(false)

///|
let draining_updates : Ref[Bool] = Ref(false)

///|
let update_callbacks : Array[() -> Unit] = []

///|
/// Framework delivery boundary: values materialize before lifecycle callbacks.
pub fn is_updating() -> Bool {
  updating.val || @signals.is_batching()
}

///|
pub fn after_update(callback : () -> Unit) -> Unit {
  let scope = Scope::current()
  let run = fn() {
    match scope {
      Some(scope) if !scope.is_disposed() => scope.run(callback)
      None => untracked(callback)
      _ => ()
    }
  }
  if is_updating() || draining_updates.val {
    update_callbacks.push(run)
  } else {
    run()
  }
}

///|
fn drain_update_callbacks() -> Unit {
  guard !draining_updates.val else { return }
  draining_updates.val = true
  defer (fn() {
    update_callbacks.release_unused(placeholder=fn() { () })
    draining_updates.val = false
  })()
  while !update_callbacks.is_empty() {
    let next = update_callbacks.remove(0)
    next()
  }
}

///|
/// Framework delivery boundary without batching signal writes. This lets input
/// handlers reconcile the tree before a default action, while lifecycle and
/// frame notifications wait until the entire action has finished.
pub fn[T] during_update(update : () -> T) -> T {
  let previous = updating.val
  updating.val = true
  defer (fn() {
    updating.val = previous
    if !is_updating() {
      drain_update_callbacks()
    }
  })()
  update()
}

///|
pub fn[T] batch(callback : () -> T) -> T {
  during_update(fn() { @signals.batch(callback) })
}

///|
pub fn batch_start() -> Unit {
  @signals.batch_start()
}

///|
pub fn batch_end() -> Unit {
  during_update(fn() { @signals.batch_end() })
}
