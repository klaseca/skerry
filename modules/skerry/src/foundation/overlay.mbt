///|
/// Preserve leaves focus unchanged. Cycle enters the layer, cycles Tab and
/// restores focus on close. Contain additionally rejects outside focus and
/// clears previous focus when the layer has no available controls.
#derive(Eq, Debug)
pub(all) enum OverlayFocus {
  Preserve
  Cycle
  Contain
}

///|
pub extend OverlayFocus with Eq::{equal, not_equal}

///|
pub extend OverlayFocus with Debug::{to_repr}

///|
/// PassThrough permits pointer/wheel input outside the layer. BlockOutside
/// places the layer's subtree above background layers and blocks such input.
#derive(Eq, Debug)
pub(all) enum OverlayPointer {
  PassThrough
  BlockOutside
}

///|
pub extend OverlayPointer with Eq::{equal, not_equal}

///|
pub extend OverlayPointer with Debug::{to_repr}

///|
/// Ignore forwards the event, Consume handles it without closing, and Dismiss
/// requests closing and consumes it even when the change is prevented.
#derive(Eq, Debug)
pub(all) enum OverlayDismiss {
  Ignore
  Consume
  Dismiss
}

///|
pub extend OverlayDismiss with Eq::{equal, not_equal}

///|
pub extend OverlayDismiss with Debug::{to_repr}

///|
/// Independent input policies, with no component identity or live callbacks.
/// Focus containment and pointer blocking can be used separately. Explicit
/// dismissal routes take precedence over passing the corresponding event on.
#derive(Eq, Debug)
pub(all) struct OverlayBehavior {
  focus : OverlayFocus
  pointer : OverlayPointer
  escape : OverlayDismiss
  outside_press : OverlayDismiss
}

///|
pub extend OverlayBehavior with Eq::{equal, not_equal}

///|
pub extend OverlayBehavior with Debug::{to_repr}

///|
pub fn OverlayBehavior::OverlayBehavior(
  focus~ : OverlayFocus = Preserve,
  pointer~ : OverlayPointer = PassThrough,
  escape~ : OverlayDismiss = Ignore,
  outside_press~ : OverlayDismiss = Ignore,
) -> OverlayBehavior {
  { focus, pointer, escape, outside_press, }
}

///|
pub fn OverlayBehavior::takes_focus(self : OverlayBehavior) -> Bool {
  self.focus != Preserve
}
