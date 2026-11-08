///|
#derive(Eq)
struct MetadataKey {
  id : Int32
}

///|
test "debug decorators merge values while preserving identity geometry and aliases" {
  let source = @diagnostics.SourceLocation(
    file="src/form.mbt",
    line=12,
    column=4,
  )
  let replacement = @diagnostics.SourceLocation(file="src/actions.mbt", line=30)
  let plain = @controls.button("Save")
  let tagged = plain.debug(name="old", source~)
  let decorated = @view.interactive(@view.interactive(tagged))
    .debug(name="save")
    .debug(source=replacement)
    .debug()
  assert_eq(decorated.node_id_at_path([]), plain.node_id_at_path([]))
  let plain_root = @runtime.mount(
    fn() { @view.stack([@controls.button("Save")]) },
    text_layout_system=test_text_layout_system(),
  )
  defer plain_root.dispose()
  let tagged_root = @runtime.mount(
    fn() { @view.stack([decorated]) },
    text_layout_system=test_text_layout_system(),
  )
  defer tagged_root.dispose()
  snapshot_paint(plain_root)
  snapshot_paint(tagged_root)
  let original = plain_root.snapshot().unwrap().tree.nodes[1]
  let metadata = tagged_root.snapshot().unwrap().tree.nodes[1]
  assert_eq(Some(metadata.id), plain.node_id_at_path([]))
  assert_eq(metadata.frame, original.frame)
  assert_eq(metadata.component_name, "Button")
  assert_eq(metadata.debug_name, Some("save"))
  assert_eq(metadata.source, Some(replacement))
  assert_eq(metadata.source.unwrap().column, None)
  assert_eq(metadata.key_label, None)
  assert_eq(original.debug_name, None)
  assert_eq(original.source, None)
  assert_eq(original.key_label, None)
  assert_true(metadata.focusable)
  let initial = @runtime.mount(
    fn() { @controls.button("Save").debug(name="old", source~) },
    text_layout_system=test_text_layout_system(),
  )
  defer initial.dispose()
  snapshot_paint(initial)
  let first = initial.snapshot().unwrap().tree.nodes[0]
  assert_eq(first.debug_name, Some("old"))
  assert_eq(first.source, Some(source))
  assert_eq(first.source.unwrap().column, Some(4))
}

