///|
pub fn apply_active_control_styles(
  base : @diagnostics.ComputedStyle,
  styles : @style.ControlStyles,
  state : @foundation.ControlState,
  theme~ : @style.Theme,
) -> @diagnostics.ComputedStyle {
  let mut result = base
  if state.hovered {
    result = apply_appearance(result, styles.hovered, theme~)
  }
  if state.focused {
    result = apply_appearance(result, styles.focused, theme~)
  }
  if state.pressed {
    result = apply_appearance(result, styles.pressed, theme~)
  }
  result
}

///|
fn resolve_plain_style(
  layers : ReadOnlyArray[@style.StyleDeclaration],
  state : @foundation.ControlState,
  base : @diagnostics.ComputedStyle,
  theme~ : @style.Theme,
) -> @diagnostics.ComputedStyle {
  let mut result = base
  for declaration in layers {
    for root in declaration.roots {
      result = apply_plain_declaration(result, root, state, theme~)
    }
  }
  result
}

///|
fn apply_plain_declaration(
  base : @diagnostics.ComputedStyle,
  style : @style.BoxStyle,
  state : @foundation.ControlState,
  theme~ : @style.Theme,
) -> @diagnostics.ComputedStyle {
  let result = apply_appearance(base, Some(style.paint), theme~)
  let result = {
    ..result,
    align: override_control_value(result.align, style.text.align),
  }
  if state.disabled {
    apply_appearance(result, style.controls.disabled, theme~)
  } else {
    apply_active_control_styles(result, style.controls, state, theme~)
  }
}

///|
pub fn apply_appearance(
  base : @diagnostics.ComputedStyle,
  appearance : @style.Appearance?,
  theme~ : @style.Theme,
) -> @diagnostics.ComputedStyle {
  guard appearance is Some(appearance) else { base }
  {
    ..base,
    background: override_control_value(
      base.background,
      appearance.background.map(value => value.resolve(theme)),
    ),
    color: override_control_value(
      base.color,
      appearance.color.map(value => value.resolve(theme)),
    ),
    radius: override_control_value(base.radius, appearance.radius),
    stroke_color: override_control_value(
      base.stroke_color,
      appearance.stroke_color.map(value => value.resolve(theme)),
    ),
    stroke_width: override_control_value(
      base.stroke_width,
      appearance.stroke_width,
    ),
  }
}

///|
fn[T] override_control_value(base : T?, next : T?) -> T? {
  match next {
    Some(_) => next
    None => base
  }
}

///|
pub fn PaintContext::stroke_appearance(
  self : PaintContext,
  frame : @foundation.Rect,
  radius : Double,
  palette : @diagnostics.ComputedStyle,
) -> Unit {
  if palette.stroke_color is Some(color) &&
    palette.stroke_width is Some(width) &&
    width > 0.0 {
    self.renderer.stroke_rounded_rect(
      RoundedRect(rect=frame, radius~),
      color,
      width,
    )
  }
}
