///|
pub struct PaintContext {
  renderer : &@foundation.SceneRenderer
  text_layout_system : @text.TextLayoutSystem
  focused : Bool
  state : @foundation.ControlState
  theme : @style.Theme
  font : @foundation.FontSpec
  padding : @foundation.Insets
  styles : ReadOnlyArray[@style.StyleDeclaration]
}

///|
pub struct Painter {
  priv paint : (PaintContext, @foundation.Rect) -> Unit
  // Explicit pure metadata resolvers are separate from drawing callbacks.
  // Diagnostics never invoke paint or read a component's live state.
  priv computed_style : ((ComputedStyleContext) -> @diagnostics.ComputedStyle)?
}

///|
fn PaintContext::PaintContext(
  renderer : &@foundation.SceneRenderer,
  text_layout_system~ : @text.TextLayoutSystem,
  theme~ : @style.Theme,
) -> PaintContext {
  {
    renderer,
    text_layout_system,
    theme,
    font: theme.font,
    padding: @foundation.Insets::all(0.0),
    styles: ReadOnlyArray::from_array([]),
    focused: false,
    state: ControlState(),
  }
}

///|
fn PaintContext::with_state(
  self : PaintContext,
  state : @foundation.ControlState,
) -> PaintContext {
  { ..self, focused: state.focused, state, }
}

///|
pub fn PaintContext::fill_box(
  self : PaintContext,
  frame : @foundation.Rect,
  color : @foundation.Color,
  radius : Double,
) -> Unit {
  if radius <= 0.0 {
    self.renderer.fill_rect(frame, color)
  } else {
    self.renderer.fill_rounded_rect(RoundedRect(rect=frame, radius~), color)
  }
}

///|
pub fn PaintContext::draw_text(
  self : PaintContext,
  text : String,
  frame : @foundation.Rect,
  font : @foundation.FontSpec,
  color : @foundation.Color,
  align : @foundation.TextAlign,
  baseline~ : Double = font.point_size() * 0.8,
) -> Unit {
  self.renderer.draw_text({ text, frame, baseline, font, color, align, })
}

///|
pub fn PaintContext::draw_text_block(
  self : PaintContext,
  text : String,
  frame : @foundation.Rect,
  font : @foundation.FontSpec,
  color : @foundation.Color,
  align : @foundation.TextAlign,
  center_vertical~ : Bool = false,
) -> Unit {
  let layout = self.text_layout_system.layout(
    TextLayoutInput(text~, font~, max_width=Some(frame.size.width)),
  )
  let y_offset = if center_vertical && frame.size.height > layout.size.height {
    (frame.size.height - layout.size.height) * 0.5
  } else {
    0.0
  }
  for line in layout.lines {
    self.draw_text(
      line.text,
      Rect(
        x=aligned_line_x(frame, line, align),
        y=frame.origin.y + y_offset + line.y,
        width=line.width,
        height=line.height,
      ),
      font,
      color,
      TextStart,
      baseline=line.baseline,
    )
  }
}

///|
pub fn Painter::empty() -> Painter {
  {
    paint: fn(_context, _frame) { () },
    computed_style: Some(fn(_) { @diagnostics.ComputedStyle() }),
  }
}

///|
pub fn Painter::Painter(
  paint : (PaintContext, @foundation.Rect) -> Unit,
) -> Painter {
  { paint, computed_style: None, }
}

///|
fn resolve_box_style(
  state : @foundation.ControlState,
  theme : @style.Theme,
  layers : ReadOnlyArray[@style.StyleDeclaration],
  surface~ : Bool = false,
) -> @diagnostics.ComputedStyle {
  let palette = {
    ..resolve_plain_style(
      layers,
      state,
      @diagnostics.ComputedStyle(
        background?=if surface {
          Some(theme.resolve(@style.surface_token))
        } else {
          None
        },
      ),
      theme~,
    ),
    color: None,
    align: None,
  }
  let paints_surface = palette.background is Some(_) ||
    (
      palette.stroke_color is Some(_) &&
      palette.stroke_width is Some(width) &&
      width > 0.0
    )
  {
    ..palette,
    radius: if paints_surface {
      Some(palette.radius.unwrap_or(0.0))
    } else {
      None
    },
  }
}

///|
fn box_painter(surface~ : Bool = false) -> Painter {
  Painter(fn(context, frame) {
    let palette = resolve_box_style(
      context.state,
      context.theme,
      context.styles,
      surface~,
    )
    if palette.background is Some(color) {
      context.fill_box(frame, color, palette.radius.unwrap())
    }
    context.stroke_appearance(frame, palette.radius.unwrap_or(0.0), palette)
  }).with_computed_style(fn(context) {
    resolve_box_style(context.state, context.theme, context.styles, surface~)
  })
}

///|
fn aligned_line_x(
  frame : @foundation.Rect,
  line : @text.TextLayoutLine,
  align : @foundation.TextAlign,
) -> Double {
  match align {
    TextStart => frame.origin.x + line.x
    TextCenter => frame.origin.x + (frame.size.width - line.width) * 0.5
    TextEnd => frame.origin.x + frame.size.width - line.width
  }
}
