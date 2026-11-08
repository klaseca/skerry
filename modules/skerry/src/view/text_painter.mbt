///|
fn text_painter(spec : TextSpec) -> Painter {
  let resolve = fn(
    _,
    state,
    theme : @style.Theme,
    font : @foundation.FontSpec,
    layers : ReadOnlyArray[@style.StyleDeclaration],
  ) {
    let applied = resolve_plain_style(
      layers,
      state,
      @diagnostics.ComputedStyle(
        font~,
        color=theme.resolve(@style.text_token),
        align=TextStart,
      ),
      theme~,
    )
    @diagnostics.ComputedStyle(
      font~,
      color?=applied.color,
      align?=applied.align,
    )
  }
  Painter(fn(context, frame) {
    let palette = resolve(
      frame,
      context.state,
      context.theme,
      context.font,
      context.styles,
    )
    context.draw_text_block(
      spec.text.get(),
      frame.inset(context.padding),
      context.font,
      palette.color.unwrap(),
      palette.align.unwrap_or(TextStart),
    )
  }).with_computed_style(fn(context) {
    resolve(
      context.frame,
      context.state,
      context.theme,
      context.font,
      context.styles,
    )
  })
}
