///|
pub fn LayoutState::paint(
  self : LayoutState,
  view : View,
  size~ : @foundation.Size,
  renderer : &@foundation.SceneRenderer,
  focused_path~ : Array[Int32]?,
  pointer? : @foundation.Point,
  captured_node_id? : Int32,
  keyboard_pressed_node_id? : Int32,
  clear~ : @foundation.Color = @foundation.Color::transparent(),
) -> Unit {
  view.with_applied_values(fn() {
    self.paint_materialized(
      view,
      size~,
      renderer,
      focused_path~,
      pointer?,
      captured_node_id?,
      keyboard_pressed_node_id?,
      clear~,
    )
  })
}

///|
fn LayoutState::paint_materialized(
  self : LayoutState,
  view : View,
  size~ : @foundation.Size,
  renderer : &@foundation.SceneRenderer,
  focused_path~ : Array[Int32]?,
  pointer? : @foundation.Point,
  captured_node_id? : Int32,
  keyboard_pressed_node_id? : Int32,
  clear~ : @foundation.Color,
) -> Unit {
  let layouts = self.layout_count
  let passes = self.layout_pass_count
  let measures = self.text_measure_count()
  let profile_generation = self.profile_generation
  let theme = self.theme
  let overrides = self.theme_overrides.copy()
  // Only this paint's layout time is needed. Do not accumulate elapsed times
  // indefinitely or mix earlier input layout into the paint phase.
  self.layout_ms = 0.0
  let timing = self.profile_clock.map(clock => {
    (clock, @reactive.untracked(clock))
  })
  self.painted = false
  self.painted_focus = None
  self.painted_hover = None
  self.painted_pointer_press = None
  self.painted_key_press = None
  self.painted_geometry = None
  renderer.clear(clear)
  let layout = self.layout(view, size~)
  let geometry = node_geometry(
    view.node,
    layout,
    Point(x=0.0, y=0.0),
    @foundation.Rect::from_size(size),
    StyleContext(theme, overrides),
    false,
    @foundation.Rect::from_size(size),
    @foundation.Rect::from_size(size),
  )
  let context = PaintContext(
    renderer,
    text_layout_system=self.text_layout_system,
    theme~,
  )
  // Resolve hover from exactly the projection that is being drawn, including
  // scrolling, clipping, resizing and structural updates under a stationary mouse.
  let hovered = match pointer {
    Some(point) =>
      match hit_test_tree(view.node, geometry, point, []) {
        HitFound(target) if !target.scrollbar => Some(target.node_id)
        _ => None
      }
    None => None
  }
  let pointer_pressed = if captured_node_id == hovered { hovered } else { None }
  paint_node(
    view.node,
    geometry,
    [],
    focused_path,
    hovered,
    pointer_pressed,
    keyboard_pressed_node_id,
    None,
    context,
  )
  let layers = []
  collect_popup_layers(view.node, geometry, [], layers)
  for layer in layers {
    paint_node(
      layer.node,
      layer.geometry,
      layer.path,
      focused_path,
      hovered,
      pointer_pressed,
      keyboard_pressed_node_id,
      None,
      context,
    )
  }
  // Input during a painter can compute another layout. Only the projection
  // actually drawn by this call may be reported as painted geometry.
  self.painted = self.layout is Some(cached) &&
    physical_equal(cached, layout) &&
    self.size == Some(size) &&
    self.theme == theme &&
    self.theme_overrides == overrides
  if self.painted {
    self.painted_focus = focused_path.map(path => path.copy())
    self.painted_hover = hovered
    self.painted_pointer_press = pointer_pressed
    self.painted_key_press = keyboard_pressed_node_id
    self.painted_geometry = Some(geometry)
  }
  let mut layout_ms = None
  let mut paint_ms = None
  if timing is Some((clock, start)) &&
    profile_generation == self.profile_generation {
    let end = @reactive.untracked(clock)
    if profile_generation == self.profile_generation {
      layout_ms = Some(self.layout_ms)
      paint_ms = Some(end - start - self.layout_ms)
    }
  }
  self.last_paint_stats = Some({
    layout_count: self.layout_count - layouts,
    layout_pass_count: self.layout_pass_count - passes,
    text_measure_count: self.text_measure_count() - measures,
    layout_ms,
    paint_ms,
  })
}

///|
fn paint_node(
  node : UiNode,
  geometry : NodeGeometry,
  path : Array[Int32],
  focused_path : Array[Int32]?,
  hovered : Int32?,
  pointer_pressed : Int32?,
  key_pressed : Int32?,
  parent_clip : @foundation.Rect?,
  context : PaintContext,
) -> Unit {
  guard !geometry.clip.is_empty() else { return }
  let context = {
    ..context,
    theme: geometry.theme,
    font: geometry.font,
    padding: geometry.padding,
    styles: geometry.styles,
  }
  let push_clip = parent_clip != Some(geometry.clip)
  if push_clip {
    context.renderer.push_clip(geometry.clip)
  }
  defer (fn() { if push_clip { context.renderer.pop_clip() } })()
  let disabled = geometry.disabled
  (node.painter.paint)(
    context.with_state(
      node_control_state(
        node.id,
        disabled,
        path_is_focused(path, focused_path),
        hovered,
        pointer_pressed,
        key_pressed,
      ),
    ),
    geometry.frame,
  )
  for index, child_geometry in geometry.children {
    if node.children.val.get(index) is Some(child) &&
      child.id == child_geometry.id {
      if child.is_popup() {
        continue
      }
      let child_path = path.copy()
      child_path.push(index)
      paint_node(
        child,
        child_geometry,
        child_path,
        focused_path,
        hovered,
        pointer_pressed,
        key_pressed,
        Some(geometry.clip),
        context,
      )
    }
  }
  paint_scrollbar(geometry, context)
}

///|
/// Return the last painted hover target without layout or application callbacks.
pub fn LayoutState::hovered_node_id(self : LayoutState) -> Int32? {
  if self.painted {
    self.painted_hover
  } else {
    None
  }
}

///|
fn node_control_state(
  node_id : Int32,
  disabled : Bool,
  focused : Bool,
  hovered : Int32?,
  pointer_pressed : Int32?,
  key_pressed : Int32?,
) -> @foundation.ControlState {
  {
    hovered: !disabled && hovered == Some(node_id),
    pressed: !disabled &&
    (
      pointer_pressed == Some(node_id) ||
      (focused && key_pressed == Some(node_id))
    ),
    focused: !disabled && focused,
    disabled,
  }
}

///|
fn path_is_focused(path : Array[Int32], focused_path : Array[Int32]?) -> Bool {
  match focused_path {
    Some(target) => same_path(path, target)
    None => false
  }
}

///|
fn same_path(left : Array[Int32], right : Array[Int32]) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    for index in 0..<left.length() {
      if left[index] != right[index] {
        return false
      }
    }
    true
  }
}
