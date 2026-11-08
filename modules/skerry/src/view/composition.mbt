///|
priv struct FlexSpec {
  axis : @foundation.Axis
  spacing : Double
  padding : @foundation.Insets
  frame : FrameSpec
  justify_content : @style.JustifyContent?
  align_items : @style.AlignItems?
}

///|
fn flex_spec(axis : @foundation.Axis, style : FlexStyle) -> FlexSpec {
  {
    axis,
    justify_content: style.justify_content,
    align_items: style.align_items,
    spacing: style.spacing.unwrap_or(0.0),
    padding: style.surface.layout.padding.unwrap_or(
      @foundation.Insets::all(0.0),
    ),
    frame: {
      width: style.surface.layout.width,
      height: style.surface.layout.height,
    },
  }
}

///|
pub fn row(
  style? : FlexStyle,
  children : Array[View],
  disabled? : &@value.BoolValue,
) -> View {
  let style = style.unwrap_or(FlexStyle())
  flex_view(Horizontal, children, style, disabled?)
}

///|
pub fn column(
  style? : FlexStyle,
  children : Array[View],
  disabled? : &@value.BoolValue,
) -> View {
  let style = style.unwrap_or(FlexStyle())
  flex_view(Vertical, children, style, disabled?)
}

///|
fn flex_view(
  axis : @foundation.Axis,
  children : Array[View],
  style : FlexStyle,
  disabled? : &@value.BoolValue,
) -> View {
  let nodes = children.map(child => child.node)
  view_from_node({
    id: next_ui_node_id(),
    lifecycle: NodeLifecycle(),
    component_name: match axis {
      Horizontal => "Row"
      Vertical => "Column"
    },
    styles: None,
    metadata: None,
    geometry: None,
    specified_style: Some(StyleDeclaration(style)),
    make_crater: fn(text_layout_system, styles) {
      @crater_node.Node::new(
        "flex",
        flex_style(flex_spec(axis, resolved_flex_style(styles.declarations))),
        nodes.map(node => node.crater(text_layout_system, styles)),
      )
    },
    painter: flex_painter(),
    events: ElementEvents(disabled?),
    reactivity: empty_reactivity(),
    children: Ref(nodes),
  })
}

///|
/// Keep the current branch while condition's Bool is unchanged. A real branch
/// transition disposes the old instance and calls render to create a fresh one.
pub fn show(
  condition : () -> Bool,
  render : () -> View,
  disabled? : &@value.BoolValue,
) -> View {
  let state = {
    let scope = @reactive.Scope::new()
    let visible = scope.run(condition)
    let branch_scope = scope.child()
    let children = Ref(
      branch_scope.run(fn() { if visible { [render().node] } else { [] } }),
    )
    ShowState::{ scope, branch_scope, visible, children, }
  }
  let node = {
    id: next_ui_node_id(),
    lifecycle: NodeLifecycle(),
    component_name: "Show",
    styles: None,
    metadata: None,
    geometry: None,
    specified_style: Some(StyleDeclaration(FlexStyle())),
    make_crater: fn(text_layout_system, styles) {
      @crater_node.Node::new(
        "dynamic-fragment",
        flex_style(
          flex_spec(Vertical, resolved_flex_style(styles.declarations)),
        ),
        state.children.val.map(node => node.crater(text_layout_system, styles)),
      )
    },
    painter: flex_painter(),
    events: ElementEvents(disabled?),
    reactivity: dynamic_children_reactivity(state, condition, render),
    children: state.children,
  }
  view_from_node(node)
}

///|
/// Render each keyed entry once, retaining its view when the key is reused.
/// Entries, scopes and structural updates belong to this View instance.
/// `render` receives a reactive getter for the entry's current value. Read it in
/// `text(bind(...))`, other reactive views, or callbacks to observe subsequent updates.
/// Prefer unique keys. Repeated keys are paired with previous entries in their
/// occurrence order; their state follows the occurrence rather than the payload.
/// Optional key_label formats diagnostic text once per new entry, untracked in
/// that entry's scope. Labels do not participate in reconciliation; reorder and
/// payload updates retain them. Snapshots never call the formatter.
pub fn[T, K : Eq] for_each(
  items : () -> Array[T],
  key : (T) -> K,
  render : (() -> T) -> View,
  key_label? : (K) -> String,
  disabled? : &@value.BoolValue,
) -> View {
  let state = {
    let scope = @reactive.Scope::new()
    let entries = scope.run(fn() {
      items().map(item => keyed_child(item, key(item), render, key_label?))
    })
    KeyedChildrenState::{
      scope,
      entries,
      children: Ref(entries.map(entry => entry.node)),
    }
  }
  let node = {
    id: next_ui_node_id(),
    lifecycle: NodeLifecycle(),
    component_name: "ForEach",
    styles: None,
    metadata: None,
    geometry: None,
    specified_style: Some(StyleDeclaration(FlexStyle())),
    make_crater: fn(text_layout_system, styles) {
      @crater_node.Node::new(
        "keyed-fragment",
        flex_style(
          flex_spec(Vertical, resolved_flex_style(styles.declarations)),
        ),
        state.children.val.map(node => node.crater(text_layout_system, styles)),
      )
    },
    painter: flex_painter(),
    events: ElementEvents(disabled?),
    reactivity: keyed_children_reactivity(state, items, key, render, key_label),
    children: state.children,
  }
  view_from_node(node)
}

///|
pub fn stack(children : Array[View], disabled? : &@value.BoolValue) -> View {
  stack_view(children, "Stack", disabled?)
}

///|
fn stack_view(
  children : Array[View],
  component_name : String,
  disabled? : &@value.BoolValue,
) -> View {
  let nodes = children.map(child => {
    child.node.with_crater(fn(text_layout_system, styles) {
      let crater = child.node.crater(text_layout_system, styles)
      with_node_style(crater, absolute_at_origin(crater.style))
    })
  })
  view_from_node({
    id: next_ui_node_id(),
    lifecycle: NodeLifecycle(),
    component_name,
    styles: None,
    metadata: None,
    geometry: None,
    specified_style: Some(StyleDeclaration(@style.BoxStyle())),
    make_crater: fn(text_layout_system, styles) {
      @crater_node.Node::new(
        "stack",
        stack_style(),
        nodes.map(node => node.crater(text_layout_system, styles)),
      )
    },
    painter: box_painter(),
    events: ElementEvents(disabled?),
    reactivity: empty_reactivity(),
    children: Ref(nodes),
  })
}

///|
pub fn fragment(children : Array[View], disabled? : &@value.BoolValue) -> View {
  stack_view(children, "Fragment", disabled?)
}

///|
fn flex_painter() -> Painter {
  let painter = box_painter()
  let resolve = painter.computed_style.unwrap()
  painter.with_computed_style(fn(context) {
    let style = resolve(context)
    {
      ..style,
      spacing: Some(resolved_flex_style(context.styles).spacing.unwrap_or(0.0)),
    }
  })
}
