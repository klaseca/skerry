///|
pub struct LayoutState {
  priv mut theme : @style.Theme
  priv theme_overrides : Map[Int32, @style.Theme]
  priv source_sheet : @style.StyleSheet
  priv text_layout_system : @text.TextLayoutSystem
  priv mut disposed : Bool
  priv mut root : @crater_node.Node?
  priv mut layout : @crater_core.Layout?
  priv mut normal_layout : @crater_core.Layout?
  priv mut size : @foundation.Size?
  priv mut measurements : Map[Int32, MeasuredLayoutNode]
  priv mut style_tree : StyleTree?
  priv mut generation : Int32
  priv mut layout_count : Int32
  priv mut layout_pass_count : Int32
  priv mut profile_clock : (() -> Double)?
  priv mut profile_generation : Int32
  priv mut layout_depth : Int32
  priv mut layout_ms : Double
  priv mut last_paint_stats : @diagnostics.PaintStats?
  priv mut painted : Bool
  priv mut painted_focus : Array[Int32]?
  priv mut painted_hover : Int32?
  priv mut painted_pointer_press : Int32?
  priv mut painted_key_press : Int32?
  priv mut painted_geometry : NodeGeometry?
  priv mut scrollbar_press : ScrollbarPress?
}

///|
priv struct MeasuredLayoutNode {
  measure : @crater_core.MeasureFunc
  height : Ref[Double]
}

///|
pub fn LayoutState::LayoutState(
  text_layout_system~ : @text.TextLayoutSystem,
  theme~ : @style.Theme = Theme(),
) -> LayoutState {
  {
    theme,
    theme_overrides: {},
    source_sheet: @style.StyleSheet(theme.styles),
    text_layout_system: text_layout_system.new_session(),
    disposed: false,
    root: None,
    layout: None,
    normal_layout: None,
    size: None,
    measurements: {},
    style_tree: None,
    generation: 0,
    layout_count: 0,
    layout_pass_count: 0,
    profile_clock: None,
    profile_generation: 0,
    layout_depth: 0,
    layout_ms: 0.0,
    last_paint_stats: None,
    painted: false,
    painted_focus: None,
    painted_hover: None,
    painted_pointer_press: None,
    painted_key_press: None,
    painted_geometry: None,
    scrollbar_press: None,
  }
}

///|
pub fn LayoutState::invalidate(self : LayoutState) -> Unit {
  self.generation += 1
  self.painted = false
  self.painted_focus = None
  self.painted_hover = None
  self.painted_pointer_press = None
  self.painted_key_press = None
  self.painted_geometry = None
  self.root = None
  self.layout = None
  self.normal_layout = None
  self.size = None
  self.measurements = {}
  self.style_tree = None
}

///|
/// Invalidate a mounted node's layout. Floating surfaces do not contribute to
/// normal layout, so changes inside them retain the background allocation and
/// measurements. Other changes use full invalidation, including missing nodes.
/// Hosts may use this with mount_reactivity's on_layout_change callback.
pub fn LayoutState::invalidate_node(
  self : LayoutState,
  view : View,
  node_id : Int32,
) -> Unit {
  if view.path_for_node_id(node_id) is Some(path) {
    for depth in path.length()>=..0 {
      if node_at_path(view.node, path[:depth].to_owned(), 0) is Some(node) &&
        node.is_overlay() {
        self.generation += 1
        self.painted = false
        self.painted_focus = None
        self.painted_hover = None
        self.painted_pointer_press = None
        self.painted_key_press = None
        self.painted_geometry = None
        self.layout = None
        self.style_tree = None
        return
      }
    }
  }
  self.invalidate()
}

///|
/// Whether the layout cache needs computing, independently of paint state.
pub fn LayoutState::needs_layout(self : LayoutState) -> Bool {
  !self.disposed && self.layout is None
}

///|
/// Number of layout computations, including those requested by hit testing.
/// Cache reuse does not increase this counter.
pub fn LayoutState::layout_count(self : LayoutState) -> Int32 {
  self.layout_count
}

