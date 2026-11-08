///|
/// Frozen paint geometry and applied values for a pure diagnostic resolver.
/// Frame is the outer box; content excludes its layout border and padding.
/// Styles are already materialized. Components choose the geometry relevant
/// to their parts without drawing or sampling reactive sources.
pub struct ComputedStyleContext {
  frame : @foundation.Rect
  content : @foundation.Rect
  state : @foundation.ControlState
  theme : @style.Theme
  font : @foundation.FontSpec
  styles : ReadOnlyArray[@style.StyleDeclaration]
}

///|
/// Attach a pure diagnostic resolver. It must read only its arguments, without
/// sampling live state or drawing. Snapshots can invoke it independently of paint.
pub fn Painter::with_computed_style(
  self : Painter,
  resolve : (ComputedStyleContext) -> @diagnostics.ComputedStyle,
) -> Painter {
  { ..self, computed_style: Some(resolve), }
}

///|
fn UiNode::snapshot_style(
  self : UiNode,
  geometry : NodeGeometry,
  state : @foundation.ControlState,
) -> @diagnostics.ComputedStyle? {
  guard self.painter.computed_style is Some(resolve) else { return None }
  Some(
    resolve({
      frame: geometry.frame,
      content: geometry.content,
      state,
      theme: geometry.theme,
      font: geometry.font,
      styles: geometry.styles,
    }),
  )
}
