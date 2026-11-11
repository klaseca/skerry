///|
/// Deliver and apply synchronously. Handler writes reconcile before the default
/// action; lifecycle/frame notifications wait for the entire input operation.
/// Return whether the default action ran; cut uses this before returning text
/// for the clipboard.
/// Compound controls can supersede proposals from another node in the same mount.
pub fn[T] dispatch_change(
  id : Int32,
  value : T,
  on_change : ((@foundation.ChangeEvent[T]) -> Unit)?,
  apply : () -> Unit,
  is_current~ : () -> Bool = fn() { true },
) -> Bool {
  let can_apply = @environment.prepare_change(id)
  @reactive.during_update(fn() {
    let prevented = match on_change {
      Some(handler) => {
        let event = @foundation.ChangeEvent(value)
        handler(event)
        event.default_prevented()
      }
      None => false
    }
    let accepted = !prevented && can_apply() && is_current()
    if accepted {
      apply()
    }
    accepted
  })
}

///|
pub fn View::click_at(
  self : View,
  size~ : @foundation.Size,
  point~ : @foundation.Point,
  text_layout_system~ : @text.TextLayoutSystem,
) -> Bool {
  let state = LayoutState(text_layout_system~)
  state.click_at(self, size~, point~)
}

///|
pub(all) struct HitTarget {
  path : Array[Int32]
  node_id : Int32
  focusable : Bool
  on_click : (() -> Unit)?
  // The ScrollView's overlay consumes pointer input without activating content.
  scrollbar : Bool
}

///|
pub fn LayoutState::click_at(
  self : LayoutState,
  view : View,
  size~ : @foundation.Size,
  point~ : @foundation.Point,
) -> Bool {
  view.with_scope(fn() {
    match self.hit_test(view, size~, point~) {
      Some(target) => {
        if target.scrollbar {
          let handled = self.pointer_down_path(
            view,
            size~,
            target.path,
            point~,
            scrollbar=true,
          )
          ignore(
            self.pointer_up_path(
              view,
              size~,
              target.path,
              point~,
              scrollbar=true,
            ),
          )
          return handled
        }
        if target.on_click is Some(action) {
          action()
        }
        true
      }
      None => false
    }
  })
}

///|
pub fn LayoutState::hit_test(
  self : LayoutState,
  view : View,
  size~ : @foundation.Size,
  point~ : @foundation.Point,
) -> HitTarget? {
  view.with_scope(fn() {
    match hit_test_tree(view.node, self.input_geometry(view, size), point, []) {
      HitFound(target) => Some(target)
      HitMiss | HitBlocked => None
    }
  })
}

///|
pub fn View::focus_path(self : View, path : Array[Int32]) -> Bool {
  self.with_scope(fn() {
    match input_node_at_path(self.node, path, 0) {
      Some(node) => {
        guard node.events.focusable else { false }
        if node.events.on_focus is Some(action) {
          action()
        }
        node.events.focusable
      }
      None => false
    }
  })
}

///|
pub fn View::blur_path(self : View, path : Array[Int32]) -> Unit {
  self.with_scope(fn() {
    if node_at_path(self.node, path, 0) is Some(node) &&
      node.events.on_blur is Some(action) {
      action()
    }
  })
}

///|
pub fn View::key_down_path(
  self : View,
  path : Array[Int32],
  event : @foundation.KeyEvent,
) -> Bool {
  self.dispatch_key_down_path(path, event) != KeyIgnored
}

///|
/// Dispatch once and distinguish activation from editing/navigation. Activation
/// handlers already ran when KeyActivated is returned. KeyHandled means the event
/// was consumed; mounted view reactivity requests any necessary paint/layout.
pub fn View::dispatch_key_down_path(
  self : View,
  path : Array[Int32],
  event : @foundation.KeyEvent,
) -> KeyHandling {
  self.with_scope(fn() {
    match input_node_at_path(self.node, path, 0) {
      Some(node) => (node.events.on_key_down)(event)
      None => KeyIgnored
    }
  })
}

///|
pub fn View::text_input_path(
  self : View,
  path : Array[Int32],
  text : String,
) -> Bool {
  self.with_scope(fn() {
    match input_node_at_path(self.node, path, 0) {
      Some(node) => (node.events.on_text_input)(text)
      None => false
    }
  })
}

