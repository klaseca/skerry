///|
fn LayoutState::layout_overlays(
  self : LayoutState,
  node : UiNode,
  layout : @crater_core.Layout,
  parent_styles : StyleContext,
  viewport : @foundation.Size,
  anchor_width~ : Double = 0.0,
) -> @crater_core.Layout {
  let layout = if node.geometry is Some({ overlay: Some(spec), .. }) &&
    !node.children.val.is_empty() {
    let crater = node.crater_content(self.text_layout_system, parent_styles)
    let crater = spec.policy.layout(crater, viewport, anchor_width)
    let measurements = Map([])
    let crater = collect_measurements(crater, measurements)
    self.compute_measured_layout(crater, viewport, measurements)
  } else {
    layout
  }
  let styles = node.style_context(parent_styles)
  let children = layout.children.mapi(fn(index, child_layout) {
    match node.children.val.get(index) {
      Some(child) =>
        self.layout_overlays(
          child,
          child_layout,
          styles,
          viewport,
          anchor_width=layout.children
            .get(0)
            .map(first => first.width)
            .unwrap_or(layout.width),
        )
      None => child_layout
    }
  })
  { ..layout, children, }
}

///|
priv struct OverlayLayer {
  node : UiNode
  geometry : NodeGeometry
  path : Array[Int32]
}

///|
fn collect_overlay_layers(
  node : UiNode,
  geometry : NodeGeometry,
  path : Array[Int32],
  result : Array[OverlayLayer],
) -> Unit {
  if node.is_overlay() && !node.children.val.is_empty() && !geometry.disabled {
    result.push({ node, geometry, path: path.copy(), })
  }
  for index, child_geometry in geometry.children {
    if node.children.val.get(index) is Some(child) &&
      child.id == child_geometry.id {
      let next = path.copy()
      next.push(index)
      collect_overlay_layers(child, child_geometry, next, result)
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
  collect_overlay_layers(node, geometry, path, layers)
  let layers = ordered_overlay_layers(layers)
  for index in (layers.length() - 1)>=..0 {
    let layer = layers[index]
    match
      hit_test_node(layer.node, layer.geometry, point, layer.path, for_scroll~) {
      HitMiss =>
        if layer.node.geometry is Some({ overlay: Some(spec), .. }) &&
          spec.behavior().pointer == BlockOutside {
          return HitBlocked
        }
      hit => return hit
    }
  }
  hit_test_node(node, geometry, point, path, for_scroll~)
}

///|
/// A popup includes its anchor and visible content. A modal includes only the
/// surface content: its trigger and backdrop are outside. Uses shared paint/input
/// geometry so hosts can apply the layer's dismissal policy to outside presses.
pub fn LayoutState::overlay_contains(
  self : LayoutState,
  view : View,
  target : OverlayTarget,
  point : @foundation.Point,
  size~ : @foundation.Size,
) -> Bool {
  let geometry = self.input_geometry(view, size)
  if view.path_for_node_id(target.node_id) is Some(path) &&
    node_at_path(view.node, path, 0)
    is Some({ geometry: Some({ overlay: Some(spec), .. }), .. }) &&
    geometry_at_path(geometry, path, 0) is Some(layer) &&
    layer.id == target.node_id {
    let trigger = match view.path_for_node_id(spec.trigger.id) {
      Some(path) => geometry_at_path(geometry, path, 0)
      None => None
    }
    return spec.policy.contains(layer, trigger, point)
  }
  false
}

///|
fn overlay_geometry_contains(
  geometry : NodeGeometry,
  point : @foundation.Point,
) -> Bool {
  clip_contains(geometry.clip, point) &&
  (
    clip_contains(geometry.frame, point) ||
    geometry.children.any(child => overlay_geometry_contains(child, point))
  )
}
