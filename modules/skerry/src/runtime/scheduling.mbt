///|
// A shared process-lifetime origin keeps all default clocks monotonic.
let monotonic_milliseconds : () -> Double = {
  let origin = @bench.monotonic_clock_start()
  fn() { @bench.monotonic_clock_end(origin) / 1000.0 }
}

///|
priv struct UiTimer {
  deadline : Double
  action : UiAction
}

///|
fn UiAction::is_pending(self : UiAction) -> Bool {
  if self.scope.is_disposed() {
    self.callback = None
  }
  self.callback is Some(_)
}

///|
fn UiRoot::prune_actions(self : UiRoot) -> Unit {
  self.actions.retain(action => action.is_pending())
  self.timers.retain(timer => timer.action.is_pending())
  self.after_present_actions.retain(action => action.is_pending())
  // Compact once per pruning pass, releasing removed scopes and their tail
  // slots. When length already equals capacity this does not copy the array.
  self.actions.shrink_to_fit()
  self.timers.shrink_to_fit()
  self.after_present_actions.shrink_to_fit()
}

///|
/// Schedule a one-shot action using the root's monotonic millisecond clock.
/// Non-positive delays behave like post. Due timers join the next action batch
/// after queued posts, ordered by deadline and FIFO for equal deadlines.
/// Cancellation or root/posting-scope disposal prevents delivery.
pub fn UiRoot::post_delayed(
  self : UiRoot,
  delay_ms : Int32,
  callback : () -> Unit,
) -> () -> Unit {
  if delay_ms <= 0 {
    return self.post(callback)
  }
  let scope = @reactive.Scope::current().unwrap_or(self.scope)
  guard !self.disposed && !scope.is_disposed() else { return fn() { () } }
  self.prune_actions()
  let deadline = @reactive.untracked(self.clock) + delay_ms.to_double()
  let action : UiAction = { callback: Some(callback), scope, }
  let timer : UiTimer = { deadline, action, }
  let mut index = self.timers.length()
  for i, current in self.timers {
    if deadline < current.deadline {
      index = i
      break
    }
  }
  self.timers.insert(index, timer)
  if index == 0 {
    self.wakeup()
  }
  let wakeup = self.wakeup_callback
  fn() {
    if action.callback is Some(_) {
      action.callback = None
      if wakeup.val is Some(notify) {
        notify()
      }
    }
  }
}

///|
/// Milliseconds until the next action pass, rounded up. None means no queued
/// actions or live timers; zero means work is ready. Hosts recalculate before
/// waiting. The injected clock must return finite, nondecreasing milliseconds.
/// Querying also releases callbacks whose posting scope has been disposed.
pub fn UiRoot::next_action_delay(self : UiRoot) -> Int32? {
  guard !self.disposed else { return None }
  self.prune_actions()
  if !self.actions.is_empty() {
    return Some(0)
  }
  guard self.timers.get(0) is Some(timer) else { return None }
  let remaining = timer.deadline - @reactive.untracked(self.clock)
  Some(if remaining <= 0.0 { 0 } else { @double.ceil(remaining).to_int() })
}

///|
/// Request a frame and run once after the next successful present, including a
/// cached-frame present. Callbacks are batched in their posting scopes. Work
/// registered during present delivery waits for a later present. Cancellation
/// prevents delivery but does not undo the frame request.
pub fn UiRoot::after_present(
  self : UiRoot,
  callback : () -> Unit,
) -> () -> Unit {
  let scope = @reactive.Scope::current().unwrap_or(self.scope)
  guard !self.disposed && !scope.is_disposed() else { return fn() { () } }
  let action : UiAction = { callback: Some(callback), scope, }
  self.after_present_actions.push(action)
  // An in-progress paint will already be presented by the host. Registration
  // during its callbacks does not need another paint just to deliver this job.
  if !self.painting {
    self.mark_paint_dirty()
  }
  fn() { action.callback = None }
}
