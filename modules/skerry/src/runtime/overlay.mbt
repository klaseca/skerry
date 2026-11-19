///|
priv struct OverlaySession {
  target : @view.OverlayTarget
  mut restore : Int32?
}

///|
// Keyboard routing follows focus containment independently of pointer barriers
// and paint order. Layers outside the active focus scope cannot take its focus.
fn overlay_focus_scope(
  targets : Array[@view.OverlayTarget],
) -> Array[@view.OverlayTarget] {
  for index in (targets.length() - 1)>=..0 {
    let boundary = targets[index]
    if boundary.behavior.focus == Contain {
      return targets.filter(target => boundary.contains_path(target.path))
    }
  }
  targets
}

///|
fn UiRoot::request_overlay_sync(self : UiRoot) -> Unit {
  guard !self.disposed else { return }
  if self.syncing_overlays {
    self.overlays_pending = true
  } else if @reactive.is_updating() {
    if !self.overlays_pending {
      self.overlays_pending = true
      self.scope.run(fn() {
        @reactive.after_update(fn() {
          self.overlays_pending = false
          self.sync_overlays()
        })
      })
    }
  } else {
    self.sync_overlays()
  }
}

///|
fn UiRoot::sync_overlays(self : UiRoot) -> Unit {
  guard !self.disposed else { return }
  if self.syncing_overlays {
    self.overlays_pending = true
    return
  }
  self.syncing_overlays = true
  self.overlays_pending = false
  let previous = self.overlay_sessions
  let targets = self.view.overlay_targets()
  let focus_owner = overlay_focus_scope(targets)
    .filter(target => target.behavior.takes_focus())
    .last()
  let next = targets.map(target => {
    for session in previous {
      if session.target.node_id == target.node_id {
        break { ..session, target, }
      }
    } nobreak {
      { target, restore: None, }
    }
  })
  self.overlay_sessions = next
  if self.captured_node_id is Some(id) &&
    self.view.path_for_node_id(id) is Some(path) &&
    !self.view.pointer_allows_path(path) {
    ignore(self.pointer_cancel())
  }
  guard !self.disposed else {
    self.syncing_overlays = false
    return
  }
  // Detach clears focus before the subtree disappears. Restore only when no
  // application callback has already selected another live target.
  for index in (previous.length() - 1)>=..0 {
    let old = previous[index]
    if !targets.any(target => target.node_id == old.target.node_id) &&
      old.target.behavior.takes_focus() &&
      self.focused_node_id is None &&
      old.restore is Some(id) {
      match focus_owner {
        Some(owner) => {
          let paths = self.view.overlay_tab_paths(owner, focused_node_id=id)
          if paths.any(path => self.view.node_id_at_path(path) == Some(id)) {
            self.set_focus(id)
          } else if paths.get(0) is Some(path) &&
            self.view.node_id_at_path(path) is Some(id) {
            self.set_focus(id)
          }
        }
        None => self.set_focus(id)
      }
    }
  }
  for session in next {
    guard !self.disposed else { break }
    if !previous.any(old => old.target.node_id == session.target.node_id) &&
      session.target.behavior.takes_focus() {
      let takes_focus = focus_owner.map(owner => owner.node_id) ==
        Some(session.target.node_id)
      session.restore = Some(
        if takes_focus ||
          !previous.any(old => old.target.behavior.takes_focus()) {
          self.focused_node_id.unwrap_or(session.target.trigger_id)
        } else {
          session.target.trigger_id
        },
      )
      if takes_focus {
        ignore(self.pointer_cancel())
      }
      if takes_focus &&
        self.view.overlay_tab_paths(session.target).get(0) is Some(path) &&
        self.view.node_id_at_path(path) is Some(id) {
        self.set_focus(id, reveal=true)
      } else if takes_focus && session.target.behavior.focus == Contain {
        self.clear_focus()
      }
    }
  }
  self.syncing_overlays = false
  if self.overlays_pending {
    self.overlays_pending = false
    self.sync_overlays()
  }
}

///|
fn UiRoot::overlay_tab_paths(self : UiRoot) -> Array[Array[Int32]] {
  let targets = overlay_focus_scope(self.view.overlay_targets())
  for index in (targets.length() - 1)>=..0 {
    if targets[index].behavior.takes_focus() {
      return self.view.overlay_tab_paths(
        targets[index],
        focused_node_id?=self.focused_node_id,
      )
    }
  }
  self.view.tab_focus_paths(focused_node_id?=self.focused_node_id)
}

///|
fn UiRoot::dismiss_top_overlay(self : UiRoot) -> Bool {
  let targets = overlay_focus_scope(self.view.overlay_targets())
  for index in (targets.length() - 1)>=..0 {
    let target = targets[index]
    match target.behavior.escape {
      Dismiss => {
        (target.dismiss)()
        return true
      }
      Consume => return true
      Ignore => ()
    }
  }
  // An unhandled Escape must not reach the background of a containing scope.
  targets.any(target => target.behavior.focus == Contain)
}

///|
fn same_overlay_order(
  left : Array[@view.OverlayTarget],
  right : Array[@view.OverlayTarget],
) -> Bool {
  guard left.length() == right.length() else { return false }
  for index, target in left {
    if target.node_id != right[index].node_id {
      return false
    }
  }
  true
}

///|
fn UiRoot::dismiss_outside_overlay(
  self : UiRoot,
  size : @foundation.Size,
  point : @foundation.Point,
) -> Bool {
  self.sync_overlays()
  guard !self.disposed else { return true }
  let targets = self.view.overlay_targets()
  for index in (targets.length() - 1)>=..0 {
    let target = targets[index]
    let inside = self.layout_state.overlay_contains(
      self.view,
      target,
      point,
      size~,
    )
    // A custom measurement can change ownership while computing geometry.
    guard !self.disposed &&
      same_overlay_order(targets, self.view.overlay_targets()) else {
      return true
    }
    if inside {
      return false
    }
    match target.behavior.outside_press {
      Dismiss => {
        (target.dismiss)()
        return true
      }
      Consume => return true
      Ignore => if target.behavior.pointer == BlockOutside { return true }
    }
  }
  false
}
