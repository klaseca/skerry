///|
#derive(Eq, Debug, Default)
pub struct ControlStyles {
  hovered : Appearance?
  pressed : Appearance?
  focused : Appearance?
  disabled : Appearance?
}

///|
pub extend ControlStyles with Eq::{equal, not_equal}

///|
pub extend ControlStyles with Debug::{to_repr}

///|
fn ControlStyles::merge(
  self : ControlStyles,
  other : ControlStyles,
) -> ControlStyles {
  {
    hovered: merge_appearance(self.hovered, other.hovered),
    pressed: merge_appearance(self.pressed, other.pressed),
    focused: merge_appearance(self.focused, other.focused),
    disabled: merge_appearance(self.disabled, other.disabled),
  }
}

///|
fn merge_appearance(base : Appearance?, next : Appearance?) -> Appearance? {
  match (base, next) {
    (Some(base), Some(next)) => Some(base.merge(next))
    (_, Some(_)) => next
    _ => base
  }
}

///|
/// Add hover overrides, merging explicitly supplied fields with earlier ones.
/// An empty appearance preserves earlier overrides.
pub fn BoxStyle::hovered(self : BoxStyle, appearance : Appearance) -> BoxStyle {
  {
    ..self,
    controls: {
      ..self.controls,
      hovered: merge_appearance(self.controls.hovered, Some(appearance)),
    },
  }
}

///|
/// Add pressed overrides, using the same field-wise composition as BoxStyle.merge.
pub fn BoxStyle::pressed(self : BoxStyle, appearance : Appearance) -> BoxStyle {
  {
    ..self,
    controls: {
      ..self.controls,
      pressed: merge_appearance(self.controls.pressed, Some(appearance)),
    },
  }
}

///|
/// Add focused overrides, using the same field-wise composition as BoxStyle.merge.
pub fn BoxStyle::focused(self : BoxStyle, appearance : Appearance) -> BoxStyle {
  {
    ..self,
    controls: {
      ..self.controls,
      focused: merge_appearance(self.controls.focused, Some(appearance)),
    },
  }
}

///|
/// Disabled overrides replace the default faded colors literally, and do not
/// combine with hover, focused or pressed overrides. Repeated calls merge their
/// explicitly supplied fields, like BoxStyle.merge.
pub fn BoxStyle::disabled(self : BoxStyle, appearance : Appearance) -> BoxStyle {
  {
    ..self,
    controls: {
      ..self.controls,
      disabled: merge_appearance(self.controls.disabled, Some(appearance)),
    },
  }
}
