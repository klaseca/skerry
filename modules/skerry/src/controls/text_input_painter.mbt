///|
fn text_input_painter(spec : TextInputSpec) -> @view.Painter {
  @view.Painter(fn(context, frame) {
    let palette = resolve_text_input_style(
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
    let content_frame = frame.inset(context.padding)
    let value = text_input_value(spec)
    context.renderer.push_clip(content_frame)
    let value_layout = text_input_layout(context, value)
    let display_context = if value.is_empty() {
      context.with_font(palette.placeholder_font.unwrap())
    } else {
      context
    }
    let display_layout = if value.is_empty() {
      text_input_layout(display_context, text_input_display_text(spec))
    } else {
      value_layout
    }
    update_text_input_scroll(spec, content_frame, value_layout, context.font)
    paint_text_input_selection(
      context,
      spec,
      content_frame,
      value_layout,
      palette.selection_color.unwrap(),
      palette.align.unwrap(),
    )
    paint_text_input_text(
      display_context,
      spec,
      content_frame,
      display_layout,
      if value.is_empty() {
        palette.placeholder_color.unwrap()
      } else {
        palette.color.unwrap()
      },
      if value.is_empty() {
        palette.placeholder_align.unwrap()
      } else {
        palette.align.unwrap()
      },
    )
    if context.focused {
      paint_text_input_caret(
        context,
        spec,
        content_frame,
        value_layout,
        palette.caret_color.unwrap(),
        palette.align.unwrap(),
      )
    }
    context.renderer.pop_clip()
  }).with_computed_style(fn(context) {
    resolve_text_input_style(
      context.state,
      context.theme,
      context.font,
      context.styles,
    )
  })
}

///|
fn text_input_layout(
  context : @view.PaintContext,
  text : String,
) -> @text.TextLayoutResult {
  context.text_layout_system.layout(
    TextLayoutInput(text~, font=context.font, max_width=None),
  )
}

///|
fn paint_text_input_text(
  context : @view.PaintContext,
  spec : TextInputSpec,
  frame : @foundation.Rect,
  layout : @text.TextLayoutResult,
  color : @foundation.Color,
  align : @foundation.TextAlign,
) -> Unit {
  let state = spec.state
  let text = text_input_display_text(spec)
  let line : @text.TextLayoutLine = if layout.lines.is_empty() {
    {
      text,
      x: 0.0,
      y: 0.0,
      width: 0.0,
      height: context.font.point_size() * 1.25,
      baseline: context.font.point_size() * 0.8,
    }
  } else {
    layout.lines[0]
  }
  context.draw_text(
    text,
    Rect(
      x=frame.origin.x -
        state.scroll_x +
        text_input_alignment_offset(layout, frame.size.width, align),
      y=frame.origin.y + (frame.size.height - line.height) * 0.5,
      width=line.width,
      height=line.height,
    ),
    context.font,
    color,
    TextStart,
    baseline=line.baseline,
  )
}

///|
fn paint_text_input_selection(
  context : @view.PaintContext,
  spec : TextInputSpec,
  frame : @foundation.Rect,
  layout : @text.TextLayoutResult,
  color : @foundation.Color,
  align : @foundation.TextAlign,
) -> Unit {
  let state = spec.state
  let value = text_input_value(spec)
  if context.focused && state.has_selection() && !value.is_empty() {
    state.clamp_to_text(value)
    let start = caret_position(layout, state.selection_start())
    let end = caret_position(layout, state.selection_end())
    context.renderer.fill_rect(
      Rect(
        x=frame.origin.x +
          start -
          state.scroll_x +
          text_input_alignment_offset(layout, frame.size.width, align),
        y=frame.origin.y,
        width=(end - start).max(0.0),
        height=frame.size.height,
      ),
      color,
    )
  }
}

///|
fn paint_text_input_caret(
  context : @view.PaintContext,
  spec : TextInputSpec,
  frame : @foundation.Rect,
  layout : @text.TextLayoutResult,
  color : @foundation.Color,
  align : @foundation.TextAlign,
) -> Unit {
  let state = spec.state
  state.clamp_to_text(text_input_value(spec))
  let caret_width = 1.0
  let max_x = frame.origin.x + frame.size.width - caret_width
  let caret_x = clamp_double(
    frame.origin.x +
    caret_position(layout, state.cursor()) -
    state.scroll_x +
    text_input_alignment_offset(layout, frame.size.width, align),
    frame.origin.x,
    max_x,
  )
  let caret_height = min_double(
    context.font.point_size() * 1.25,
    frame.size.height,
  )
  let caret_y = frame.origin.y + (frame.size.height - caret_height) * 0.5
  context.renderer.fill_rect(
    Rect(x=caret_x, y=caret_y, width=caret_width, height=caret_height),
    color,
  )
}

///|
fn update_text_input_scroll(
  spec : TextInputSpec,
  frame : @foundation.Rect,
  layout : @text.TextLayoutResult,
  font : @foundation.FontSpec,
) -> Unit {
  let state = spec.state
  state.clamp_to_text(text_input_value(spec))
  let caret = caret_position(layout, state.cursor())
  let visible_width = (frame.size.width - text_input_caret_gutter(font)).max(
    0.0,
  )
  let visible_left = state.scroll_x
  let visible_right = state.scroll_x + visible_width
  if caret < visible_left {
    state.scroll_x = caret.max(0.0)
  } else if caret > visible_right {
    state.scroll_x = (caret - visible_width).max(0.0)
  }
  let max_scroll = (layout.size.width - visible_width).max(0.0)
  state.scroll_x = clamp_double(state.scroll_x, 0.0, max_scroll)
}

///|
fn text_input_caret_gutter(font : @foundation.FontSpec) -> Double {
  max_double(4.0, font.point_size() * 0.5)
}

///|
fn caret_position(layout : @text.TextLayoutResult, index : Int32) -> Double {
  if layout.caret_positions.is_empty() {
    0.0
  } else {
    let clamped = index.max(0).min(layout.caret_positions.length() - 1)
    layout.caret_positions[clamped]
  }
}

///|
fn text_input_alignment_offset(
  layout : @text.TextLayoutResult,
  width : Double,
  align : @foundation.TextAlign,
) -> Double {
  let space = (width - layout.size.width).max(0.0)
  match align {
    TextStart => 0.0
    TextCenter => space * 0.5
    TextEnd => space
  }
}

///|
fn resolve_text_input_style(
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
      caret_color=theme.resolve(@style.accent_token),
      selection_color=theme.resolve(@style.selection_token),
    ),
    theme,
    shade_background=false,
  )
  for layer in layers {
    let style : TextInputStyle? = layer.get()
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
      style.text,
      state,
      theme,
    )
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
        @style.style_value(style.placeholder).font,
      ),
      placeholder_align: merge_style_option(
        result.placeholder_align,
        @style.style_value(style.placeholder).align,
      ),
      caret_color: normal_part_color(
        result.caret_color,
        style.caret_color,
        state,
        theme,
      ),
      selection_color: normal_part_color(
        result.selection_color,
        style.selection_color,
        state,
        theme,
      ),
    }
  }
  result
}
