///|
fn UiRoot::node_is_disabled(self : UiRoot, id : Int32?) -> Bool {
  match id {
    Some(id) =>
      match self.view.path_for_node_id(id) {
        Some(path) => !self.view.is_enabled_path(path)
        None => true
      }
    None => false
  }
}

///|
fn UiRoot::prune_disabled_interactions(self : UiRoot) -> Unit {
  self.scope.run(fn() {
    guard !self.disposed && !self.losing_focus else { return }
    defer self.request_overlay_sync()
    // Decide both before callbacks. A cancel handler can re-enable the subtree;
    // the interrupted interaction must still finish, including blur/key press.
    let cancel = self.node_is_disabled(self.captured_node_id)
    let blur = self.node_is_disabled(self.focused_node_id)
    let unhover = self.node_is_disabled(self.hovered_node_id)
    guard cancel || blur || unhover else { return }
    let fallback = if blur {
      match self.focused_node_id {
        Some(id) => self.view.focus_group_fallback(id)
        None => None
      }
    } else {
      None
    }
    if unhover {
      self.hovered_node_id = None
    }
    self.losing_focus = true
    defer (fn() { self.losing_focus = false })()
    // Invalidate before invoking observers or blur/cancel callbacks. They must
    // not observe the old painted state alongside already-cleared input IDs.
    self.mark_paint_dirty()
    if cancel {
      ignore(self.pointer_cancel())
    }
    if blur {
      self.clear_focus()
    }
    self.losing_focus = false
    if !self.disposed && self.focused_node_id is None && fallback is Some(id) {
      self.set_focus(id, reveal=true)
      self.reveal_focus()
    }
  })
}
