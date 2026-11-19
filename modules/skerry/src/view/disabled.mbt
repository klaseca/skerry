///|
fn UiNode::is_disabled(self : UiNode) -> Bool {
  if self.geometry is Some({ overlay: Some(spec), .. }) &&
    (spec.trigger.is_disabled() || spec.trigger.lifecycle.phase is Disposed) {
    return true
  }
  match self.events.disabled {
    None => false
    Some(spec) =>
      match spec.constant_value() {
        Some(value) => value
        None => self.lifecycle.disabled
      }
  }
}

///|
fn UiNode::mount_disabled(
  self : UiNode,
  source : @reactive.Binding[Bool],
  host : MountContext,
) -> () -> Unit {
  let previous : Ref[Bool?] = Ref(None)
  let active = Ref(true)
  let stop = source.subscribe(fn(next) {
    guard active.val else { return }
    let changed = previous.val is Some(old) && old != next
    previous.val = Some(next)
    self.lifecycle.disabled = next
    if changed {
      @reactive.after_update(fn() {
        if active.val {
          (host.on_disabled_change)(self.id)
        }
      })
      (host.mark_paint_dirty)()
    }
  })
  fn() {
    guard active.val else { return }
    active.val = false
    stop()
  }
}
