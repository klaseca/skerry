///|
/// Interaction state for one node in one root. Disabled includes ancestors and
/// suppresses the other states. Pressed means an active pointer press over its
/// captured target, or a held activation key on the focused target.
#derive(Eq, Debug)
pub(all) struct ControlState {
  hovered : Bool
  pressed : Bool
  focused : Bool
  disabled : Bool
}

///|
pub extend ControlState with Eq::{equal, not_equal}

///|
pub extend ControlState with Debug::{to_repr}

///|
pub fn ControlState::ControlState(
  hovered~ : Bool = false,
  pressed~ : Bool = false,
  focused~ : Bool = false,
  disabled~ : Bool = false,
) -> ControlState {
  { hovered, pressed, focused, disabled, }
}
