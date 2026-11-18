///|
fn select_painter(
  content : @view.TextContent,
  empty : () -> Bool,
) -> @view.Painter {
  @view.Painter(fn(context, frame) {
    let palette = resolve_select_style(
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
    let inner = frame.inset(context.padding)
    let text = {
      ..inner,
      size: @foundation.Size(
        width=(inner.size.width - 24.0).max(0.0),
        height=inner.size.height,
      ),
    }
    context.renderer.push_clip(inner)
    let display = if empty() {
      context.with_font(palette.placeholder_font.unwrap())
    } else {
      context
    }
    display.draw_text_block(
      content.get(),
      text,
      display.font,
      if empty() {
        palette.placeholder_color.unwrap()
      } else {
        palette.color.unwrap()
      },
      if empty() {
        palette.placeholder_align.unwrap()
      } else {
        palette.align.unwrap()
      },
      center_vertical=true,
    )
    select_indicator(
      context,
      @foundation.Rect(
        x=inner.origin.x + (inner.size.width - 20.0).max(0.0),
        y=inner.origin.y,
        width=20.0.min(inner.size.width),
        height=inner.size.height,
      ),
      palette.color.unwrap(),
      check=false,
    )
    context.renderer.pop_clip()
  }).with_computed_style(fn(context) {
    resolve_select_style(
      context.state,
      context.theme,
      context.font,
      context.styles,
    )
  })
}

///|
fn resolve_select_style(
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
      radius=6.0,
      align=TextStart,
      stroke_color=theme.resolve(@style.border_token),
      stroke_width=1.0,
      placeholder_color=theme.resolve(@style.muted_text_token),
      placeholder_font=font,
      placeholder_align=TextStart,
    ),
    theme,
    shade_background=false,
  )
  for layer in layers {
    let style : SelectStyle? = layer.get()
    match style {
      None =>
        result = apply_control_style(
          result,
          layer.layout,
          @view.TextStyle(),
          state,
          theme,
        )
      Some(style) => {
        result = apply_control_style(
          result,
          style.surface,
          style.label,
          state,
          theme,
        )
        let placeholder = @style.style_value(style.placeholder)
        result = {
          ..result,
          placeholder_color: resolve_text_part(
            result.placeholder_color,
            style.placeholder,
            state,
            theme,
          ),
          placeholder_font: merge_style_option(
            result.placeholder_font,
            placeholder.font,
          ),
          placeholder_align: merge_style_option(
            result.placeholder_align,
            placeholder.align,
          ),
        }
      }
    }
  }
  result
}

///|
fn select_option_painter(
  content : @view.TextContent,
  selected : () -> Bool,
) -> @view.Painter {
  @view.Painter(fn(context, frame) {
    let palette = resolve_select_option_style(
      context.state,
      context.theme,
      context.font,
      context.styles,
      selected(),
    )
    context.fill_box(
      frame,
      palette.background.unwrap(),
      palette.radius.unwrap(),
    )
    context.stroke_appearance(frame, palette.radius.unwrap(), palette)
    let inner = frame.inset(context.padding)
    context.renderer.push_clip(inner)
    context.draw_text_block(
      content.get(),
      {
        ..inner,
        size: @foundation.Size(
          width=(inner.size.width - 24.0).max(0.0),
          height=inner.size.height,
        ),
      },
      context.font,
      palette.color.unwrap(),
      palette.align.unwrap(),
      center_vertical=true,
    )
    if selected() {
      select_indicator(
        context,
        @foundation.Rect(
          x=inner.origin.x + (inner.size.width - 20.0).max(0.0),
          y=inner.origin.y,
          width=20.0.min(inner.size.width),
          height=inner.size.height,
        ),
        palette.color.unwrap(),
        check=true,
      )
    }
    context.renderer.pop_clip()
  }).with_computed_style(fn(context) {
    resolve_select_option_style(
      context.state,
      context.theme,
      context.font,
      context.styles,
      selected(),
    )
  })
}

///|
// Built-in indicators are geometry, not glyphs in the application's font.
fn select_indicator(
  context : @view.PaintContext,
  frame : @foundation.Rect,
  color : @foundation.Color,
  check~ : Bool,
) -> Unit {
  let size = 12.0.min(frame.size.width).min(frame.size.height)
  guard size > 0.0 else { return }
  let x = frame.origin.x + (frame.size.width - size) * 0.5
  let y = frame.origin.y + (frame.size.height - size) * 0.5
  let (start, middle, end) : (
    @foundation.Point,
    @foundation.Point,
    @foundation.Point,
  ) = if check {
    (
      Point(x=x + size * 0.1, y=y + size * 0.5),
      Point(x=x + size * 0.4, y=y + size * 0.8),
      Point(x=x + size * 0.9, y=y + size * 0.2),
    )
  } else {
    (
      Point(x=x + size * 0.15, y=y + size * 0.35),
      Point(x=x + size * 0.5, y=y + size * 0.7),
      Point(x=x + size * 0.85, y=y + size * 0.35),
    )
  }
  let width = (size / 6.0).min(2.0)
  context.renderer.draw_line(start, middle, color, width)
  context.renderer.draw_line(middle, end, color, width)
}

///|
fn resolve_select_option_style(
  state : @foundation.ControlState,
  theme : @style.Theme,
  font : @foundation.FontSpec,
  layers : ReadOnlyArray[@style.StyleDeclaration],
  selected : Bool,
) -> @diagnostics.ComputedStyle {
  let mut result = control_defaults(
    // Options share background feedback for pointer hover and keyboard focus.
    // The field keeps its focus outline; list rows have no built-in outline.
    {
      ..state,
      hovered: state.hovered || (state.focused && !selected),
      focused: false,
    },
    @diagnostics.ComputedStyle(
      font~,
      color=theme.resolve(@style.text_token),
      background=theme.resolve(
        if selected {
          @style.selection_token
        } else {
          @style.control_surface_token
        },
      ),
      radius=4.0,
      align=TextStart,
    ),
    theme,
  )
  for layer in layers {
    let style : ButtonStyle? = layer.get()
    result = match style {
      Some(style) =>
        apply_control_style(result, style.surface, style.label, state, theme)
      None =>
        apply_control_style(
          result,
          layer.layout,
          @view.TextStyle(),
          state,
          theme,
        )
    }
  }
  result
}
