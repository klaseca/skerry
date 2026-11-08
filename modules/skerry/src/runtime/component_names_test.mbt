///|
test "component names do not select layout diagnostics or theme styles" {
  let selected = @reactive.signal(1)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.row([]).component("Card").debug(name="summary"),
        @view.stack([]).component("Row"),
        @view.box().component("RadioGroup"),
        @view.show(() => false, @view.empty).component("Status"),
        @view.for_each(() => [], fn(item : Int32) { item }, fn(_) {
          @view.empty()
        }).component("Results"),
        @controls.radio_group(selected, [1], label=fn(_) { "One" }).component(
          "Preferences",
        ),
      ])
    },
    theme=Theme(styles=@style.Styles().add(@view.FlexStyle().spacing(7.0))),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let before = root.snapshot().unwrap()
  let nodes = before.tree.nodes
  assert_eq(nodes[1].component_name, "Row")
  assert_eq(nodes[1].debug_name, None)
  assert_eq(nodes[1].components[0].name, "Card")
  assert_eq(nodes[1].components[0].debug_name, Some("summary"))
  assert_eq(nodes[2].component_name, "Stack")
  assert_eq(nodes[2].components[0].name, "Row")
  assert_eq(nodes[3].component_name, "Box")
  assert_eq(nodes[3].components[0].name, "RadioGroup")
  assert_eq(nodes[1].style_type, nodes[0].style_type)
  for index in [0, 1, 4, 5, 6] {
    assert_eq(nodes[index].computed_style.unwrap().spacing, Some(7.0))
  }
  for index in [2, 3, 7] {
    assert_eq(nodes[index].computed_style.unwrap().spacing, None)
  }
  assert_eq(nodes[6].component_name, "Column")
  assert_eq(nodes[6].components.map(component => component.name), [
    "Preferences", "RadioGroup",
  ])
  assert_eq(root.snapshot(), Some(before))
  assert_false(root.needs_frame())
}

///|
test "component boundaries preserve the fitted indicators controls paint" {
  let frame = @style.BoxStyle()
    .width(28.0)
    .height(26.0)
    .shrink(0.0)
    .padding(@foundation.Insets::all(7.0))
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.checkbox(style=@controls.CheckboxStyle().frame(frame)).component(
          "Column",
        ),
        @controls.radio(style=@controls.RadioStyle().frame(frame)).component(
          "CustomChoice",
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = ScrollRecorder()
  root.paint(renderer, size=Size(width=200.0, height=100.0))
  let snapshot = root.snapshot().unwrap()
  assert_eq(renderer.fills.length(), 2)
  for index in 1..<3 {
    let node = snapshot.tree.nodes[index]
    let computed = node.computed_style.unwrap()
    assert_eq(node.frame.size, Size(width=28.0, height=26.0))
    assert_eq(node.content.size, Size(width=14.0, height=12.0))
    assert_eq(computed.indicator_size, Some(node.content.size))
    assert_eq(renderer.fills[index - 1].0.size, node.content.size)
    assert_eq(renderer.fills[index - 1].0.origin, node.content.origin)
    assert_eq(computed.spacing, None)
  }
  assert_eq(snapshot.tree.nodes[1].component_name, "Checkbox")
  assert_eq(snapshot.tree.nodes[1].components[0].name, "Column")
  assert_eq(snapshot.tree.nodes[2].component_name, "Radio")
  assert_eq(snapshot.tree.nodes[2].components[0].name, "CustomChoice")
}

///|
test "nested components preserve the primitive and each level's diagnostic values" {
  let body_source = @diagnostics.SourceLocation(file="body.mbt", line=4)
  let card_source = @diagnostics.SourceLocation(file="card.mbt", line=8)
  let profile_source = @diagnostics.SourceLocation(file="profile.mbt", line=12)
  let body = @view.column([@view.text("Title")]).debug(
    name="body",
    source=body_source,
  )
  let card = body.component("Card").debug(name="card", source=card_source)
  let profile = card
    .component("ProfileCard")
    .debug(name="old")
    .debug(name="summary")
    .debug(source=profile_source)
    .debug()
  let decorated = @view.interactive(profile)
  let root = @runtime.mount(
    fn() { @view.stack([decorated]) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let snapshot = root.snapshot().unwrap()
  let nodes = snapshot.tree.nodes
  assert_eq(nodes.length(), 3)
  let node = nodes[1]
  assert_eq(node.component_name, "Column")
  assert_eq(node.debug_name, Some("body"))
  assert_eq(node.source, Some(body_source))
  assert_eq(Some(node.id), body.node_id_at_path([]))
  assert_eq(Some(node.id), card.node_id_at_path([]))
  assert_eq(Some(node.id), profile.node_id_at_path([]))
  assert_eq(node.parent_id, Some(nodes[0].id))
  assert_eq(node.children, ReadOnlyArray::from_array([nodes[2].id]))
  assert_true(node.focusable)
  let components = node.components
  assert_eq(components.length(), 2)
  assert_eq(components[0].name, "ProfileCard")
  assert_eq(components[0].debug_name, Some("summary"))
  assert_eq(components[0].source, Some(profile_source))
  assert_eq(components[1].name, "Card")
  assert_eq(components[1].debug_name, Some("card"))
  assert_eq(components[1].source, Some(card_source))
  assert_true(components[0].id != components[1].id)
  let projection : Array[String] = components
    .iter()
    .map(component => component.name)
    .collect()
  projection.push(node.component_name)
  assert_eq(projection, ["ProfileCard", "Card", "Column"])
  assert_eq(root.snapshot(), Some(snapshot))
  assert_false(root.needs_frame())
}

///|
test "equal component names still identify distinct instances and nested boundaries" {
  let first = @view.column([]).component("Card").component("Card")
  let second = @view.column([]).component("Card")
  let root = @runtime.mount(
    fn() { @view.row([first, second]) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes.length(), 3)
  assert_true(nodes[0].components.is_empty())
  assert_eq(nodes[1].components.length(), 2)
  assert_eq(nodes[2].components.length(), 1)
  let ids = [
    nodes[1].components[0].id,
    nodes[1].components[1].id,
    nodes[2].components[0].id,
  ]
  assert_true(ids[0] != ids[1] && ids[0] != ids[2] && ids[1] != ids[2])
}
