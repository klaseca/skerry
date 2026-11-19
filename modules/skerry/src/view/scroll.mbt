///|
/// A bounded viewport containing one scrollable child. Root host sizing or BoxStyle
/// supplies the viewport size. Positive offset moves content toward the start.
/// An optional signal lets the application control the requested offset; actual
/// offsets are clamped per mounted viewport without modifying the signal in paint.
/// Scroll changes request paint and retain cached layout. An overlay scrollbar
/// appears when content overflows; scrollbar=false hides it. Unhandled keyboard
/// navigation scrolls its viewport, and Tab reveals newly focused children.
/// scrollbar_style configures thickness and the separate track/thumb appearance.
/// When omitted, its colors follow the root palette. An explicit style is a
/// complete value and keeps its colors across theme changes.
/// scrollbar_gutter reserves a stable strip for the track, including when the
/// content fits. It reduces layout/child clipping instead of covering content.
/// Padding separates content from the track; the track stays at the outer
/// right/bottom edge and retains the padding at its ends along the scroll axis.
/// Focus outlines may use that padding. Clipping excludes the gutter and keeps
/// fixed padding along an overflowing scroll axis; fitting content can paint
/// decorations within the padding box.
///
/// ```mbt check
/// test {
///   let offset = @reactive.signal(0.0)
///   let system = @text.TextLayoutSystem::from_metrics(
///     TextMetricsProvider(measure=fn(_) {
///       TextMetrics(width=0.0, line_height=10.0, baseline=8.0, caret_positions=[])
///     }),
///   )
///   let root = @runtime.mount(
///     fn() {
///       @view.scroll_view(
///         @view.column([
///           @view.fill_box(30.0),
///           @view.fill_box(30.0),
///           @view.fill_box(30.0),
///         ]),
///         offset~,
///       )
///     },
///     text_layout_system=system,
///   )
///   defer root.dispose()
///   assert_true(
///     root.scroll_at(
///       size=Size(width=60.0, height=50.0),
///       point=Point(x=5.0, y=5.0),
///       delta=Point(x=0.0, y=100.0),
///     ),
///   )
///   assert_eq(offset.get(), 40.0)
/// }
/// ```
pub fn scroll_view(
  child : View,
  axis~ : @foundation.Axis = Vertical,
  offset? : @reactive.Signal[Double],
  style? : @style.BoxStyle,
  disabled? : &@value.BoolValue,
  scrollbar~ : Bool = true,
  scrollbar_style? : @style.ScrollbarStyle,
  scrollbar_gutter~ : Bool = false,
) -> View {
  let style = resolve_style(style)
  let thickness = scrollbar_style.unwrap_or(ScrollbarStyle()).thickness
  let gutter = if scrollbar && scrollbar_gutter && thickness.is_finite() {
    thickness.max(0.0)
  } else {
    0.0
  }
  let offset = offset.unwrap_or(@reactive.signal(0.0))
  let nodes = Ref([child.node])
  view_from_node({
    id: next_ui_node_id(),
    lifecycle: NodeLifecycle(),
    component_name: "ScrollView",
    styles: None,
    metadata: None,
    specified_style: Some(StyleDeclaration(style)),
    geometry: Some({
      translation: Point(x=0.0, y=0.0),
      clip_frame: false,
      scroll: Some({ axis, offset, scrollbar, scrollbar_style, gutter, }),
      theme: None,
      overlay: None,
    }),
    make_crater: fn(text_layout_system, styles) {
      let padding = styles.style.layout.padding.unwrap_or(
        @foundation.Insets::all(0.0),
      )
      let padding = match axis {
        Vertical => { ..padding, right: padding.right + gutter, }
        Horizontal => { ..padding, bottom: padding.bottom + gutter, }
      }
      let viewport = {
        ..flex_style({
          ..flex_spec(axis, FlexStyle().surface(styles.style.padding(padding))),
          spacing: 0.0,
        }),
        overflow_x: Hidden,
        overflow_y: Hidden,
        min_width: Length(0.0),
        min_height: Length(0.0),
      }
      let children = nodes.val.map(node => {
        let crater = node.crater(text_layout_system, styles)
        with_node_style(crater, { ..crater.style, flex_shrink: 0.0, })
      })
      @crater_node.Node::new("scroll-view", viewport, children)
    },
    painter: box_painter(),
    events: ElementEvents(disabled?),
    reactivity: paint_reactivity(fn() { ignore(offset.get()) }),
    children: nodes,
  })
}

///|
/// Route logical deltas to the deepest eligible scroll viewport under the point.
/// At an axis boundary the event bubbles to an enclosing viewport. A partial
/// movement consumes the event; remaining delta is not split between viewports.
pub fn LayoutState::scroll_at(
  self : LayoutState,
  view : View,
  size~ : @foundation.Size,
  point~ : @foundation.Point,
  delta~ : @foundation.Point,
) -> Bool {
  view.with_scope(fn() {
    guard !self.disposed else { return false }
    if (delta.x == 0.0 || delta.x != delta.x) &&
      (delta.y == 0.0 || delta.y != delta.y) {
      return false
    }
    let geometry = self.input_geometry(view, size)
    guard !self.disposed else { return false }
    guard hit_test_tree(view.node, geometry, point, [], for_scroll=true)
      is HitFound(target) else {
      return false
    }
    for depth in target.path.length()>=..0 {
      let path = target.path[:depth].to_owned()
      if node_at_path(view.node, path, 0) is Some(node) && node.is_overlay() {
        break
      }
      if input_node_at_path(view.node, path, 0) is Some(node) &&
        geometry_at_path(geometry, path, 0)
        is Some({ scroll: Some(scroll), clip, .. }) &&
        (
          clip_contains(clip.intersect(scroll.viewport), point) ||
          (
            scroll.scrollbar is Some(bar) &&
            clip_contains(clip.intersect(bar.track), point)
          )
        ) &&
        node.geometry is Some({ scroll: Some(spec), .. }) {
        let amount = match spec.axis {
          Vertical => delta.y
          Horizontal => delta.x
        }
        if amount == amount && amount != 0.0 {
          let next = clamped_scroll_offset(
            scroll.offset + amount,
            scroll.max_offset,
          )
          if next != scroll.offset {
            spec.offset.set(next)
            return true
          }
        }
      }
    }
    false
  })
}
