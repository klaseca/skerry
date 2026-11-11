///|
// Built-in interaction feedback forms the lowest paint layer. Concrete style
// declarations then retain their own normal/state/disabled precedence.
fn control_defaults(
  state : @foundation.ControlState,
  base : @diagnostics.ComputedStyle,
  theme : @style.Theme,
  button~ : Bool = false,
  shade_background~ : Bool = true,
) -> @diagnostics.ComputedStyle {
  let mut result = base
  if state.disabled {
    result = {
      ..result,
      background: result.background.map(color => control_color(color, true)),
      color: result.color.map(color => control_color(color, true)),
      stroke_color: result.stroke_color.map(color => control_color(color, true)),
      marker_color: result.marker_color.map(color => control_color(color, true)),
      placeholder_color: result.placeholder_color.map(color => {
        control_color(color, true)
      }),
      caret_color: result.caret_color.map(color => control_color(color, true)),
      selection_color: result.selection_color.map(color => {
        control_color(color, true)
      }),
    }
  } else {
    if shade_background && (state.hovered || state.pressed) {
      // Compose both overlays before choosing their direction from the original
      // background. Hover must not reverse the pressed effect near the midpoint.
      let hover = if state.hovered { 0.04 } else { 0.0 }
      let press = if state.pressed { 0.12 } else { 0.0 }
      let amount = hover + (1.0 - hover) * press
      result = {
        ..result,
        background: result.background.map(color => {
          control_feedback_color(color, amount)
        }),
      }
    }
    if state.hovered {
      result = {
        ..result,
        stroke_color: result.stroke_color.map(_ => {
          theme.resolve(@style.accent_token)
        }),
      }
    }
    if state.focused {
      result = {
        ..result,
        stroke_color: Some(
          theme.resolve(
            if button {
              @style.text_token
            } else {
              @style.accent_token
            },
          ),
        ),
        stroke_width: Some(2.0),
      }
    }
  }
  result
}

///|
fn apply_control_style(
  base : @diagnostics.ComputedStyle,
  surface : @style.BoxStyle,
  text : @view.TextStyle,
  state : @foundation.ControlState,
  theme : @style.Theme,
) -> @diagnostics.ComputedStyle {
  let mut result = base
  for layer in @style.style_layers(surface) {
    result = if state.disabled {
      apply_disabled_style(result, layer, theme~)
    } else {
      @view.apply_active_control_styles(
        @view.apply_appearance(result, Some(layer.paint), theme~),
        layer.controls,
        state,
        theme~,
      )
    }
  }
  let surface_value = @style.style_value(surface)
  let text_value = @style.style_value(text)
  {
    ..result,
    color: resolve_text_part(result.color, text, state, theme),
    align: merge_style_option(
      result.align,
      merge_style_option(surface_value.text.align, text_value.align),
    ),
  }
}

///|
fn control_feedback_color(
  color : @foundation.Color,
  amount : Double,
) -> @foundation.Color {
  // Weighted RGB brightness also handles custom palette colors independently
  // of the application's Light/Dark/System preference. Keep the source alpha.
  let brightness = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
  let target = if brightness < 0.5 { 1.0 } else { 0.0 }
  {
    ..color,
    r: color.r + (target - color.r) * amount,
    g: color.g + (target - color.g) * amount,
    b: color.b + (target - color.b) * amount,
  }
}

///|
fn apply_disabled_style(
  base : @diagnostics.ComputedStyle,
  style : @style.BoxStyle,
  theme~ : @style.Theme,
) -> @diagnostics.ComputedStyle {
  let result = @view.apply_appearance(base, Some(style.paint), theme~)
  // Fade only the normal colors supplied by this declaration. Values inherited
  // from lower layers were already faded or explicitly supplied for disabled.
  let result = {
    ..result,
    background: merge_style_option(
      result.background,
      style.paint.background.map(color => {
        control_color(color.resolve(theme), true)
      }),
    ),
    color: merge_style_option(
      result.color,
      style.paint.color.map(color => control_color(color.resolve(theme), true)),
    ),
    stroke_color: merge_style_option(
      result.stroke_color,
      style.paint.stroke_color.map(color => {
        control_color(color.resolve(theme), true)
      }),
    ),
  }
  @view.apply_appearance(result, style.controls.disabled, theme~)
}

///|
// A part's explicit text color/state overrides the surface's inherited defaults
// within each declaration; later declarations still retain their layer priority.
fn resolve_text_layer(
  base : @foundation.Color?,
  text : @view.TextStyle,
  state : @foundation.ControlState,
  theme : @style.Theme,
) -> @foundation.Color? {
  let mut color = merge_style_option(
    base,
    text.color.map(value => control_color(value.resolve(theme), state.disabled)),
  )
  let resolve = fn(appearance : @view.TextAppearance) {
    appearance.color.map(value => value.resolve(theme))
  }
  if state.disabled {
    color = merge_style_option(color, text.controls.disabled.bind(resolve))
  } else {
    if state.hovered {
      color = merge_style_option(color, text.controls.hovered.bind(resolve))
    }
    if state.focused {
      color = merge_style_option(color, text.controls.focused.bind(resolve))
    }
    if state.pressed {
      color = merge_style_option(color, text.controls.pressed.bind(resolve))
    }
  }
  color
}

///|
fn normal_part_color(
  base : @foundation.Color?,
  next : @style.StyleColor?,
  state : @foundation.ControlState,
  theme : @style.Theme,
) -> @foundation.Color? {
  merge_style_option(
    base,
    next.map(value => control_color(value.resolve(theme), state.disabled)),
  )
}

///|
fn resolve_text_part(
  base : @foundation.Color?,
  text : @view.TextStyle,
  state : @foundation.ControlState,
  theme : @style.Theme,
) -> @foundation.Color? {
  let mut result = base
  for layer in @style.style_layers(text) {
    result = resolve_text_layer(result, layer, state, theme)
  }
  result
}

///|
fn control_color(
  color : @foundation.Color,
  disabled : Bool,
) -> @foundation.Color {
  if disabled {
    { ..color, a: color.a * 0.45, }
  } else {
    color
  }
}

///|
fn min_double(left : Double, right : Double) -> Double {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn max_double(left : Double, right : Double) -> Double {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn fit_choice_palette(
  palette : @diagnostics.ComputedStyle,
  frame : @foundation.Rect,
) -> @diagnostics.ComputedStyle {
  let size = palette.indicator_size.unwrap()
  {
    ..palette,
    indicator_size: Some(
      Size(
        width=size.width.min(frame.size.width.max(0.0)),
        height=size.height.min(frame.size.height.max(0.0)),
      ),
    ),
  }
}

///|
fn[T] merge_style_option(a : T?, b : T?) -> T? {
  match b {
    Some(_) => b
    None => a
  }
}

///|
fn text_root_style(
  surface : @style.BoxStyle,
  text : @view.TextStyle,
) -> @style.BoxStyle {
  let text = @style.style_value(text)
  let surface = match text.font {
    Some(font) => surface.font(font)
    None => surface
  }
  match text.align {
    Some(align) => surface.align(align)
    None => surface
  }
}
