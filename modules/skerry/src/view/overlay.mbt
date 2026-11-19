///|
priv struct OverlayState {
  id : Int32
  open : @reactive.Signal[Bool]
  on_change : ((@foundation.ChangeEvent[Bool]) -> Unit)?
}

///|
fn OverlayState::change(self : OverlayState, next : Bool) -> Unit {
  let before = self.open.peek()
  guard before != next else { return }
  ignore(
    dispatch_change(
      self.id,
      next,
      self.on_change,
      fn() { self.open.set(next) },
      is_current=fn() { self.open.peek() == before },
    ),
  )
}

///|
// Implementations read only their configuration and supplied layout/geometry.
// They never evaluate application producers or retain a frame's projection.
priv trait OverlayPolicy {
  fn layout(Self, @crater_node.Node, @foundation.Size, Double) -> @crater_node.Node
  fn origin(Self, @foundation.Rect, @foundation.Size, @foundation.Rect) -> @foundation.Point
  fn contains(Self, NodeGeometry, NodeGeometry?, @foundation.Point) -> Bool
  fn behavior(Self) -> @foundation.OverlayBehavior
}

///|
priv struct OverlaySpec {
  policy : &OverlayPolicy
  trigger : UiNode
  dismiss : () -> Unit
}

///|
fn OverlaySpec::behavior(self : OverlaySpec) -> @foundation.OverlayBehavior {
  self.policy.behavior()
}

///|
// Shared visibility and ownership only; each concrete layer builds its own
// surface and supplies its own layout/paint policy.
fn overlay_session(
  anchor : View,
  open : @reactive.Signal[Bool]?,
  trigger : PopupTrigger,
  on_change : ((@foundation.ChangeEvent[Bool]) -> Unit)?,
  content : (() -> Unit) -> View,
) -> (View, View, OverlayState) {
  let state : OverlayState = {
    id: next_ui_node_id(),
    open: open.unwrap_or_else(fn() { @reactive.signal(false) }),
    on_change: on_change.map(scoped_handler),
  }
  let surface = show_view(
    fn() { state.open.get() },
    fn() {
      let scope = @reactive.Scope::current().unwrap()
      content(fn() {
        if !scope.is_disposed() {
          scope.run(fn() { state.change(false) })
        }
      })
    },
    id=state.id,
  )
  let anchor = match trigger {
    Manual => anchor
    Click => overlay_click_anchor(anchor, state)
  }
  (anchor, surface, state)
}

///|
fn overlay_view(
  anchor : View,
  surface : View,
  spec : OverlaySpec,
  component_name : String,
) -> View {
  let surface = view_from_node({
    ..surface.node,
    geometry: Some({
      translation: Point(x=0.0, y=0.0),
      clip_frame: false,
      scroll: None,
      theme: None,
      overlay: Some(spec),
    }),
    events: ElementEvents(editable=true, hit_testable=true),
  })
  let nodes = [anchor.node, surface.node]
  view_from_node({
    id: next_ui_node_id(),
    lifecycle: NodeLifecycle(),
    component_name,
    styles: None,
    metadata: None,
    geometry: None,
    specified_style: None,
    make_crater: fn(system, styles) {
      @crater_node.Node::new(
        "overlay-anchor",
        flex_style(flex_spec(Vertical, FlexStyle())),
        nodes.map(node => node.crater(system, styles)),
      )
    },
    painter: Painter(fn(_, _) { () }),
    events: ElementEvents(),
    reactivity: empty_reactivity(),
    children: Ref(nodes),
  })
}

///|
fn UiNode::is_overlay(self : UiNode) -> Bool {
  self.geometry is Some({ overlay: Some(_), .. })
}

///|
/// Host protocol for live floating layers, in paint order. The top pointer
/// barrier and its descendants follow background layers. Behavior carries the
/// input policy; trigger_id is the fallback target for focus restoration.
/// Paths and callbacks belong to the attached tree; do not retain them after
/// detach. Reading this does not evaluate application producers or run layout.
pub struct OverlayTarget {
  node_id : Int32
  trigger_id : Int32
  path : Array[Int32]
  behavior : @foundation.OverlayBehavior
  dismiss : () -> Unit
}

