///|
priv struct PopupSession {
  target : @view.PopupTarget
  mut restore : Int32?
}

///|
fn UiRoot::request_popup_sync(self : UiRoot) -> Unit {
  guard !self.disposed else { return }
  if self.syncing_popups {
    self.popups_pending = true
  } else if @reactive.is_updating() {
    if !self.popups_pending {
      self.popups_pending = true
      self.scope.run(fn() {
        @reactive.after_update(fn() {
          self.popups_pending = false
          self.sync_popups()
        })
      })
    }
  } else {
    self.sync_popups()
  }
}

///|
fn UiRoot::sync_popups(self : UiRoot) -> Unit {
  guard !self.disposed else { return }
  if self.syncing_popups {
    self.popups_pending = true
    return
  }
  self.syncing_popups = true
  self.popups_pending = false
  let previous = self.popup_sessions
  let targets = self.view.popup_targets()
  let focus_owner = targets.filter(target => target.focus).last()
  let next = targets.map(target => {
    for session in previous {
      if session.target.node_id == target.node_id {
        break { ..session, target, }
      }
    } nobreak {
      { target, restore: None, }
    }
  })
  self.popup_sessions = next
  // Detach clears focus before the subtree disappears. Restore only when no
  // application callback has already selected another live target.
  for index in (previous.length() - 1)>=..0 {
    let old = previous[index]
    if !targets.any(target => target.node_id == old.target.node_id) &&
      old.target.focus &&
      self.focused_node_id is None &&
      old.restore is Some(id) {
      match focus_owner {
        Some(owner) => {
          let paths = self.view.popup_tab_paths(owner, focused_node_id=id)
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
      session.target.focus {
      let takes_focus = focus_owner.map(owner => owner.node_id) ==
        Some(session.target.node_id)
      session.restore = Some(
        if takes_focus || !previous.any(old => old.target.focus) {
          self.focused_node_id.unwrap_or(session.target.anchor_id)
        } else {
          session.target.anchor_id
        },
      )
      if takes_focus {
        ignore(self.pointer_cancel())
      }
      if takes_focus &&
        self.view.popup_tab_paths(session.target).get(0) is Some(path) &&
        self.view.node_id_at_path(path) is Some(id) {
        self.set_focus(id, reveal=true)
      }
    }
  }
  self.syncing_popups = false
  if self.popups_pending {
    self.popups_pending = false
    self.sync_popups()
  }
}

///|
fn UiRoot::popup_tab_paths(self : UiRoot) -> Array[Array[Int32]] {
  let targets = self.view.popup_targets()
  for index in (targets.length() - 1)>=..0 {
    if targets[index].focus {
      return self.view.popup_tab_paths(
        targets[index],
        focused_node_id?=self.focused_node_id,
      )
    }
  }
  self.view.tab_focus_paths(focused_node_id?=self.focused_node_id)
}

///|
fn UiRoot::dismiss_top_popup(self : UiRoot) -> Bool {
  let targets = self.view.popup_targets()
  guard !targets.is_empty() else { return false }
  (targets[targets.length() - 1].dismiss)()
  true
}

///|
fn UiRoot::dismiss_outside_popup(
  self : UiRoot,
  size : @foundation.Size,
  point : @foundation.Point,
) -> Bool {
  self.sync_popups()
  guard !self.disposed else { return true }
  let targets = self.view.popup_targets()
  guard !targets.is_empty() else { return false }
  let top = targets[targets.length() - 1]
  let inside = self.layout_state.popup_contains(self.view, top, point, size~)
  // A custom measurement can change ownership while computing geometry.
  guard !self.disposed &&
    self.view.popup_targets().last().map(target => target.node_id) ==
    Some(top.node_id) else {
    return true
  }
  if inside {
    false
  } else {
    (top.dismiss)()
    true
  }
}
