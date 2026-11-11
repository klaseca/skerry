///|
const SCROLL_KEY_STEP : Double = 40.0

///|
fn scroll_key_offset(
  scroll : @diagnostics.ScrollSnapshot,
  key : @foundation.Key,
) -> Double? {
  match (key, scroll.axis) {
    (KeyArrowUp, Vertical) | (KeyArrowLeft, Horizontal) =>
      Some(scroll.offset - SCROLL_KEY_STEP)
    (KeyArrowDown, Vertical) | (KeyArrowRight, Horizontal) =>
      Some(scroll.offset + SCROLL_KEY_STEP)
    (KeyPageUp, _) =>
      Some(
        scroll.offset - scroll_axis_length(scroll.axis, scroll.viewport.size),
      )
    (KeyPageDown, _) =>
      Some(
        scroll.offset + scroll_axis_length(scroll.axis, scroll.viewport.size),
      )
    (KeyHome, _) => Some(0.0)
    (KeyEnd, _) => Some(scroll.max_offset)
    _ => None
  }
}

///|
/// Scroll an unhandled navigation key through the focused node's ancestors.
/// With no focus, only a root ScrollView is eligible. Modified keys are ignored.
pub fn LayoutState::scroll_key(
  self : LayoutState,
  view : View,
  node_id : Int32?,
  event : @foundation.KeyEvent,
  size~ : @foundation.Size,
) -> Bool {
  view.with_scope(fn() {
    guard !self.disposed && size.width > 0.0 && size.height > 0.0 else {
      return false
    }
    guard !event.modifiers.shift &&
      !event.modifiers.control &&
      !event.modifiers.alt &&
      !event.modifiers.meta else {
      return false
    }
    guard event.key
      is (KeyArrowUp
      | KeyArrowDown
      | KeyArrowLeft
      | KeyArrowRight
      | KeyPageUp
      | KeyPageDown
      | KeyHome
      | KeyEnd) else {
      return false
    }
    let geometry = self.input_geometry(view, size)
    guard !self.disposed else { return false }
    let id = node_id.unwrap_or(view.node.id)
    guard path_for_node_id(view.node, id, []) is Some(path) &&
      input_node_at_path(view.node, path, 0) is Some(_) &&
      geometry_at_path(geometry, path, 0) is Some({ id: projected_id, .. }) &&
      projected_id == id else {
      return false
    }
    for depth in path.length()>=..0 {
      let ancestor_path = path[:depth].to_owned()
      if node_at_path(view.node, ancestor_path, 0) is Some(node) &&
        node.is_popup() {
        break
      }
      if input_node_at_path(view.node, ancestor_path, 0) is Some(node) &&
        geometry_at_path(geometry, ancestor_path, 0) is Some(ancestor) &&
        node.id == ancestor.id &&
        ancestor.scroll is Some(scroll) &&
        scroll_key_offset(scroll, event.key) is Some(next) {
        let next = clamped_scroll_offset(next, scroll.max_offset)
        if next != scroll.offset {
          node.set_scroll_offset(scroll, next)
          return true
        }
      }
    }
    false
  })
}

///|
fn reveal_delta(
  start : Double,
  length : Double,
  viewport_start : Double,
  viewport_length : Double,
) -> Double {
  let end = start + length
  let viewport_end = viewport_start + viewport_length
  if start < viewport_start && end > viewport_end {
    0.0
  } else if start < viewport_start {
    if length > viewport_length {
      end - viewport_end
    } else {
      start - viewport_start
    }
  } else if end > viewport_end {
    if length > viewport_length {
      start - viewport_start
    } else {
      end - viewport_end
    }
  } else {
    0.0
  }
}

///|
// A nested viewport may currently lie outside an enclosing scroll viewport.
// Reveal inside it first; static clips between these viewports still constrain it.
fn reveal_viewport(
  view : View,
  geometry : NodeGeometry,
  path : Array[Int32],
  depth : Int32,
  size : @foundation.Size,
  viewport : @foundation.Rect,
) -> @foundation.Rect {
  let mut viewport = viewport
  for parent_depth in (depth - 1)>=..0 {
    let parent_path = path[:parent_depth].to_owned()
    if node_at_path(view.node, parent_path, 0) is Some(node) && node.is_popup() {
      break
    }
    if geometry_at_path(geometry, parent_path, 0) is Some(parent) {
      if parent.scroll is Some(_) {
        return viewport
      }
      if node_at_path(view.node, parent_path, 0)
        is Some({ geometry: Some({ clip_frame: true, .. }), .. }) {
        viewport = viewport.intersect(parent.frame)
      }
    }
  }
  viewport.intersect(@foundation.Rect::from_size(size))
}

