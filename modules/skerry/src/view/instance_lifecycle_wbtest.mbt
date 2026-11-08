///|
test "duplicate decorated instances are rejected before mounting and claims roll back" {
  let starts = Ref(0)
  let stops = Ref(0)
  let leaf = element(
    style=@style.BoxStyle(),
    painter=Painter::empty(),
    reactivity=Reactivity(mount=fn(_) {
      starts.val += 1
      fn() { stops.val += 1 }
    }),
  )
  let next_ui_id = next_ui_node_id_ref.val
  let decorated = interactive(leaf)
    .component("Control")
    .component("Alias")
    .debug(name="alias")
  assert_eq(next_ui_node_id_ref.val, next_ui_id)
  assert_true(physical_equal(leaf.node.lifecycle, decorated.node.lifecycle))
  assert_true(leaf.node.metadata is None)
  let fresh = empty()
  let invalid = column([fresh, stack([decorated, leaf])])
  let problem = claim_nodes([invalid.node]).unwrap()
  assert_true(problem.contains("more than once"))
  assert_eq((starts.val, stops.val), (0, 0))
  assert_true(invalid.node.lifecycle.phase is Available)
  assert_true(fresh.node.lifecycle.phase is Available)
  assert_true(leaf.node.lifecycle.phase is Available)
  let stop = decorated.mount_reactivity(mark_layout_dirty=fn() { () }, mark_paint_dirty=fn() {
    ()
  })
  assert_eq(starts.val, 1)
  assert_true(claim_nodes([leaf.node]) is Some(_))
  stop()
  stop()
  assert_eq(stops.val, 1)
  assert_true(leaf.node.lifecycle.phase is Disposed)
  assert_true(claim_nodes([leaf.node]).unwrap().contains("disposed"))
}

///|
test "a rejected second tree preserves the first subscriptions and fresh siblings" {
  let value = @reactive.signal(0)
  let reads = Ref(0)
  let paints = Ref(0)
  let leaf = element(
    style=@style.BoxStyle(),
    painter=Painter::empty(),
    reactivity=Reactivity::paint(fn() {
      ignore(value.get())
      reads.val += 1
    }),
  )
  let first = column([leaf])
  let stop_first = first.mount_reactivity(mark_layout_dirty=fn() { () }, mark_paint_dirty=fn() {
    paints.val += 1
  })
  defer stop_first()
  assert_eq(reads.val, 1)
  let fresh = empty()
  let second = column([fresh, interactive(leaf)])
  assert_true(claim_nodes([second.node]) is Some(_))
  assert_true(second.node.lifecycle.phase is Available)
  assert_true(fresh.node.lifecycle.phase is Available)
  assert_true(leaf.node.lifecycle.phase is Mounted)
  value.set(1)
  assert_eq((reads.val, paints.val), (2, 1))
  let stop_fresh = fresh.mount_reactivity(mark_layout_dirty=fn() { () }, mark_paint_dirty=fn() {
    ()
  })
  stop_fresh()
  stop_first()
  value.set(2)
  assert_eq((reads.val, paints.val), (2, 1))
  assert_true(claim_nodes([first.node]).unwrap().contains("disposed"))
}

///|
test "dynamic attachment checks the whole incoming forest before subscriptions" {
  let starts = Ref(0)
  let leaf = element(
    style=@style.BoxStyle(),
    painter=Painter::empty(),
    reactivity=Reactivity(mount=fn(_) {
      starts.val += 1
      fn() { () }
    }),
  )
  let a = column([leaf])
  let b = column([leaf.component("Alias")])
  assert_true(claim_nodes([a.node, b.node]) is Some(_))
  assert_eq(starts.val, 0)
  assert_true(a.node.lifecycle.phase is Available)
  assert_true(b.node.lifecycle.phase is Available)
  assert_true(leaf.node.lifecycle.phase is Available)
}
