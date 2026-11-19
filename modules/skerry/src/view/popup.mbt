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
priv struct PopupSpec {
  placement : PopupPlacement
  gap : Double
  focus : Bool
  match_anchor_width : Bool
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
/// match_anchor_width sizes the floating surface to the anchor, capped by the
/// window viewport. Child layout styles still apply inside that surface.
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
  match_anchor_width~ : Bool = false,
  on_change? : (@foundation.ChangeEvent[Bool]) -> Unit,
  content : (() -> Unit) -> View,
) -> View {
  let (anchor, surface, state) = overlay_session(
    anchor, open, trigger, on_change, content,
  )
  let spec : OverlaySpec = {
    policy: PopupSpec::{
      placement,
      gap: if gap >= 0.0 && gap.is_finite() {
        gap
      } else {
        0.0
      },
      focus,
      match_anchor_width,
    },
    dismiss: fn() { state.change(false) },
    trigger: anchor.node,
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
  })
  overlay_view(anchor, surface, spec, "PopupAnchor")
}
