///|
priv struct ModalSpec {
  close_on_escape : Bool
  close_on_backdrop : Bool
}

///|
/// A viewport-sized modal layer for compound controls. Its style uses the same
/// flex layout as column; the caller chooses content alignment and backdrop.
/// The host confines input to the top modal and its nested popups. Dialog
/// supplies centered placement and the usual surface and backdrop styles.
/// Visibility, trigger activation and session lifetime follow popup.
///
/// ```mbt check
/// test {
///   let view = @view.modal(
///     @controls.button("Open"),
///     style=@view.FlexStyle().align_items(End).justify_content(End),
///     fn(close) { @controls.button("Close", on_click=close) },
///   )
///   ignore(view)
/// }
/// ```
pub fn modal(
  anchor : View,
  open? : @reactive.Signal[Bool],
  trigger~ : PopupTrigger = Click,
  style? : FlexStyle,
  close_on_escape~ : Bool = true,
  close_on_backdrop~ : Bool = true,
  on_change? : (@foundation.ChangeEvent[Bool]) -> Unit,
  content : (() -> Unit) -> View,
) -> View {
  let (anchor, surface, state) = overlay_session(
    anchor, open, trigger, on_change, content,
  )
  let spec : OverlaySpec = {
    policy: ModalSpec::{ close_on_escape, close_on_backdrop, },
    dismiss: fn() { state.change(false) },
    trigger: anchor.node,
  }
  let children = surface.node.children
  let surface = view_from_node({
    ..surface.node,
    component_name: "Modal",
    styles: None,
    specified_style: Some(StyleDeclaration(style.unwrap_or(FlexStyle()))),
    painter: flex_painter(),
    make_crater: fn(system, styles) {
      @crater_node.Node::new(
        "modal",
        flex_style(
          flex_spec(Vertical, resolved_flex_style(styles.declarations)),
        ),
        children.val.map(node => node.crater(system, styles)),
      )
    },
  })
  overlay_view(anchor, surface, spec, "ModalAnchor")
}

///|
// Bound the surface before layout so explicit/minimum dimensions cannot push
// controls outside the window. Keep smaller application bounds intact.
impl OverlayPolicy for ModalSpec with fn layout(
  _self,
  crater : @crater_node.Node,
  viewport : @foundation.Size,
  _anchor_width : Double,
) -> @crater_node.Node {
  let padding = @css_values.resolve_rect(crater.style.padding, viewport.width)
  let border = @css_values.resolve_rect(crater.style.border, viewport.width)
  let width = (viewport.width -
  padding.horizontal_sum() -
  border.horizontal_sum()).max(0.0)
  let height = (viewport.height - padding.vertical_sum() - border.vertical_sum()).max(
    0.0,
  )
  let children = crater.children.map(child => {
    let max_width = match child.style.max_width {
      Length(value) => value.min(width)
      _ => width
    }
    let max_height = match child.style.max_height {
      Length(value) => value.min(height)
      _ => height
    }
    with_node_style(child, {
      ..child.style,
      width: match child.style.width {
        Length(value) => Length(value.min(max_width))
        value => value
      },
      height: match child.style.height {
        Length(value) => Length(value.min(max_height))
        value => value
      },
      min_width: match child.style.min_width {
        Length(value) => Length(value.min(max_width))
        _ => Length(0.0)
      },
      min_height: match child.style.min_height {
        Length(value) => Length(value.min(max_height))
        _ => Length(0.0)
      },
      max_width: Length(max_width),
      max_height: Length(max_height),
    })
  })
  @crater_node.Node::with_uid_and_measure(
    crater.id,
    crater.uid,
    force_size(
      crater.style,
      Size(width=viewport.width.max(0.0), height=viewport.height.max(0.0)),
    ),
    children,
    crater.measure,
    crater.text,
    src=crater.src,
  )
}

///|
impl OverlayPolicy for ModalSpec with fn origin(_self, _anchor, _size, viewport) {
  viewport.origin
}

///|
impl OverlayPolicy for ModalSpec with fn contains(
  _self,
  surface,
  _trigger,
  point,
) {
  surface.children.any(child => overlay_geometry_contains(child, point))
}

///|
impl OverlayPolicy for ModalSpec with fn behavior(self) {
  OverlayBehavior(
    focus=Contain,
    pointer=BlockOutside,
    escape=if self.close_on_escape { Dismiss } else { Consume },
    outside_press=if self.close_on_backdrop { Dismiss } else { Consume },
  )
}