///|
pub fn View::layout(
  self : View,
  size~ : @foundation.Size,
  text_layout_system~ : @text.TextLayoutSystem,
) -> @crater_core.Layout {
  let state = LayoutState(text_layout_system~)
  defer state.dispose()
  state.layout(self, size~)
}

///|
pub fn LayoutState::layout(
  self : LayoutState,
  view : View,
  size~ : @foundation.Size,
) -> @crater_core.Layout {
  view.with_applied_values(fn() { self.layout_materialized(view, size~) })
}

///|
fn LayoutState::layout_materialized(
  self : LayoutState,
  view : View,
  size~ : @foundation.Size,
) -> @crater_core.Layout {
  // Cache reuse performs no layout work and does not read the profiling clock.
  if self.size == Some(size) && self.layout is Some(layout) {
    return layout
  }
  let profile_generation = self.profile_generation
  let timing = if self.layout_depth == 0 {
    self.profile_clock.map(clock => (clock, @reactive.untracked(clock)))
  } else {
    None
  }
  self.layout_depth += 1
  defer (fn() {
    self.layout_depth -= 1
    if timing is Some((clock, start)) &&
      profile_generation == self.profile_generation {
      let end = @reactive.untracked(clock)
      if profile_generation == self.profile_generation {
        self.layout_ms += end - start
      }
    }
  })()
  let generation = self.generation
  self.painted = false
  let (root, measurements) = match self.root {
    Some(root) =>
      (with_node_style(root, force_size(root.style, size)), self.measurements)
    None => {
      let crater = view.node.crater(
        self.text_layout_system,
        StyleContext(self.theme, self.theme_overrides.copy()),
      )
      let root = with_node_style(crater, force_size(crater.style, size))
      let measurements : Map[Int32, MeasuredLayoutNode] = Map([])
      let root = collect_measurements(root, measurements)
      (root, measurements)
    }
  }
  self.layout_count += 1
  let normal_layout = if self.size == Some(size) &&
    self.normal_layout is Some(layout) {
    layout
  } else {
    self.compute_measured_layout(root, size, measurements)
  }
  let layout = self.layout_overlays(
    view.node,
    normal_layout,
    StyleContext(self.theme, self.theme_overrides.copy()),
    size,
  )
  // A measurement callback can invalidate the root. Keep that invalidation;
  // this computation must not put its stale nodes back into the cache.
  if generation == self.generation && !self.disposed {
    self.root = Some(root)
    self.layout = Some(layout)
    self.normal_layout = Some(normal_layout)
    self.size = Some(size)
    self.measurements = measurements
    self.style_tree = Some(view.node.style_tree())
  }
  layout
}

///|
fn collect_measurements(
  node : @crater_node.Node,
  measurements : Map[Int32, MeasuredLayoutNode],
  in_row~ : Bool = false,
) -> @crater_node.Node {
  let row_children = node.style.display is Flex &&
    (
      node.style.flex_direction is Row ||
      node.style.flex_direction is RowReverse
    )
  let children = node.children.map(child => {
    collect_measurements(child, measurements, in_row=row_children)
  })
  let mut style = node.style
  let mut measure = node.measure
  if style.height is Auto && measure is Some(original) {
    let intrinsic = (original.func)(0.0, 0.0)
    let height = Ref(intrinsic.max_height)
    // Crater approximates wrapping when intrinsic widths form a range.
    // Resolve content height here and provide a fixed intrinsic size while
    // keeping height auto, so row cross-axis stretch still applies.
    let preferred_width = intrinsic.max_width
    measure = Some({
      func: fn(_, _) {
        {
          min_width: preferred_width,
          max_width: preferred_width,
          min_height: height.val,
          max_height: height.val,
        }
      },
    })
    let padding = @css_values.resolve_rect(style.padding, 0.0)
    let border = @css_values.resolve_rect(style.border, 0.0)
    let minimum_width = intrinsic.min_width +
      padding.horizontal_sum() +
      border.horizontal_sum()
    // Automatic min-width is a content floor only on the row main axis.
    // A specified width can be smaller than the content's intrinsic minimum.
    if in_row && style.min_width is Auto {
      let minimum_width = match style.width {
        Length(width) => minimum_width.min(width)
        _ => minimum_width
      }
      style = { ..style, min_width: Length(minimum_width), }
    }
    measurements[node.uid] = { measure: original, height, }
  }
  @crater_node.Node::with_uid_and_measure(
    node.id,
    node.uid,
    style,
    children,
    measure,
    node.text,
    src=node.src,
  )
}

