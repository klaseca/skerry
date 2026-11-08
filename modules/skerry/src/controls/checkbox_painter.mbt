///|
fn checkbox_painter(spec : CheckboxSpec) -> @view.Painter {
  let resolve = fn(
    frame,
    state,
    theme : @style.Theme,
    font : @foundation.FontSpec,
    layers : ReadOnlyArray[@style.StyleDeclaration],
  ) {
    resolve_checkbox_style(frame, state, theme, font, layers)
  }
  @view.Painter(fn(context, frame) {
    let frame = frame.inset(context.padding)
    let palette = resolve(
      frame,
      context.state,
      context.theme,
      context.font,
      context.styles,
    )
    let indicator = palette.indicator_size.unwrap()
    let gap = palette.indicator_gap.unwrap()
    let box_frame = @foundation.Rect(
      x=frame.origin.x,
      y=frame.origin.y + (frame.size.height - indicator.height) * 0.5,
      width=indicator.width,
      height=indicator.height,
    )
    context.fill_box(
      box_frame,
      palette.background.unwrap(),
      palette.radius.unwrap(),
    )
    context.stroke_appearance(box_frame, palette.radius.unwrap(), palette)
    if spec.checked.get() {
      context.fill_box(
        box_frame.inset(@foundation.Insets::all(4.0)),
        palette.marker_color.unwrap(),
        palette.radius.unwrap() * 0.5,
      )
    }
    let label = spec.label.get()
    if !label.is_empty() {
      context.draw_text_block(
        label,
        Rect(
          x=box_frame.origin.x + indicator.width + gap,
          y=frame.origin.y,
          width=(frame.size.width - indicator.width - gap).max(0.0),
          height=frame.size.height,
        ),
        context.font,
        palette.color.unwrap(),
        palette.align.unwrap(),
        center_vertical=true,
      )
    }
  }).with_computed_style(fn(context) {
    resolve(
      context.content,
      context.state,
      context.theme,
      context.font,
      context.styles,
    )
  })
}

///|
fn resolve_checkbox_style(
  frame : @foundation.Rect,
  state : @foundation.ControlState,
  theme : @style.Theme,
  font : @foundation.FontSpec,
  layers : ReadOnlyArray[@style.StyleDeclaration],
) -> @diagnostics.ComputedStyle {
  let mut result = control_defaults(
    state,
    @diagnostics.ComputedStyle(
      font~,
      color=theme.resolve(@style.text_token),
      background=theme.resolve(@style.control_surface_token),
      radius=4.0,
      align=TextStart,
      stroke_color=theme.resolve(@style.border_token),
      stroke_width=1.0,
      marker_color=theme.resolve(@style.accent_token),
      indicator_size=Size(width=18.0, height=18.0),
      indicator_gap=8.0,
    ),
    theme,
  )
  for layer in layers {
    let style : CheckboxStyle? = layer.get()
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
      style.frame.merge(style.indicator),
      style.label,
      state,
      theme,
    )
    let size = result.indicator_size.unwrap()
    result = {
      ..result,
      marker_color: normal_part_color(
        result.marker_color,
        style.marker_color,
        state,
        theme,
      ),
      indicator_size: Some(
        Size(
          width=@style.style_value(style.indicator).layout.width
            .map(style_length)
            .unwrap_or(size.width),
          height=@style.style_value(style.indicator).layout.height
            .map(style_length)
            .unwrap_or(size.height),
        ),
      ),
      indicator_gap: merge_style_option(
        result.indicator_gap,
        style.gap.map(style_length),
      ),
    }
  }
  let result = fit_choice_palette(result, frame)
  result
}
