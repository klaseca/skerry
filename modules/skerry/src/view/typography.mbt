///|
priv struct StyleContext {
  theme : @style.Theme
  themes : Map[Int32, @style.Theme]
  inherited_font : @foundation.FontSpec?
  style : @style.BoxStyle
  metrics : Array[@style.StyleMetrics]
  declarations : ReadOnlyArray[@style.StyleDeclaration]
}

///|
fn StyleContext::StyleContext(
  theme : @style.Theme,
  themes : Map[Int32, @style.Theme],
) -> StyleContext {
  {
    theme,
    themes,
    inherited_font: None,
    style: BoxStyle(),
    metrics: [],
    declarations: ReadOnlyArray::from_array([]),
  }
}

///|
fn StyleContext::resolved_font(self : StyleContext) -> @foundation.FontSpec {
  self.inherited_font.unwrap_or(self.theme.font)
}

///|
fn UiNode::style_context(self : UiNode, parent : StyleContext) -> StyleContext {
  parent.for_node(self.id, self.provided_theme(), self.styles)
}

///|
fn StyleContext::for_node(
  self : StyleContext,
  id : Int32,
  fallback : @style.Theme?,
  node_styles : NodeStyles?,
) -> StyleContext {
  let theme = self.themes.get(id).unwrap_or(fallback.unwrap_or(self.theme))
  let declarations = match node_styles {
    Some(value) => value.layers(theme)
    None => ReadOnlyArray::from_array([])
  }
  let mut style = @style.BoxStyle()
  let metrics : Array[@style.StyleMetrics] = []
  let metric_types : Array[@style.StyleDeclaration] = []
  for declaration in declarations {
    style = style.merge(declaration.layout)
    let mut found = false
    for index, before in metric_types {
      if before.same_type(declaration) {
        metrics[index] = metrics[index].merge(declaration.metrics)
        found = true
        break
      }
    }
    if !found {
      metric_types.push(declaration)
      metrics.push(declaration.metrics)
    }
  }
  {
    ..self,
    theme,
    style,
    metrics,
    declarations,
    inherited_font: match style.text.font {
      Some(font) => Some(font)
      None => self.inherited_font
    },
  }
}

///|
fn UiNode::provided_theme(self : UiNode) -> @style.Theme? {
  match self.geometry {
    Some({ theme: Some(spec), .. }) => Some(spec.initial)
    _ => None
  }
}