///|
fn reveal_target(
  view : View,
  geometry : NodeGeometry,
  path : Array[Int32],
  depth : Int32,
) -> @foundation.Rect? {
  guard geometry_at_path(geometry, path, 0) is Some(target) else { return None }
  let mut rect = target.frame
  for child_depth in path.length()>=..(depth + 1) {
    let child_path = path[:child_depth].to_owned()
    if geometry_at_path(geometry, child_path, 0) is Some(child) {
      if child.scroll is Some(scroll) {
        rect = rect.intersect(scroll.viewport)
      }
      if node_at_path(view.node, child_path, 0)
        is Some({ geometry: Some({ clip_frame: true, .. }), .. }) {
        rect = rect.intersect(child.frame)
      }
    }
  }
  Some(rect)
}

///|
/// Reveal a live node with minimal scroll movement, from inner to outer viewport.
/// Oversized targets retain an already visible region instead of oscillating.
/// Recheck identity/geometry after scroll callbacks. is_current can cancel the
/// remaining ancestor updates if the host's focus/session changes.
pub fn LayoutState::reveal_node(
  self : LayoutState,
  view : View,
  node_id : Int32,
  size~ : @foundation.Size,
  is_current~ : () -> Bool = fn() { true },
) -> Bool {
  view.with_scope(fn() {
    guard !self.disposed &&
      is_current() &&
      size.width > 0.0 &&
      size.height > 0.0 else {
      return false
    }
    guard path_for_node_id(view.node, node_id, []) is Some(logical_path) &&
      input_node_at_path(view.node, logical_path, 0) is Some(_) else {
      return false
    }
    let mut has_viewport = false
    for depth in (logical_path.length() - 1)>=..0 {
      if node_at_path(view.node, logical_path[:depth].to_owned(), 0)
        is Some(node) &&
        node.is_popup() {
        break
      }
      if node_at_path(view.node, logical_path[:depth].to_owned(), 0)
        is Some({ geometry: Some({ scroll: Some(_), .. }), .. }) {
        has_viewport = true
        break
      }
    }
    guard has_viewport else { return false }
    let initial = self.input_geometry(view, size)
    guard !self.disposed && is_current() else { return false }
    guard path_for_node_id(view.node, node_id, []) is Some(initial_path) &&
      input_node_at_path(view.node, initial_path, 0) is Some(_) &&
      geometry_at_path(initial, initial_path, 0) is Some({ id, .. }) &&
      id == node_id else {
      return false
    }
    let ancestors : Array[Int32] = []
    for depth in (initial_path.length() - 1)>=..0 {
      if node_at_path(view.node, initial_path[:depth].to_owned(), 0)
        is Some(node) &&
        node.is_popup() {
        break
      }
      if geometry_at_path(initial, initial_path[:depth].to_owned(), 0)
        is Some({ id, scroll: Some(_), .. }) {
        ancestors.push(id)
      }
    }
    let mut changed = false
    for ancestor_id in ancestors {
      guard !self.disposed && is_current() else { break }
      let geometry = self.input_geometry(view, size)
      guard !self.disposed && is_current() else { break }
      guard path_for_node_id(view.node, node_id, []) is Some(path) &&
        input_node_at_path(view.node, path, 0) is Some(target) &&
        target.id == node_id &&
        geometry_at_path(geometry, path, 0) is Some({ id, .. }) &&
        id == node_id else {
        break
      }
      for depth in (path.length() - 1)>=..0 {
        let ancestor_path = path[:depth].to_owned()
        if input_node_at_path(view.node, ancestor_path, 0) is Some(node) &&
          node.id == ancestor_id &&
          geometry_at_path(geometry, ancestor_path, 0)
          is Some({ id, scroll: Some(scroll), .. }) &&
          id == ancestor_id &&
          reveal_target(view, geometry, path, depth) is Some(rect) {
          let viewport = reveal_viewport(
            view,
            geometry,
            path,
            depth,
            size,
            scroll.viewport,
          )
          if !rect.is_empty() && !viewport.is_empty() {
            let amount = reveal_delta(
              scroll_axis_position(scroll.axis, rect.origin),
              scroll_axis_length(scroll.axis, rect.size),
              scroll_axis_position(scroll.axis, viewport.origin),
              scroll_axis_length(scroll.axis, viewport.size),
            )
            let next = clamped_scroll_offset(
              scroll.offset + amount,
              scroll.max_offset,
            )
            if next != scroll.offset {
              node.set_scroll_offset(scroll, next)
              changed = true
            }
          }
          break
        }
      }
    }
    changed
  })
}
