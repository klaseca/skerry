///|
priv struct TextSpec {
  text : TextContent
}

///|
/// Display a String source. Constants create no effect; reactive sources
/// update an applied string per mount. Equal strings do not request layout.
pub fn text(
  value : &@value.StringValue,
  style? : TextStyle,
  disabled? : &@value.BoolValue,
) -> View {
  let text = value.to_binding()
  let style = style.unwrap_or(TextStyle())
  let value = TextContent(text)
  let id = value.id
  let spec = { text: value, }
  view_from_node({
    lifecycle: NodeLifecycle(),
    id,
    component_name: "Text",
    styles: None,
    metadata: None,
    geometry: None,
    specified_style: Some(StyleDeclaration(style)),
    make_crater: fn(text_layout_system, styles) {
      let font = styles.resolved_font()
      text_node(
        "text",
        content_style(styles.style, font),
        text_measure_func(spec, text_layout_system, font),
        spec.text.get(),
      )
    },
    painter: text_painter(spec),
    events: ElementEvents(disabled?),
    reactivity: text_reactivity(value),
    children: Ref([]),
  })
}

///|
/// Format a Signal through Show. Custom formatting uses text(bind(() => ...)).
pub fn[T : Show] text_of(
  value : @reactive.Signal[T],
  style? : TextStyle,
  disabled? : &@value.BoolValue,
) -> View {
  text(@reactive.bind(fn() { value.get().to_string() }), style?, disabled?)
}