///|
fn LayoutState::compute_measured_layout(
  self : LayoutState,
  root : @crater_node.Node,
  size : @foundation.Size,
  measurements : Map[Int32, MeasuredLayoutNode],
) -> @crater_core.Layout {
  let mut layout = self.compute_layout_pass(root, size)
  if measurements.is_empty() {
    return layout
  }
  // Reflow can change ancestor geometry. Allow each measured node to resolve
  // once more, with a finite bound even for an inconsistent metrics provider.
  for _ in 0..<=measurements.length() {
    if !update_measurements(root, layout, measurements) {
      break
    }
    layout = self.compute_layout_pass(root, size)
  }
  layout
}

///|
fn update_measurements(
  node : @crater_node.Node,
  layout : @crater_core.Layout,
  measurements : Map[Int32, MeasuredLayoutNode],
) -> Bool {
  let mut changed = false
  if measurements.get(node.uid) is Some(measured) {
    let content_width = (layout.width -
    layout.padding.horizontal_sum() -
    layout.border.horizontal_sum()).max(0.0)
    let height = (measured.measure.func)(content_width, 0.0).max_height
    if height != measured.height.val {
      measured.height.val = height
      changed = true
    }
  }
  for index, child_layout in layout.children {
    if node.children.get(index) is Some(child) {
      changed = update_measurements(child, child_layout, measurements) ||
        changed
    }
  }
  changed
}

///|
fn LayoutState::compute_layout_pass(
  self : LayoutState,
  root : @crater_node.Node,
  size : @foundation.Size,
) -> @crater_core.Layout {
  // Crater 0.19.1's LayoutTree owns callbacks that capture the tree itself.
  // Use its immutable-node entry point so invalidation releases the old nodes.
  // The global intrinsic/resolved caches belong to this computation: our nodes
  // and measured heights can change between passes. Keep the finished layout in
  // LayoutState instead of retaining Crater's intermediate caches across passes.
  @crater_layout.reset_intrinsic_cache()
  defer (fn() {
    @crater_layout.reset_intrinsic_cache()
    @crater_block.clear_block_intrinsic_caches()
  })()
  self.layout_pass_count += 1
  @crater_layout.compute_layout_in_context(root, {
    available_width: size.width,
    available_height: Some(size.height),
    sizing_mode: Definite,
    viewport_width: size.width,
    viewport_height: size.height,
    stretch_width: false,
    stretch_height: false,
  })
}

///|
fn layout_frame(
  layout : @crater_core.Layout,
  parent_x : Double,
  parent_y : Double,
) -> @foundation.Rect {
  Rect(
    x=parent_x + layout.x,
    y=parent_y + layout.y,
    width=layout.width,
    height=layout.height,
  )
}

///|
fn child_parent_origin(
  layout : @crater_core.Layout,
  frame : @foundation.Rect,
) -> @foundation.Point {
  Point(
    x=frame.origin.x + layout.border.left,
    y=frame.origin.y + layout.border.top,
  )
}

///|
/// The rule source used by a custom host's View.mount_reactivity. UiRoot wires
/// this automatically; root-local and scoped context providers take precedence.
pub fn LayoutState::style_sheet(self : LayoutState) -> @style.StyleSheet {
  self.source_sheet
}