///|
pub fn View::text_edit_path(
  self : View,
  path : Array[Int32],
  command : @foundation.TextEditCommand,
) -> @foundation.TextEditResult {
  self.with_scope(fn() {
    match input_node_at_path(self.node, path, 0) {
      Some(node) => (node.events.on_text_edit)(command)
      None => TextEditIgnored
    }
  })
}

///|
/// Dispatch to the captured node. Custom hosts pass HitTarget.scrollbar for
/// every phase of a scrollbar press and clear interaction state with pointer_cancel.
pub fn LayoutState::pointer_down_path(
  self : LayoutState,
  view : View,
  size~ : @foundation.Size,
  path : Array[Int32],
  point~ : @foundation.Point,
  scrollbar~ : Bool = false,
) -> Bool {
  self.dispatch_pointer_event(
    view,
    size~,
    path,
    point~,
    PointerDown,
    scrollbar~,
  )
}

///|
pub fn LayoutState::pointer_move_path(
  self : LayoutState,
  view : View,
  size~ : @foundation.Size,
  path : Array[Int32],
  point~ : @foundation.Point,
  scrollbar~ : Bool = false,
) -> Bool {
  self.dispatch_pointer_event(
    view,
    size~,
    path,
    point~,
    PointerMove,
    scrollbar~,
  )
}

///|
pub fn LayoutState::pointer_up_path(
  self : LayoutState,
  view : View,
  size~ : @foundation.Size,
  path : Array[Int32],
  point~ : @foundation.Point,
  scrollbar~ : Bool = false,
) -> Bool {
  self.dispatch_pointer_event(view, size~, path, point~, PointerUp, scrollbar~)
}

///|
pub fn View::focusable_paths(self : View) -> Array[Array[Int32]] {
  self.with_scope(fn() {
    let paths : Array[Array[Int32]] = []
    collect_focusable_paths(self.node, [], paths)
    paths
  })
}

///|
pub fn View::pointer_cancel_path(self : View, path : Array[Int32]) -> Bool {
  self.with_scope(fn() {
    match node_at_path(self.node, path, 0) {
      Some(node) => {
        (node.events.on_pointer_cancel)()
        true
      }
      None => false
    }
  })
}

///|
pub fn View::node_id_at_path(self : View, path : Array[Int32]) -> Int32? {
  self.with_scope(fn() { node_at_path(self.node, path, 0).map(node => node.id) })
}

///|
/// Whether the path exists and every node on it allows input.
pub fn View::is_enabled_path(self : View, path : Array[Int32]) -> Bool {
  self.with_scope(fn() { input_node_at_path(self.node, path, 0) is Some(_) })
}

///|
pub fn View::path_for_node_id(self : View, node_id : Int32) -> Array[Int32]? {
  self.with_scope(fn() { path_for_node_id(self.node, node_id, []) })
}

///|
/// Tab stops differ from all focusable targets: a radio group contributes one
/// path. Retain a focused candidate when exiting, including a vetoed selection.
pub fn View::tab_focus_paths(
  self : View,
  focused_node_id? : Int32,
) -> Array[Array[Int32]] {
  self.with_scope(fn() {
    let paths : Array[Array[Int32]] = []
    collect_tab_focus_paths(self.node, [], focused_node_id, paths)
    paths
  })
}

///|
fn collect_tab_focus_paths(
  node : UiNode,
  path : Array[Int32],
  focused : Int32?,
  paths : Array[Array[Int32]],
) -> Unit {
  guard !node.is_disabled() else { return }
  if node.events.focus_entry is Some(preferred) {
    let members : Array[Array[Int32]] = []
    collect_focusable_paths(node, [], members)
    if members.is_empty() {
      return
    }
    let mut chosen = members[0]
    let selected = preferred()
    for candidate in members {
      let id = node_at_path(node, candidate, 0).unwrap().id
      if selected == Some(id) {
        chosen = candidate
      }
    }
    for candidate in members {
      if focused == Some(node_at_path(node, candidate, 0).unwrap().id) {
        chosen = candidate
        break
      }
    }
    let entry = path.copy()
    for index in chosen {
      entry.push(index)
    }
    paths.push(entry)
    return
  }
  if node.events.focusable {
    paths.push(path.copy())
  }
  for index, child in node.children.val {
    let child_path = path.copy()
    child_path.push(index)
    collect_tab_focus_paths(child, child_path, focused, paths)
  }
}

