///|
fn popup_origin(
  spec : PopupSpec,
  anchor : @foundation.Rect,
  size : @foundation.Size,
  viewport : @foundation.Rect,
) -> @foundation.Point {
  let right = anchor.origin.x + anchor.size.width
  let bottom = anchor.origin.y + anchor.size.height
  let end_x = viewport.origin.x + viewport.size.width
  let end_y = viewport.origin.y + viewport.size.height
  let below = bottom + spec.gap
  let above = anchor.origin.y - spec.gap - size.height
  let after = right + spec.gap
  let before = anchor.origin.x - spec.gap - size.width
  let (x, y) = match spec.placement {
    BottomStart | BottomEnd => {
      let y = if below + size.height > end_y &&
        anchor.origin.y - viewport.origin.y > end_y - bottom {
        above
      } else {
        below
      }
      (
        if spec.placement == BottomEnd {
          right - size.width
        } else {
          anchor.origin.x
        },
        y,
      )
    }
    TopStart | TopEnd => {
      let y = if above < viewport.origin.y &&
        end_y - bottom > anchor.origin.y - viewport.origin.y {
        below
      } else {
        above
      }
      (
        if spec.placement == TopEnd {
          right - size.width
        } else {
          anchor.origin.x
        },
        y,
      )
    }
    LeftStart =>
      (
        if before < viewport.origin.x &&
          end_x - right > anchor.origin.x - viewport.origin.x {
          after
        } else {
          before
        },
        anchor.origin.y,
      )
    RightStart =>
      (
        if after + size.width > end_x &&
          anchor.origin.x - viewport.origin.x > end_x - right {
          before
        } else {
          after
        },
        anchor.origin.y,
      )
  }
  Point(
    x=x.max(viewport.origin.x).min((end_x - size.width).max(viewport.origin.x)),
    y=y.max(viewport.origin.y).min((end_y - size.height).max(viewport.origin.y)),
  )
}

///|
fn LayoutState::layout_popups(
  self : LayoutState,
  node : UiNode,
  layout : @crater_core.Layout,
  parent_styles : StyleContext,
  viewport : @foundation.Size,
) -> @crater_core.Layout {
  let layout = if node.is_popup() && !node.children.val.is_empty() {
    let crater = node.crater_content(self.text_layout_system, parent_styles)
    let crater = with_node_style(crater, {
      ..crater.style,
      width: FitContent(viewport.width.max(0.0)),
      max_width: Length(viewport.width.max(0.0)),
      max_height: Length(viewport.height.max(0.0)),
    })
    let measurements = Map([])
    let crater = collect_measurements(crater, measurements)
    self.compute_measured_layout(crater, viewport, measurements)
  } else {
    layout
  }
  let styles = node.style_context(parent_styles)
  let children = layout.children.mapi(fn(index, child_layout) {
    match node.children.val.get(index) {
      Some(child) => self.layout_popups(child, child_layout, styles, viewport)
      None => child_layout
    }
  })
  { ..layout, children, }
}

///|
priv struct PopupLayer {
  node : UiNode
  geometry : NodeGeometry
  path : Array[Int32]
}

///|
fn collect_popup_layers(
  node : UiNode,
  geometry : NodeGeometry,
  path : Array[Int32],
  result : Array[PopupLayer],
) -> Unit {
  if node.is_popup() && !node.children.val.is_empty() && !geometry.disabled {
    result.push({ node, geometry, path: path.copy(), })
  }
  for index, child_geometry in geometry.children {
    if node.children.val.get(index) is Some(child) &&
      child.id == child_geometry.id {
      let next = path.copy()
      next.push(index)
      collect_popup_layers(child, child_geometry, next, result)
    }
  }
}

///|
fn hit_test_tree(
  node : UiNode,
  geometry : NodeGeometry,
  point : @foundation.Point,
  path : Array[Int32],
  for_scroll~ : Bool = false,
) -> HitTestResult {
  let layers = []
  collect_popup_layers(node, geometry, path, layers)
  for index in (layers.length() - 1)>=..0 {
    let layer = layers[index]
    match
      hit_test_node(layer.node, layer.geometry, point, layer.path, for_scroll~) {
      HitMiss => ()
      hit => return hit
    }
  }
  hit_test_node(node, geometry, point, path, for_scroll~)
}

///|
/// Whether a press is inside an open popup or its anchor, using current shared
/// paint/input geometry. Custom hosts use this before invoking dismiss.
pub fn LayoutState::popup_contains(
  self : LayoutState,
  view : View,
  target : PopupTarget,
  point : @foundation.Point,
  size~ : @foundation.Size,
) -> Bool {
  let geometry = self.input_geometry(view, size)
  for id in [target.node_id, target.anchor_id] {
    if view.path_for_node_id(id) is Some(path) &&
      geometry_at_path(geometry, path, 0) is Some(node) {
      if id == target.node_id {
        if popup_geometry_contains(node, point) {
          return true
        }
      } else if clip_contains(node.clip.intersect(node.frame), point) {
        return true
      }
    }
  }
  false
}

///|
fn popup_geometry_contains(
  geometry : NodeGeometry,
  point : @foundation.Point,
) -> Bool {
  clip_contains(geometry.clip, point) &&
  (
    clip_contains(geometry.frame, point) ||
    geometry.children.any(child => popup_geometry_contains(child, point))
  )
}
