///|
#derive(Eq, Debug)
pub(all) enum PopupPlacement {
  BottomStart
  BottomEnd
  TopStart
  TopEnd
  LeftStart
  RightStart
}

///|
pub extend PopupPlacement with Eq::{equal, not_equal}

///|
pub extend PopupPlacement with Debug::{to_repr}

///|
/// Click adds pointer and keyboard activation to the anchor. Manual leaves its
/// behavior intact; the owner controls visibility through an external signal.
#derive(Eq, Debug)
pub(all) enum PopupTrigger {
  Click
  Manual
}

///|
pub extend PopupTrigger with Eq::{equal, not_equal}

///|
pub extend PopupTrigger with Debug::{to_repr}

///|
priv struct PopupState {
  id : Int32
  open : @reactive.Signal[Bool]
  on_change : ((@foundation.ChangeEvent[Bool]) -> Unit)?
}

///|
fn PopupState::change(self : PopupState, next : Bool) -> Unit {
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
priv struct PopupSpec {
  anchor : UiNode
  placement : PopupPlacement
  gap : Double
  focus : Bool
  dismiss : () -> Unit
}

///|
/// A floating surface anchored to a live view. Content is built once per open
/// session and disposed on close. It inherits the logical parent's context,
/// styles and disabled state, but paints above ordinary content without ancestor
/// clipping. Placement flips at window edges and is clamped to the viewport.
/// Outside presses are consumed; Escape dismisses the topmost popup. UiRoot
/// manages initial focus, Tab containment and restoration. focus=false keeps
/// keyboard focus in the application, for passive content such as tooltips.
/// The popup owns its closed state by default. An optional open signal exposes
/// that same state to its owner. Click toggles the anchor by default, including
/// Enter/Space. Manual preserves the anchor's behavior for owner-driven opening.
/// The content receives a session-scoped close function. on_change can prevent
/// opening or closing, including content close, just like editable controls.
///
/// ```mbt nocheck
/// @view.popup(
///   @controls.button("Actions"),
///   fn(close) { @controls.button("Close", on_click=close) },
/// )
/// ```
pub fn popup(
  anchor : View,
  open? : @reactive.Signal[Bool],
  trigger~ : PopupTrigger = Click,
  placement~ : PopupPlacement = BottomStart,
  gap~ : Double = 4.0,
  focus~ : Bool = true,
  on_change? : (@foundation.ChangeEvent[Bool]) -> Unit,
  content : (() -> Unit) -> View,
) -> View {
  let state : PopupState = {
    id: next_ui_node_id(),
    open: match open {
      Some(open) => open
      None => @reactive.signal(false)
    },
    on_change: on_change.map(scoped_handler),
  }
  let surface = show_view(
    fn() { state.open.get() },
    fn() {
      let scope = @reactive.Scope::current().unwrap()
      let close = fn() {
        if !scope.is_disposed() {
          scope.run(fn() { state.change(false) })
        }
      }
      content(close)
    },
    id=state.id,
  )
  let anchor = match trigger {
    Manual => anchor
    Click => popup_click_anchor(anchor, state)
  }
  let spec : PopupSpec = {
    anchor: anchor.node,
    placement,
    gap: if gap >= 0.0 && gap.is_finite() {
      gap
    } else {
      0.0
    },
    focus,
    dismiss: fn() { state.change(false) },
  }
  let children = surface.node.children
  let surface = view_from_node({
    ..surface.node,
    component_name: "Popup",
    styles: None,
    specified_style: None,
    painter: Painter(fn(_, _) { () }),
    make_crater: fn(system, styles) {
      @crater_node.Node::new(
        "popup",
        flex_style(flex_spec(Vertical, FlexStyle())),
        children.val.map(node => node.crater(system, styles)),
      )
    },
    geometry: Some({
      translation: Point(x=0.0, y=0.0),
      clip_frame: false,
      scroll: None,
      theme: None,
      popup: Some(spec),
    }),
    events: ElementEvents(editable=true, hit_testable=true),
  })
  let nodes = [anchor.node, surface.node]
  view_from_node({
    id: next_ui_node_id(),
    lifecycle: NodeLifecycle(),
    component_name: "PopupAnchor",
    styles: None,
    metadata: None,
    geometry: None,
    specified_style: None,
    make_crater: fn(system, styles) {
      @crater_node.Node::new(
        "popup-anchor",
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
fn UiNode::is_popup(self : UiNode) -> Bool {
  self.geometry is Some({ popup: Some(_), .. })
}

///|
/// Host protocol for open popups, in paint order (later entries are on top).
/// Paths and callbacks belong to the current live tree; do not retain them after
/// detach. Reading this does not evaluate application producers or run layout.
pub struct PopupTarget {
  node_id : Int32
  anchor_id : Int32
  path : Array[Int32]
  focus : Bool
  dismiss : () -> Unit
}

///|
pub fn View::popup_targets(self : View) -> Array[PopupTarget] {
  let result = []
  collect_popup_targets(self.node, [], result)
  result
}

///|
fn collect_popup_targets(
  node : UiNode,
  path : Array[Int32],
  result : Array[PopupTarget],
) -> Unit {
  guard !node.is_disabled() && !(node.lifecycle.phase is Disposed) else {
    return
  }
  if node.geometry is Some({ popup: Some(spec), .. }) &&
    node.children.val.any(child => !(child.lifecycle.phase is Disposed)) {
    result.push({
      node_id: node.id,
      anchor_id: spec.anchor.id,
      path: path.copy(),
      focus: spec.focus,
      dismiss: spec.dismiss,
    })
  }
  for index, child in node.children.val {
    let next = path.copy()
    next.push(index)
    collect_popup_targets(child, next, result)
  }
}

///|
/// Group-aware Tab stops within one popup, ignoring focus groups outside it.
pub fn View::popup_tab_paths(
  self : View,
  target : PopupTarget,
  focused_node_id? : Int32,
) -> Array[Array[Int32]] {
  let paths = []
  if input_node_at_path(self.node, target.path, 0) is Some(node) &&
    node.id == target.node_id {
    collect_tab_focus_paths(node, target.path, focused_node_id, paths)
  }
  paths
}
