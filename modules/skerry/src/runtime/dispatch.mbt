///|
priv struct UiAction {
  mut callback : (() -> Unit)?
  scope : @reactive.Scope
}

///|
/// Defer work to the UI host's next action pass. Call on the UI thread, including
/// completion callbacks already marshalled there by a native event bridge.
/// The returned function cancels delivery; root or posting scope disposal also
/// prevents delivery. Cancellation does not undo an action that already ran.
pub fn UiRoot::post(self : UiRoot, callback : () -> Unit) -> () -> Unit {
  let scope = @reactive.Scope::current().unwrap_or(self.scope)
  guard !self.disposed && !scope.is_disposed() else { return fn() { () } }
  let action : UiAction = { callback: Some(callback), scope, }
  let was_empty = self.actions.is_empty()
  self.actions.push(action)
  if was_empty {
    self.wakeup()
  }
  fn() { action.callback = None }
}

///|
pub fn UiRoot::has_pending_actions(self : UiRoot) -> Bool {
  self.next_action_delay() == Some(0)
}

///|
/// Hosts call this after input and before layout/paint. One snapshot of the
/// queue runs FIFO in a batch, untracked in each posting scope. Nested posts
/// wait for the next pass; draining during paint or another drain is ignored.
pub fn UiRoot::drain_actions(self : UiRoot) -> Unit {
  guard !self.disposed &&
    !self.draining_actions &&
    !self.painting &&
    !self.presenting &&
    !self.notifying_snapshot else {
    return
  }
  self.prune_actions()
  if !self.timers.is_empty() {
    let now = @reactive.untracked(self.clock)
    let pending : Array[UiTimer] = []
    for timer in self.timers {
      if timer.deadline <= now {
        self.actions.push(timer.action)
      } else {
        pending.push(timer)
      }
    }
    self.timers = pending
  }
  guard !self.actions.is_empty() else { return }
  let actions = self.actions
  self.actions = []
  self.draining_actions = true
  defer (fn() { self.draining_actions = false })()
  self.run_actions(actions)
}

///|
fn UiRoot::run_actions(self : UiRoot, actions : Array[UiAction]) -> Unit {
  @reactive.batch(fn() {
    for action in actions {
      let callback = action.callback
      action.callback = None
      if !self.disposed &&
        callback is Some(callback) &&
        !action.scope.is_disposed() {
        action.scope.run(callback)
      }
    }
  })
}

///|
/// Install the host's wakeup notifier on the UI thread. It must notify the event
/// loop without executing queued actions. Installing on a root with queued work
/// notifies immediately, so work posted before host attachment is not lost.
pub fn UiRoot::set_wakeup(self : UiRoot, wakeup : () -> Unit) -> Unit {
  guard !self.disposed else { return }
  self.wakeup_callback.val = Some(wakeup)
  if self.next_action_delay() is Some(_) {
    self.wakeup()
  }
}

///|
fn UiRoot::wakeup(self : UiRoot) -> Unit {
  if !self.disposed && self.wakeup_callback.val is Some(wakeup) {
    wakeup()
  }
}

///|
fn UiRoot::wakeup_frame(self : UiRoot) -> Unit {
  if @reactive.is_updating() {
    self.scope.run(fn() { @reactive.after_update(fn() { self.wakeup() }) })
  } else {
    self.wakeup()
  }
}
