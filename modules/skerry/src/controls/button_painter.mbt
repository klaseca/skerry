///|
fn button_painter(spec : ButtonSpec) -> @view.Painter {
  @view.Painter(fn(context, frame) {
    let palette = resolve_button_style(
      context.state,
      context.theme,
      context.font,
      context.styles,
    )
    context.fill_box(
      frame,
      palette.background.unwrap(),
      palette.radius.unwrap(),
    )
    context.stroke_appearance(frame, palette.radius.unwrap(), palette)
    context.draw_text_block(
      spec.label.get(),
      frame.inset(context.padding),
      context.font,
      palette.color.unwrap(),
      palette.align.unwrap(),
      center_vertical=true,
    )
  }).with_computed_style(fn(context) {
    resolve_button_style(
      context.state,
      context.theme,
      context.font,
      context.styles,
    )
  })
}

///|
fn resolve_button_style(
  state : @foundation.ControlState,
  theme : @style.Theme,
  font : @foundation.FontSpec,
  layers : ReadOnlyArray[@style.StyleDeclaration],
) -> @diagnostics.ComputedStyle {
  let mut result = control_defaults(
    state,
    @diagnostics.ComputedStyle(
      font~,
      color=theme.resolve(@style.on_accent_token),
      background=theme.resolve(@style.accent_token),
      radius=6.0,
      align=TextCenter,
    ),
    theme,
  )
  for layer in layers {
    let style : ButtonStyle? = layer.get()
    guard style is Some(style) else {
      result = apply_control_style(
        result,
        layer.layout,
        @view.TextStyle(),
        state,
        theme,
      )
      continue
    }
    result = apply_control_style(
      result,
      style.surface,
      style.label,
      state,
      theme,
    )
  }
  result
}
