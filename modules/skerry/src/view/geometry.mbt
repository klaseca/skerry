///|
priv struct GeometrySpec {
  translation : @foundation.Point
  clip_frame : Bool
  scroll : ScrollSpec?
  theme : ThemeSpec?
  popup : PopupSpec?
}

///|
priv struct ScrollSpec {
  axis : @foundation.Axis
  offset : @reactive.Signal[Double]
  scrollbar : Bool
  scrollbar_style : @style.ScrollbarStyle?
  gutter : Double
}

///|
// Geometry and concrete style values are frozen without live nodes or part
// selectors. Paint, hit testing and snapshots use this same representation.
#derive(Eq)
priv struct NodeGeometry {
  id : Int32
  frame : @foundation.Rect
  content : @foundation.Rect
  padding : @foundation.Insets
  border : @foundation.Insets
  clip : @foundation.Rect
  scroll : @diagnostics.ScrollSnapshot?
  image : @diagnostics.ImageSnapshot?
  theme : @style.Theme
  font : @foundation.FontSpec
  styles : ReadOnlyArray[@style.StyleDeclaration]
  // Effective value, including ancestors, frozen for this projection.
  disabled : Bool
  children : Array[NodeGeometry]
}

///|
/// Move paint/input geometry without changing layout allocation or node identity.
/// The translation is inherited by descendants and does not change scroll extent.
/// Calling this again replaces the previous translation on this node.
pub fn View::translated(self : View, offset : @foundation.Point) -> View {
  let previous = self.node.geometry.unwrap_or({
    translation: Point(x=0.0, y=0.0),
    clip_frame: false,
    scroll: None,
    theme: None,
    popup: None,
  })
  view_from_node({
    ..self.node,
    geometry: Some({ ..previous, translation: offset, }),
  })
}

///|
/// Clip this node and its descendants to its translated outer frame. Layout and
/// identity are preserved; input uses the same effective ancestor clip as paint.
pub fn View::clip(self : View) -> View {
  let previous = self.node.geometry.unwrap_or({
    translation: Point(x=0.0, y=0.0),
    clip_frame: false,
    scroll: None,
    theme: None,
    popup: None,
  })
  view_from_node({
    ..self.node,
    geometry: Some({ ..previous, clip_frame: true, }),
  })
}

///|
fn clip_contains(clip : @foundation.Rect, point : @foundation.Point) -> Bool {
  // Clip edges are half-open, including zero-area intersections. This agrees
  // with the renderer viewport instead of targeting the next row at its edge.
  !clip.is_empty() &&
  point.x >= clip.origin.x &&
  point.y >= clip.origin.y &&
  point.x < clip.origin.x + clip.size.width &&
  point.y < clip.origin.y + clip.size.height
}

///|
fn clamped_scroll_offset(requested : Double, maximum : Double) -> Double {
  if requested != requested || requested < 0.0 {
    0.0
  } else {
    requested.min(maximum.max(0.0))
  }
}

///|
// Visible layout overflow contributes to scroll extent. A nested viewport or
// explicitly clipped node contains its overflow; translations affect painting
// and input but keep the allocated scroll extent unchanged.
fn node_layout_extent(
  node : UiNode,
  layout : @crater_core.Layout,
) -> @foundation.Size {
  let mut width = layout.width.max(0.0)
  let mut height = layout.height.max(0.0)
  if node.geometry is Some(spec) && (spec.clip_frame || spec.scroll is Some(_)) {
    return Size(width~, height~)
  }
  for index, child_layout in layout.children {
    if node.children.val.get(index) is Some(child) {
      if child.is_popup() {
        continue
      }
      let extent = node_layout_extent(child, child_layout)
      width = width.max(
        layout.border.left +
        child_layout.x +
        extent.width +
        layout.padding.right +
        layout.border.right,
      )
      height = height.max(
        layout.border.top +
        child_layout.y +
        extent.height +
        layout.padding.bottom +
        layout.border.bottom,
      )
    }
  }
  Size(width~, height~)
}