///|
fn enclosing_focus_group(
  root : UiNode,
  path : Array[Int32],
) -> (UiNode, Array[Int32])? {
  for depth in path.length()>=..0 {
    let parent = path[:depth].to_owned()
    if input_node_at_path(root, parent, 0) is Some(node) &&
      node.events.focus_entry is Some(_) {
      return Some((node, parent))
    }
  }
  None
}

///|
/// Return a keyboard activation target for the nearest enabled focus group.
/// Hosts focus it first, revalidate it, then invoke its action and reveal focus.
pub fn View::focus_group_key_target(
  self : View,
  path : Array[Int32],
  event : @foundation.KeyEvent,
) -> HitTarget? {
  self.with_scope(fn() {
    guard !event.modifiers.shift &&
      !event.modifiers.control &&
      !event.modifiers.alt &&
      !event.modifiers.meta else {
      return None
    }
    let forward = match event.key {
      KeyArrowDown | KeyArrowRight => true
      KeyArrowUp | KeyArrowLeft => false
      _ => return None
    }
    guard input_node_at_path(self.node, path, 0) is Some(current) else {
      return None
    }
    guard enclosing_focus_group(self.node, path) is Some((group, parent)) else {
      return None
    }
    let members : Array[Array[Int32]] = []
    collect_focusable_paths(group, parent, members)
    for index, candidate in members {
      if node_at_path(self.node, candidate, 0).unwrap().id == current.id {
        let next = if forward {
          if index + 1 < members.length() {
            index + 1
          } else {
            0
          }
        } else if index > 0 {
          index - 1
        } else {
          members.length() - 1
        }
        let target = members[next]
        let node = node_at_path(self.node, target, 0).unwrap()
        return Some({
          path: target,
          node_id: node.id,
          focusable: true,
          on_click: node.events.on_click,
          scrollbar: false,
        })
      }
    }
    None
  })
}

///|
/// Recover focus within an enabled group after a candidate becomes unavailable.
/// Availability never changes the selected model or emits a change proposal.
pub fn View::focus_group_fallback(self : View, node_id : Int32) -> Int32? {
  self.with_scope(fn() {
    guard self.path_for_node_id(node_id) is Some(path) else { return None }
    guard enclosing_focus_group(self.node, path) is Some((group, parent)) else {
      return None
    }
    let members : Array[Array[Int32]] = []
    collect_focusable_paths(group, parent, members)
    for candidate in members {
      if focus_path_follows(candidate, path) {
        return self.node_id_at_path(candidate)
      }
    }
    match members.get(0) {
      Some(candidate) => self.node_id_at_path(candidate)
      None => None
    }
  })
}

///|
fn focus_path_follows(left : Array[Int32], right : Array[Int32]) -> Bool {
  for index in 0..<left.length().min(right.length()) {
    if left[index] != right[index] {
      return left[index] > right[index]
    }
  }
  left.length() > right.length()
}

///|
priv enum PointerPhase {
  PointerDown
  PointerMove
  PointerUp
}

///|
fn LayoutState::dispatch_pointer_event(
  self : LayoutState,
  view : View,
  size~ : @foundation.Size,
  path : Array[Int32],
  point~ : @foundation.Point,
  phase : PointerPhase,
  scrollbar~ : Bool = false,
) -> Bool {
  view.with_scope(fn() {
    guard !self.disposed else { return false }
    let geometry = self.input_geometry(view, size)
    guard !self.disposed else { return false }
    match
      (
        input_node_at_path(view.node, path, 0),
        geometry_at_path(geometry, path, 0),
      ) {
      (Some(node), Some(geometry)) if node.id == geometry.id => {
        if self.scrollbar_pointer(node, geometry, point, phase, scrollbar) {
          return true
        }
        // A vanished scrollbar must not turn its initial press into a content event.
        if scrollbar {
          return false
        }
        // The host selects a visible target before starting capture. Focus/blur
        // callbacks may move it; captured events still follow that node identity.
        let event : PointerContext = {
          align: geometry.styles
          .iter()
          .fold(init=TextStart, fn(align, declaration) {
            declaration.layout.text.align.unwrap_or(align)
          }),
          position: Point(
            x=point.x - geometry.frame.origin.x,
            y=point.y - geometry.frame.origin.y,
          ),
          text_layout_system: self.text_layout_system,
          font: geometry.font,
          size: geometry.frame.size,
          padding: geometry.padding,
        }
        match phase {
          PointerDown => (node.events.on_pointer_down)(event)
          PointerMove => (node.events.on_pointer_move)(event)
          PointerUp => (node.events.on_pointer_up)(event)
        }
        true
      }
      _ => false
    }
  })
}

