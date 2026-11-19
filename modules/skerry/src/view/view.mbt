///|
/// One UI instance. Call a component function again to create another instance.
/// A view can be mounted once and cannot occupy multiple positions in a tree.
pub struct View {
  priv node : UiNode
}

///|
priv struct UiNode {
  id : Int32
  lifecycle : NodeLifecycle
  component_name : String
  styles : NodeStyles?
  metadata : DebugMetadata?
  specified_style : @style.StyleDeclaration?
  geometry : GeometrySpec?
  make_crater : (@text.TextLayoutSystem, StyleContext) -> @crater_node.Node
  painter : Painter
  events : ElementEvents
  reactivity : Reactivity
  // Shared by aliases of this instance; dynamic compositions replace the array.
  children : Ref[Array[UiNode]]
}

///|
fn[T] View::with_scope(self : View, run : () -> T) -> T {
  match self.node.lifecycle.scope {
    Some(scope) => scope.run(run)
    None => run()
  }
}

///|
let next_ui_node_id_ref : Ref[Int32] = Ref(0)

///|
fn next_ui_node_id() -> Int32 {
  let id = next_ui_node_id_ref.val
  next_ui_node_id_ref.val = id + 1
  id
}

///|
priv struct FrameSpec {
  width : Double?
  height : Double?
}

///|
fn view_from_node(node : UiNode) -> View {
  let node = if node.styles is None && node.specified_style is Some(specified) {
    { ..node, styles: Some(NodeStyles(specified)), }
  } else {
    node
  }
  { node, }
}

///|
fn chain_click(previous : (() -> Unit)?, next : (() -> Unit)?) -> (() -> Unit)? {
  match (previous, next) {
    (None, None) => None
    _ =>
      Some(fn() {
        if previous is Some(action) {
          action()
        }
        if next is Some(action) {
          action()
        }
      })
  }
}

///|
fn chain_action(
  previous : (() -> Unit)?,
  next : (() -> Unit)?,
) -> (() -> Unit)? {
  chain_click(previous, next)
}

///|
fn UiNode::crater(
  self : UiNode,
  text_layout_system : @text.TextLayoutSystem,
  styles : StyleContext,
) -> @crater_node.Node {
  if self.is_overlay() {
    return leaf_node(
      "overlay-placeholder",
      absolute_at_origin(empty_style()),
      @foundation.Size::zero(),
    )
  }
  self.crater_content(text_layout_system, styles)
}

///|
fn UiNode::crater_content(
  self : UiNode,
  text_layout_system : @text.TextLayoutSystem,
  styles : StyleContext,
) -> @crater_node.Node {
  let styles = self.style_context(styles)
  let node = (self.make_crater)(text_layout_system, styles)
  apply_layout_properties(node, styles.style)
}

///|
fn UiNode::with_crater(
  self : UiNode,
  make_crater : (@text.TextLayoutSystem, StyleContext) -> @crater_node.Node,
) -> UiNode {
  { ..self, make_crater, }
}

///|
pub fn empty() -> View {
  view_from_node({
    id: next_ui_node_id(),
    lifecycle: NodeLifecycle(),
    component_name: "Empty",
    styles: None,
    metadata: None,
    geometry: None,
    specified_style: Some(StyleDeclaration(@style.BoxStyle())),
    make_crater: fn(_text_layout_system, _styles) {
      leaf_node("empty", empty_style(), @foundation.Size::zero())
    },
    painter: box_painter(),
    events: ElementEvents(),
    reactivity: empty_reactivity(),
    children: Ref([]),
  })
}

///|
pub fn interactive(
  on_click? : () -> Unit,
  on_focus? : () -> Unit,
  on_blur? : () -> Unit,
  on_key_down? : (@foundation.KeyEvent) -> Unit,
  on_text_input? : (String) -> Unit,
  on_pointer_down? : (@foundation.PointerEvent) -> Unit,
  on_pointer_move? : (@foundation.PointerEvent) -> Unit,
  on_pointer_up? : (@foundation.PointerEvent) -> Unit,
  on_pointer_cancel? : () -> Unit,
  child : View,
  disabled? : &@value.BoolValue,
) -> View {
  let previous = child.node.events
  let next_click = on_click.map(scoped_callback)
  let on_click = chain_click(previous.on_click, next_click)
  let on_pointer_cancel = on_pointer_cancel.map(scoped_callback)
  let events = {
    ..previous,
    disabled: match disabled {
      Some(value) => Some(value.to_binding())
      None => previous.disabled
    },
    focusable: true,
    hit_testable: previous.hit_testable ||
    on_click is Some(_) ||
    on_pointer_down is Some(_) ||
    on_pointer_move is Some(_) ||
    on_pointer_up is Some(_),
    on_click,
    on_focus: chain_action(previous.on_focus, on_focus.map(scoped_callback)),
    on_blur: chain_action(previous.on_blur, on_blur.map(scoped_callback)),
    on_key_down: observed_handler(
      keyboard_click_handler(previous.on_key_down, on_click, next_click),
      on_key_down.map(scoped_handler),
    ),
    on_text_input: observed_handler(
      previous.on_text_input,
      on_text_input.map(scoped_handler),
    ),
    on_pointer_down: pointer_handler(
      Some(previous.on_pointer_down),
      on_pointer_down.map(scoped_handler),
      PointerDown,
    ),
    on_pointer_move: pointer_handler(
      Some(previous.on_pointer_move),
      on_pointer_move.map(scoped_handler),
      PointerMove,
    ),
    on_pointer_up: pointer_handler(
      Some(previous.on_pointer_up),
      on_pointer_up.map(scoped_handler),
      PointerUp,
    ),
    on_pointer_cancel: fn() {
      (previous.on_pointer_cancel)()
      if on_pointer_cancel is Some(handler) {
        handler()
      }
    },
  }
  view_from_node({ ..child.node, events, })
}

///|
fn keyboard_click_handler(
  previous : (@foundation.KeyEvent) -> KeyHandling,
  on_click : (() -> Unit)?,
  next_click : (() -> Unit)?,
) -> (@foundation.KeyEvent) -> KeyHandling {
  fn(event) {
    match previous(event) {
      KeyActivated => {
        if next_click is Some(action) {
          action()
        }
        KeyActivated
      }
      KeyHandled => KeyHandled
      KeyIgnored =>
        match event.key {
          KeyEnter | KeySpace =>
            match on_click {
              Some(action) => {
                action()
                KeyActivated
              }
              None => KeyIgnored
            }
          _ => KeyIgnored
        }
    }
  }
}

///|
fn resolve_style(style : @style.BoxStyle?) -> @style.BoxStyle {
  style.unwrap_or(BoxStyle())
}
