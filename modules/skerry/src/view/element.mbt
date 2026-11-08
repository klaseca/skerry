///|
/// Content measurement in logical units. Layout adds padding and border.
pub type Measure = (Double, Double) -> @foundation.IntrinsicSize

///|
/// Applied values for one element's measurement. Reading these never invokes
/// a style producer; the host has already materialized reactive declarations.
pub struct MeasureContext {
  text_layout_system : @text.TextLayoutSystem
  theme : @style.Theme
  font : @foundation.FontSpec
  style : @style.BoxStyle
  styles : ReadOnlyArray[@style.StyleDeclaration]
}

///|
/// Build a leaf with the same layout, input, styles and lifecycle as
/// built-in views. The optional measure callback supplies intrinsic content
/// dimensions. Without it, the leaf has no intrinsic content size: styles and
/// its parent determine its box. Padding is a fallback; an explicit root style
/// takes precedence. Configure disabled state through events. The component
/// name is diagnostic only.
pub fn[S : @style.StyleSpec] element(
  style~ : S,
  measure? : (MeasureContext) -> Measure,
  painter~ : Painter,
  events~ : ElementEvents = ElementEvents(),
  reactivity~ : Reactivity = Reactivity(),
  padding~ : @foundation.Insets = @foundation.Insets::all(0.0),
  component_name~ : String = "Custom",
) -> View {
  let id = match reactivity.text_value {
    Some(text) => text.id
    None => next_ui_node_id()
  }
  view_from_node({
    id,
    lifecycle: NodeLifecycle(),
    component_name,
    styles: None,
    metadata: None,
    geometry: None,
    specified_style: Some(StyleDeclaration(style)),
    make_crater: fn(text_layout_system, styles) {
      let font = styles.resolved_font()
      let style = styles.style
      let style = style.padding(style.layout.padding.unwrap_or(padding))
      let layout_style = content_style(style, font)
      match measure {
        Some(measure) => {
          let measured = measure({
            text_layout_system,
            theme: styles.theme,
            font,
            style,
            styles: styles.declarations,
          })
          @crater_node.Node::with_measure(
            "element",
            layout_style,
            crater_measure(measured),
          )
        }
        None => @crater_node.Node::new("element", layout_style, [])
      }
    },
    painter,
    events,
    reactivity,
    children: Ref([]),
  })
}

///|
fn crater_measure(measure : Measure) -> @crater_core.MeasureFunc {
  {
    func: fn(width, height) {
      let size = measure(width, height)
      {
        min_width: size.min_width,
        max_width: size.max_width,
        min_height: size.min_height,
        max_height: size.max_height,
      }
    },
  }
}

///|
/// Group descendant focus targets into one Tab stop. Arrow navigation uses the
/// same enabled descendants; the preferred entry is a node ID, not an index.
pub fn View::focus_group(self : View, preferred_entry : () -> Int32?) -> View {
  view_from_node({
    ..self.node,
    events: {
      ..self.node.events,
      focus_entry: Some(scoped_callback(preferred_entry)),
    },
  })
}