///|
test "metadata on logical regions and primitive nodes survives structural decorators" {
  let visible = @reactive.signal(true)
  let cleanup = Ref(0)
  let source = @diagnostics.SourceLocation(file="src/status.mbt", line=8)
  let root = @runtime.mount(
    fn() {
      @view.fragment([
        @view.interactive(
          @view.show(fn() { visible.get() }, fn() {
            @reactive.on_cleanup(fn() { cleanup.val += 1 })
            @view.box().component("Indicator").debug(name="indicator", source~)
          })
          .component("Status")
          .debug(name="status", source~),
        ),
      ])
      .component("Screen")
      .debug(name="screen")
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let before = root.snapshot().unwrap()
  assert_eq(before.tree.nodes[0].component_name, "Fragment")
  assert_eq(before.tree.nodes[0].components[0].debug_name, Some("screen"))
  assert_eq(before.tree.nodes[1].component_name, "Show")
  assert_eq(before.tree.nodes[1].components[0].name, "Status")
  assert_eq(before.tree.nodes[1].components[0].debug_name, Some("status"))
  assert_eq(before.tree.nodes[1].components[0].source, Some(source))
  assert_eq(before.tree.nodes[2].component_name, "Box")
  assert_eq(before.tree.nodes[2].components[0].name, "Indicator")
  assert_eq(before.tree.nodes[2].components[0].debug_name, Some("indicator"))
  visible.set(false)
  assert_eq(cleanup.val, 1)
  snapshot_paint(root)
  let hidden = root.snapshot().unwrap()
  assert_eq(hidden.tree.nodes.length(), 2)
  assert_eq(hidden.tree.nodes[1].id, before.tree.nodes[1].id)
  assert_eq(hidden.tree.nodes[1].components, before.tree.nodes[1].components)
  assert_eq(hidden.tree.nodes[0].components, before.tree.nodes[0].components)
  visible.set(true)
  snapshot_paint(root)
  let current = root.snapshot().unwrap()
  assert_true(current.tree.nodes[2].id != before.tree.nodes[2].id)
  assert_eq(current.tree.nodes[2].components[0].source, Some(source))
  assert_true(
    current.tree.nodes[2].components[0].id !=
    before.tree.nodes[2].components[0].id,
  )
  assert_eq(current.tree.nodes[1].components, before.tree.nodes[1].components)
  root.dispose()
  assert_eq(cleanup.val, 2)
  assert_eq(before.tree.nodes[2].components[0].debug_name, Some("indicator"))
  assert_eq(before.tree.nodes[2].components[0].source, Some(source))
}

///|
test "Eq only keys keep labels and metadata across payload updates and reorder" {
  let items = @reactive.signal([(1, "first"), (2, "second")])
  let formatted : Array[Int32] = []
  let source = @diagnostics.SourceLocation(file="src/list.mbt", line=24)
  let root = @runtime.mount(
    fn() {
      @view.for_each(
        fn() { items.get() },
        fn(item) { MetadataKey::{ id: item.0, } },
        fn(item) {
          @view.text(@reactive.bind(fn() { item().1 }))
          .component("Entry")
          .debug(name="row", source~)
        },
        key_label=fn(key) {
          formatted.push(key.id)
          "item:\{key.id}"
        },
      )
      .component("Results")
      .debug(name="rows")
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let original = root.snapshot().unwrap()
  assert_eq(formatted, [1, 2])
  assert_eq(original.tree.nodes[0].key_label, None)
  assert_eq(original.tree.nodes[0].components[0].debug_name, Some("rows"))
  assert_eq(original.tree.nodes[1].key_label, Some("item:1"))
  assert_eq(original.tree.nodes[2].key_label, Some("item:2"))
  assert_eq(original.tree.nodes[1].components[0].name, "Entry")
  assert_eq(original.tree.nodes[1].components[0].debug_name, Some("row"))
  assert_eq(original.tree.nodes[2].components[0].source, Some(source))
  items.set([(2, "updated"), (1, "first")])
  snapshot_paint(root)
  let reordered = root.snapshot().unwrap()
  assert_eq(reordered.tree.nodes[1].id, original.tree.nodes[2].id)
  assert_eq(reordered.tree.nodes[1].key_label, Some("item:2"))
  assert_eq(
    reordered.tree.nodes[1].components,
    original.tree.nodes[2].components,
  )
  assert_eq(reordered.tree.nodes[2].id, original.tree.nodes[1].id)
  assert_eq(
    reordered.tree.nodes[2].components,
    original.tree.nodes[1].components,
  )
  assert_eq(formatted, [1, 2])
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  let callbacks = Ref(0)
  let stop = root.observe_snapshots(fn(_) { callbacks.val += 1 })
  defer stop()
  let before = root.frame_stats()
  for _ in 0..<3 {
    ignore(root.snapshot())
  }
  assert_eq(formatted, [1, 2])
  assert_eq(root.frame_stats(), before)
  assert_eq(callbacks.val, 1)
  assert_eq(wakeups.val, 0)
  assert_false(root.needs_frame())
  items.set([(2, "updated"), (3, "third")])
  snapshot_paint(root)
  let current = root.snapshot().unwrap()
  assert_eq(formatted, [1, 2, 3])
  assert_eq(current.tree.nodes[1].id, original.tree.nodes[2].id)
  assert_eq(current.tree.nodes[1].components, original.tree.nodes[2].components)
  assert_eq(current.tree.nodes[2].key_label, Some("item:3"))
  assert_true(
    current.tree.nodes[2].components[0].id !=
    original.tree.nodes[1].components[0].id,
  )
  assert_false(
    current.tree.nodes.any(node => node.id == original.tree.nodes[1].id),
  )
  assert_eq(original.tree.nodes[1].key_label, Some("item:1"))
}

///|
test "repeated keys and colliding labels retain occurrence reconciliation" {
  let items = @reactive.signal([1, 1, 2])
  let formatted = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.for_each(
        fn() { items.get() },
        fn(item) { item },
        fn(item) { @view.text(item().to_string()) },
        key_label=fn(_) {
          formatted.val += 1
          "same"
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let before = root.snapshot().unwrap()
  let ids = before.tree.nodes[0].children
  assert_true(ids[0] != ids[1])
  assert_eq(formatted.val, 3)
  items.set([2, 1, 1])
  snapshot_paint(root)
  let reordered = root.snapshot().unwrap()
  assert_eq(
    reordered.tree.nodes[0].children,
    ReadOnlyArray::from_array([ids[2], ids[0], ids[1]]),
  )
  for index in 1..<4 {
    assert_eq(reordered.tree.nodes[index].key_label, Some("same"))
  }
  assert_eq(formatted.val, 3)
  items.set([1])
  snapshot_paint(root)
  items.set([1, 1])
  snapshot_paint(root)
  let reinserted = root.snapshot().unwrap()
  assert_eq(reinserted.tree.nodes[1].id, ids[0])
  assert_true(reinserted.tree.nodes[2].id != ids[1])
  assert_eq(reinserted.tree.nodes[2].key_label, Some("same"))
  assert_eq(formatted.val, 4)
}

///|
test "key formatters are untracked and use the keyed entry lifetime" {
  let items = @reactive.signal([1, 2])
  let prefix = @reactive.signal("old")
  let watched = @reactive.signal(0)
  let formatted = Ref(0)
  let effects = Ref(0)
  let cleanup = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.for_each(
        fn() { items.get() },
        fn(item) { item },
        fn(item) { @view.text(item().to_string()) },
        key_label=fn(key) {
          formatted.val += 1
          @reactive.on_cleanup(fn() { cleanup.val += 1 })
          ignore(
            @reactive.effect(fn() {
              ignore(watched.get())
              effects.val += 1
            }),
          )
          "\{prefix.get()}:\{key}"
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let original = root.snapshot().unwrap()
  assert_eq(formatted.val, 2)
  assert_eq(effects.val, 2)
  prefix.set("new")
  assert_false(root.needs_frame())
  assert_eq(formatted.val, 2)
  items.set([1, 2, 3])
  snapshot_paint(root)
  let appended = root.snapshot().unwrap()
  assert_eq(formatted.val, 3)
  assert_eq(appended.tree.nodes[1].key_label, Some("old:1"))
  assert_eq(appended.tree.nodes[3].key_label, Some("new:3"))
  prefix.set("later")
  assert_false(root.needs_frame())
  assert_eq(formatted.val, 3)
  items.set([2, 3])
  assert_eq(cleanup.val, 1)
  watched.set(1)
  assert_eq(effects.val, 5)
  snapshot_paint(root)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].key_label, Some("old:2"))
  assert_eq(formatted.val, 3)
  root.dispose()
  assert_eq(cleanup.val, 3)
  watched.set(2)
  assert_eq(effects.val, 5)
  assert_eq(original.tree.nodes[1].key_label, Some("old:1"))
}

///|
test "metadata stays absent without explicit tags or a key formatter" {
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.empty(),
        @view.text("text"),
        @controls.text_input(),
        @view.box(),
        @view.fill_box(10.0),
        @controls.button("button"),
        @controls.checkbox(),
        @controls.radio_group(@reactive.signal(1), [1], label=fn(_) { "one" }),
        @view.row([]),
        @view.stack([]),
        @view.fragment([]),
        @view.show(fn() { false }, @view.empty),
        @view.for_each(fn() { [1] }, fn(item) { MetadataKey::{ id: item, } }, fn(
          _,
        ) {
          @view.empty()
        }),
        @view.element(style=@style.BoxStyle(), painter=@view.Painter::empty()),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let snapshot = root.snapshot().unwrap()
  assert_true(
    snapshot.tree.nodes.all(node => {
      node.debug_name is None && node.source is None && node.key_label is None
    }),
  )
}
