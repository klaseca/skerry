///|
/// Scroll at logical root coordinates. Positive logical deltas increase the content
/// offset on the selected axis. Geometry/clip targeting is shared with pointer
/// input; consumed events request paint while keeping layout/text caches.
pub fn UiRoot::scroll_at(
  self : UiRoot,
  size~ : @foundation.Size,
  point~ : @foundation.Point,
  delta~ : @foundation.Point,
) -> Bool {
  self.scope.run(fn() {
    guard !self.disposed && !self.losing_focus else { return false }
    self.viewport_size = Some(size)
    let handled = self.layout_state.scroll_at(self.view, size~, point~, delta~)
    if handled && !self.disposed {
      self.pointer_position = Some(point)
      self.mark_paint_dirty()
    }
    handled
  })
}

///|
fn UiRoot::reveal_focus(self : UiRoot) -> Unit {
  guard !self.disposed && !self.losing_focus && !self.revealing_focus else {
    return
  }
  guard self.pending_focus_reveal is Some(node_id) else { return }
  if self.focused_node_id != Some(node_id) {
    self.pending_focus_reveal = None
    return
  }
  guard self.viewport_size is Some(size) &&
    size.width > 0.0 &&
    size.height > 0.0 else {
    return
  }
  self.pending_focus_reveal = None
  self.revealing_focus = true
  defer (fn() { self.revealing_focus = false })()
  if self.layout_state.reveal_node(self.view, node_id, size~, is_current=fn() {
      !self.disposed &&
      !self.losing_focus &&
      self.focused_node_id == Some(node_id) &&
      self.viewport_size == Some(size)
    }) {
    self.mark_paint_dirty()
  }
  if !self.disposed &&
    self.focused_node_id == Some(node_id) &&
    self.viewport_size != Some(size) {
    self.pending_focus_reveal = Some(node_id)
    self.mark_paint_dirty()
  }
}
