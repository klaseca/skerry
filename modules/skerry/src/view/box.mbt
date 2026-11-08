///|
pub fn box(style? : @style.BoxStyle, disabled? : &@value.BoolValue) -> View {
  let style = resolve_style(style)
  view_from_node({
    id: next_ui_node_id(),
    lifecycle: NodeLifecycle(),
    component_name: "Box",
    styles: None,
    metadata: None,
    geometry: None,
    specified_style: Some(StyleDeclaration(style)),
    make_crater: fn(_text_layout_system, styles) {
      leaf_node(
        "box",
        box_style(),
        Size(
          width=styles.style.layout.width.unwrap_or(0.0),
          height=styles.style.layout.height.unwrap_or(0.0),
        ),
      )
    },
    painter: box_painter(surface=true),
    events: ElementEvents(disabled?),
    reactivity: empty_reactivity(),
    children: Ref([]),
  })
}

///|
pub fn fill_box(
  height : Double,
  style? : @style.BoxStyle,
  disabled? : &@value.BoolValue,
) -> View {
  let style = resolve_style(style)
  view_from_node({
    id: next_ui_node_id(),
    lifecycle: NodeLifecycle(),
    component_name: "FillBox",
    styles: None,
    metadata: None,
    geometry: None,
    specified_style: Some(StyleDeclaration(style)),
    make_crater: fn(_text_layout_system, _styles) {
      leaf_node("fill-box", fill_box_style(height), @foundation.Size::zero())
    },
    painter: box_painter(surface=true),
    events: ElementEvents(disabled?),
    reactivity: empty_reactivity(),
    children: Ref([]),
  })
}
