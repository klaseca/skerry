///|
/// Read the last painted layout and current logical hierarchy without computing
/// layout or calling application code. None means the cache was invalidated or
/// a different projection was computed since paint, including by hit testing.
/// Pass the same View used by paint and invalidate on structural changes.
/// UiRoot::snapshot also checks pending frame work and supplies root identity
/// and frame statistics.
pub fn LayoutState::snapshot(
  self : LayoutState,
  view : View,
) -> @diagnostics.TreeSnapshot? {
  view.with_scope(fn() {
    guard self.painted else { return None }
    guard self.painted_geometry is Some(geometry) && self.size is Some(size) else {
      return None
    }
    let nodes : Array[@diagnostics.NodeSnapshot] = []
    let themes : Array[(@style.Theme, @style.Theme)] = []
    snapshot_node(
      view.node,
      geometry,
      None,
      self.painted_focus.map(path => path[:]),
      self.painted_hover,
      self.painted_pointer_press,
      self.painted_key_press,
      nodes,
      themes,
    )
    Some({ size, nodes: ReadOnlyArray::from_array(nodes[:]), })
  })
}

///|
fn snapshot_node(
  node : UiNode,
  geometry : NodeGeometry,
  parent_id : Int32?,
  focus : ArrayView[Int32]?,
  hovered : Int32?,
  pointer_pressed : Int32?,
  key_pressed : Int32?,
  nodes : Array[@diagnostics.NodeSnapshot],
  themes : Array[(@style.Theme, @style.Theme)],
) -> Unit {
  let frame = geometry.frame
  let padding = geometry.padding
  let border = geometry.border
  let disabled = geometry.disabled
  let state = node_control_state(
    node.id,
    disabled,
    focus is Some([]),
    hovered,
    pointer_pressed,
    key_pressed,
  )
  let (debug_name, source, key_label) = match node.metadata {
    Some(metadata) => (metadata.name, metadata.source, metadata.key_label)
    None => (None, None, None)
  }
  nodes.push({
    id: node.id,
    parent_id,
    children: ReadOnlyArray::from_iter(
      node.children.val.iter().map(child => child.id),
    ),
    component_name: node.component_name,
    components: snapshot_components(node.metadata),
    style_type: node.specified_style.map(value => value.name),
    debug_name,
    source,
    key_label,
    specified_style: match node.specified_style {
      Some(style) => style.snapshot(geometry.styles)
      None => None
    },
    style_layers: geometry.styles,
    computed_style: node.snapshot_style(geometry, state),
    theme: snapshot_theme(geometry.theme, themes),
    frame,
    content: geometry.content,
    clip: geometry.clip,
    scroll: geometry.scroll,
    overlay: match node.geometry {
      Some({ overlay: Some(spec), .. }) =>
        Some({ trigger_id: spec.trigger.id, behavior: spec.behavior(), })
      _ => None
    },
    image: geometry.image,
    padding,
    border,
    disabled,
    state,
    focusable: node.events.focusable,
    hit_testable: node.events.hit_testable ||
    geometry.scroll is Some({ scrollbar: Some(_), .. }),
  })
  for index, child_geometry in geometry.children {
    if node.children.val.get(index) is Some(child) &&
      child.id == child_geometry.id {
      snapshot_node(
        child,
        child_geometry,
        Some(node.id),
        match focus {
          Some([head, .. tail]) if head == index => Some(tail)
          _ => None
        },
        hovered,
        pointer_pressed,
        key_pressed,
        nodes,
        themes,
      )
    }
  }
}

///|
fn snapshot_components(
  metadata : DebugMetadata?,
) -> ReadOnlyArray[@diagnostics.ComponentSnapshot] {
  let components : Array[@diagnostics.ComponentSnapshot] = []
  let mut current = match metadata {
    Some(metadata) => metadata.components
    None => None
  }
  while current is Some(component) {
    components.push({
      id: component.id,
      name: component.name,
      debug_name: component.debug_name,
      source: component.source,
    })
    current = component.inner
  }
  ReadOnlyArray::from_array(components[:])
}

///|
fn snapshot_theme(
  theme : @style.Theme,
  themes : Array[(@style.Theme, @style.Theme)],
) -> @style.Theme {
  for (original, snapshot) in themes {
    if physical_equal(original, theme) {
      return snapshot
    }
  }
  let snapshot = theme.snapshot()
  themes.push((theme, snapshot))
  snapshot
}