///|
pub fn OverlayTarget::contains_path(
  self : OverlayTarget,
  path : ArrayView[Int32],
) -> Bool {
  path_within(path, self.path)
}

///|
pub fn View::overlay_targets(self : View) -> Array[OverlayTarget] {
  let result = []
  collect_overlay_targets(self.node, [], result)
  ordered_overlay_targets(result)
}

///|
fn collect_overlay_targets(
  node : UiNode,
  path : Array[Int32],
  result : Array[OverlayTarget],
) -> Unit {
  guard !node.is_disabled() && !(node.lifecycle.phase is Disposed) else {
    return
  }
  if node.geometry is Some({ overlay: Some(spec), .. }) &&
    node.children.val.any(child => !(child.lifecycle.phase is Disposed)) {
    result.push({
      node_id: node.id,
      trigger_id: spec.trigger.id,
      path: path.copy(),
      behavior: spec.behavior(),
      dismiss: spec.dismiss,
    })
  }
  for index, child in node.children.val {
    let next = path.copy()
    next.push(index)
    collect_overlay_targets(child, next, result)
  }
}

///|
/// Group-aware Tab stops within a layer, ignoring focus groups outside it.
pub fn View::overlay_tab_paths(
  self : View,
  target : OverlayTarget,
  focused_node_id? : Int32,
) -> Array[Array[Int32]] {
  let paths = []
  if input_node_at_path(self.node, target.path, 0) is Some(node) &&
    node.id == target.node_id {
    collect_tab_focus_paths(node, target.path, focused_node_id, paths)
  }
  paths
}

///|
fn path_within(path : ArrayView[Int32], parent : ArrayView[Int32]) -> Bool {
  guard path.length() >= parent.length() else { return false }
  for index, part in parent {
    if path[index] != part {
      return false
    }
  }
  true
}

///|
// Keep background layers for restoration, below the top pointer barrier.
fn ordered_overlay_layers(layers : Array[OverlayLayer]) -> Array[OverlayLayer] {
  for index in (layers.length() - 1)>=..0 {
    if layers[index].node.geometry is Some({ overlay: Some(spec), .. }) &&
      spec.behavior().pointer == BlockOutside {
      let owner = layers[index].path
      let ordered = layers.filter(layer => !path_within(layer.path, owner))
      for layer in layers {
        if path_within(layer.path, owner) {
          ordered.push(layer)
        }
      }
      return ordered
    }
  }
  layers
}

///|
fn ordered_overlay_targets(
  targets : Array[OverlayTarget],
) -> Array[OverlayTarget] {
  for index in (targets.length() - 1)>=..0 {
    if targets[index].behavior.pointer == BlockOutside {
      let owner = targets[index].path
      let ordered = targets.filter(target => !path_within(target.path, owner))
      for target in targets {
        if path_within(target.path, owner) {
          ordered.push(target)
        }
      }
      return ordered
    }
  }
  targets
}

///|
/// Hosts reject focus requests outside the top containing focus scope.
pub fn View::focus_allows_path(self : View, path : Array[Int32]) -> Bool {
  let targets = self.overlay_targets()
  for index in (targets.length() - 1)>=..0 {
    if targets[index].behavior.focus == Contain {
      return path_within(path, targets[index].path)
    }
  }
  true
}

///|
/// Hosts reject activation/capture outside the top pointer barrier. This is
/// independent of keyboard focus containment.
pub fn View::pointer_allows_path(self : View, path : Array[Int32]) -> Bool {
  let targets = self.overlay_targets()
  for index in (targets.length() - 1)>=..0 {
    if targets[index].behavior.pointer == BlockOutside {
      return targets[index].contains_path(path)
    }
  }
  true
}
