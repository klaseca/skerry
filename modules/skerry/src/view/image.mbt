///|
/// Display a shared image. Equal-sized replacements repaint without layout.
pub fn image(
  value : &@value.ImageValue,
  style? : ImageStyle,
  disabled? : &@value.BoolValue,
) -> View {
  let id = next_ui_node_id()
  let value = ImageValue(id, value.to_binding())
  let style = style.unwrap_or(ImageStyle())
  view_from_node({
    id,
    lifecycle: NodeLifecycle(),
    component_name: "Image",
    styles: None,
    metadata: None,
    geometry: None,
    specified_style: Some(StyleDeclaration(style)),
    make_crater: fn(_, styles) {
      let size = value.get().size()
      let padding = styles.style.layout.padding.unwrap_or(
        @foundation.Insets::all(0.0),
      )
      let preferred_width = if styles.style.layout.width is None {
        // A height constraint also changes the natural width while width is auto.
        let vertical_padding = padding.top + padding.bottom
        let height = styles.style.layout.height.unwrap_or(
          size.height + vertical_padding,
        )
        let height = match styles.style.layout.max_height {
          Some(maximum) => height.min(maximum)
          None => height
        }
        let height = match styles.style.layout.min_height {
          Some(minimum) => height.max(minimum)
          None => height
        }
        (height - vertical_padding).max(0.0) * size.width / size.height
      } else {
        size.width
      }
      @crater_node.Node::with_measure(
        "image",
        content_style(styles.style, styles.resolved_font()),
        {
          func: fn(width, _) {
            let width = if width > 0.0 { width } else { preferred_width }
            let height = width * size.height / size.width
            {
              min_width: 0.0,
              max_width: preferred_width,
              min_height: height,
              max_height: height,
            }
          },
        },
      )
    },
    painter: image_painter(value),
    events: ElementEvents(disabled?),
    reactivity: image_reactivity(value),
    children: Ref([]),
  })
}

///|
fn image_painter(value : ImageValue) -> Painter {
  Painter(fn(context, frame) {
    let palette = resolve_box_style(
      context.state,
      context.theme,
      context.styles,
    )
    if palette.background is Some(color) {
      context.fill_box(frame, color, palette.radius.unwrap_or(0.0))
    }
    let style = resolved_image_style(context.styles)
    let image = value.get()
    if image.placement(
        frame.inset(context.padding),
        fit=style.fit.unwrap_or(Contain),
        alignment=style.alignment.unwrap_or(Center),
      )
      is Some(placement) {
      context.renderer.draw_image(image, placement)
    }
    context.stroke_appearance(frame, palette.radius.unwrap_or(0.0), palette)
  }).with_computed_style(fn(context) {
    resolve_box_style(context.state, context.theme, context.styles)
  })
}

///|
fn UiNode::image_snapshot(
  self : UiNode,
  content : @foundation.Rect,
  layers : ReadOnlyArray[@style.StyleDeclaration],
) -> @diagnostics.ImageSnapshot? {
  guard self.reactivity.image_value is Some(value) else { return None }
  let image = value.get()
  let style = resolved_image_style(layers)
  let fit = style.fit.unwrap_or(Contain)
  let alignment = style.alignment.unwrap_or(Center)
  Some({
    size: image.size(),
    fit,
    alignment,
    placement: image.placement(content, fit~, alignment~),
  })
}