///|
fn node_geometry(
  node : UiNode,
  layout : @crater_core.Layout,
  parent : @foundation.Point,
  ancestor_clip : @foundation.Rect,
  styles : StyleContext,
  ancestor_disabled : Bool,
  viewport : @foundation.Rect,
  anchor : @foundation.Rect,
) -> NodeGeometry {
  let disabled = ancestor_disabled || node.is_disabled()
  let styles = node.style_context(styles)
  let theme = styles.theme
  let base = layout_frame(layout, parent.x, parent.y)
  let base = match node.geometry {
    Some({ popup: Some(spec), .. }) =>
      { ..base, origin: popup_origin(spec, anchor, base.size, viewport), }
    _ => base
  }
  let translation = node.geometry
    .map(spec => spec.translation)
    .unwrap_or(Point(x=0.0, y=0.0))
  let frame : @foundation.Rect = {
    ..base,
    origin: Point(
      x=base.origin.x + translation.x,
      y=base.origin.y + translation.y,
    ),
  }
  let padding : @foundation.Insets = {
    top: layout.padding.top,
    right: layout.padding.right,
    bottom: layout.padding.bottom,
    left: layout.padding.left,
  }
  let border : @foundation.Insets = {
    top: layout.border.top,
    right: layout.border.right,
    bottom: layout.border.bottom,
    left: layout.border.left,
  }
  let content = frame.inset(border).inset(padding)
  let ancestor_clip = if node.is_popup() { viewport } else { ancestor_clip }
  let clip = if node.is_popup() && disabled {
    @foundation.Rect(x=frame.origin.x, y=frame.origin.y, width=0.0, height=0.0)
  } else if node.geometry is Some({ clip_frame: true, .. }) {
    ancestor_clip.intersect(frame)
  } else {
    ancestor_clip
  }
  let scroll_spec = match node.geometry {
    Some(spec) => spec.scroll
    None => None
  }
  let scroll : @diagnostics.ScrollSnapshot? = scroll_spec.map(spec => {
    // Layout padding includes a stable gutter; the scrollbar's viewport also
    // includes that gutter, while content and child clipping exclude it.
    let viewport_padding = match spec.axis {
      Vertical => { ..padding, right: (padding.right - spec.gutter).max(0.0), }
      Horizontal =>
        { ..padding, bottom: (padding.bottom - spec.gutter).max(0.0), }
    }
    let scroll_viewport = frame.inset(border).inset(viewport_padding)
    let content_size = match
      (node.children.val.get(0), layout.children.get(0)) {
      (Some(child), Some(child_layout)) =>
        node_layout_extent(child, child_layout)
      _ => @foundation.Size::zero()
    }
    let maximum = match spec.axis {
      Vertical => (content_size.height - content.size.height).max(0.0)
      Horizontal => (content_size.width - content.size.width).max(0.0)
    }
    let requested = @reactive.untracked(fn() { spec.offset.get() })
    let offset = clamped_scroll_offset(requested, maximum)
    {
      axis: spec.axis,
      viewport: scroll_viewport,
      content_size,
      offset,
      max_offset: maximum,
      scrollbar: if spec.scrollbar {
        scrollbar_geometry(
          spec.axis,
          scroll_viewport,
          content_size,
          offset,
          maximum,
          spec.scrollbar_style.unwrap_or(ScrollbarStyle()),
          theme~,
        )
      } else {
        None
      },
    }
  })
  let origin = child_parent_origin(layout, frame)
  let origin : @foundation.Point = match scroll {
    Some({ axis: Vertical, offset, .. }) =>
      Point(x=origin.x, y=origin.y - offset)
    Some({ axis: Horizontal, offset, .. }) =>
      Point(x=origin.x - offset, y=origin.y)
    None => origin
  }
  let child_clip = if scroll is Some(_) {
    clip.intersect(content)
  } else {
    clip
  }
  let children = []
  for index, child_layout in layout.children {
    if node.children.val.get(index) is Some(child) {
      children.push(
        node_geometry(
          child,
          child_layout,
          origin,
          child_clip,
          styles,
          disabled,
          viewport,
          children.get(0).map(first => first.frame).unwrap_or(frame),
        ),
      )
    }
  }
  {
    id: node.id,
    frame,
    content,
    padding,
    border,
    clip,
    scroll,
    image: node.image_snapshot(content, styles.declarations),
    theme,
    font: styles.resolved_font(),
    styles: styles.declarations,
    disabled,
    children,
  }
}

///|
fn LayoutState::input_geometry(
  self : LayoutState,
  view : View,
  size : @foundation.Size,
) -> NodeGeometry {
  let layout = self.layout(view, size~)
  let geometry = node_geometry(
    view.node,
    layout,
    Point(x=0.0, y=0.0),
    @foundation.Rect::from_size(size),
    StyleContext(self.theme, self.theme_overrides),
    false,
    @foundation.Rect::from_size(size),
    @foundation.Rect::from_size(size),
  )
  if self.painted && self.painted_geometry != Some(geometry) {
    self.painted = false
    self.painted_geometry = None
  }
  geometry
}

///|
fn geometry_at_path(
  geometry : NodeGeometry,
  path : Array[Int32],
  depth : Int32,
) -> NodeGeometry? {
  if depth == path.length() {
    Some(geometry)
  } else {
    match geometry.children.get(path[depth]) {
      Some(child) => geometry_at_path(child, path, depth + 1)
      None => None
    }
  }
}