///|
priv enum HitTestResult {
  HitMiss
  HitBlocked
  HitFound(HitTarget)
}

///|
fn hit_test_node(
  node : UiNode,
  geometry : NodeGeometry,
  point : @foundation.Point,
  path : Array[Int32],
  for_scroll~ : Bool = false,
) -> HitTestResult {
  if !clip_contains(geometry.clip, point) {
    HitMiss
  } else {
    let disabled = geometry.disabled
    // The overlay is painted after children, so it wins over content targets.
    if geometry.scroll is Some({ scrollbar: Some(bar), .. }) &&
      clip_contains(bar.track, point) {
      return if disabled {
        HitBlocked
      } else {
        HitFound({
          path,
          node_id: node.id,
          focusable: false,
          on_click: None,
          scrollbar: true,
        })
      }
    }
    let mut result = HitMiss
    for index, child_geometry in geometry.children {
      if node.children.val.get(index) is Some(child) &&
        child.id == child_geometry.id {
        if child.is_popup() {
          continue
        }
        let child_path = path.copy()
        child_path.push(index)
        match
          hit_test_node(child, child_geometry, point, child_path, for_scroll~) {
          HitMiss => ()
          hit => result = hit
        }
      }
    }
    match result {
      HitFound(_) | HitBlocked => result
      HitMiss =>
        if !clip_contains(geometry.frame, point) {
          HitMiss
        } else if disabled {
          HitBlocked
        } else if node.events.focusable ||
          node.events.hit_testable ||
          node.events.on_click is Some(_) ||
          (
            for_scroll &&
            geometry.scroll is Some(scroll) &&
            clip_contains(scroll.viewport, point)
          ) {
          HitFound({
            path,
            node_id: node.id,
            focusable: node.events.focusable,
            on_click: node.events.on_click,
            scrollbar: false,
          })
        } else {
          HitMiss
        }
    }
  }
}

///|
fn node_at_path(node : UiNode, path : Array[Int32], depth : Int32) -> UiNode? {
  if depth == path.length() {
    Some(node)
  } else {
    let index = path[depth]
    if index < 0 || index >= node.children.val.length() {
      None
    } else {
      node_at_path(node.children.val[index], path, depth + 1)
    }
  }
}

///|
fn input_node_at_path(
  node : UiNode,
  path : Array[Int32],
  depth : Int32,
) -> UiNode? {
  guard !node.is_disabled() else { None }
  if depth == path.length() {
    Some(node)
  } else {
    match node.children.val.get(path[depth]) {
      Some(child) => input_node_at_path(child, path, depth + 1)
      None => None
    }
  }
}

///|
fn path_for_node_id(
  node : UiNode,
  node_id : Int32,
  path : Array[Int32],
) -> Array[Int32]? {
  if node.id == node_id {
    Some(path.copy())
  } else {
    for index, child in node.children.val {
      let child_path = path.copy()
      child_path.push(index)
      if path_for_node_id(child, node_id, child_path) is Some(found) {
        break Some(found)
      }
    } nobreak {
      None
    }
  }
}

///|
fn collect_focusable_paths(
  node : UiNode,
  path : Array[Int32],
  paths : Array[Array[Int32]],
) -> Unit {
  guard !node.is_disabled() else { return }
  if node.events.focusable {
    paths.push(path.copy())
  }
  for index, child in node.children.val {
    let child_path = path.copy()
    child_path.push(index)
    collect_focusable_paths(child, child_path, paths)
  }
}
