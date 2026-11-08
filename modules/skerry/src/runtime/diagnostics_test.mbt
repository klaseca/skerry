///|
fn snapshot_paint(root : @runtime.UiRoot) -> Unit {
  root.paint(
    TextRunRecorder::{ text: Ref(None), },
    size=Size(width=200.0, height=100.0),
  )
}

///|
test "snapshots freeze reactive styles without reading unused theme producers" {
  let width = @reactive.signal(20.0)
  let reads = Ref(0)
  let unused_reads = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.box(
          style=@style.BoxStyle::bind(
            @reactive.bind(fn() {
              reads.val += 1
              @style.BoxStyle().width(width.get()).height(30.0)
            }),
          ),
        ),
      ])
    },
    theme=Theme(
      styles=@style.Styles().add(
        @controls.TextInputStyle::bind(
          @reactive.bind(fn() {
            unused_reads.val += 1
            @controls.TextInputStyle()
          }),
        ),
      ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let before = reads.val
  let saved = root.snapshot().unwrap()
  assert_eq(reads.val, before)
  assert_eq(unused_reads.val, 0)
  let declared : @style.BoxStyle = saved.tree.nodes[1].specified_style
    .unwrap()
    .get()
    .unwrap()
  assert_false(@style.StyleSpec::has_source(declared))
  assert_eq(declared.layout.width, Some(20.0))
  assert_eq(
    (saved.theme.styles.get() : ReadOnlyArray[@controls.TextInputStyle]).length(),
    0,
  )
  assert_eq(
    (
      saved.tree.nodes[1].theme.styles.get() :
      ReadOnlyArray[@controls.TextInputStyle]).length(),
    0,
  )
  width.set(40.0)
  snapshot_paint(root)
  let updated : @style.BoxStyle = root.snapshot().unwrap().tree.nodes[1].specified_style
    .unwrap()
    .get()
    .unwrap()
  assert_eq(updated.layout.width, Some(40.0))
  root.dispose()
  let retained : @style.BoxStyle = saved.tree.nodes[1].specified_style
    .unwrap()
    .get()
    .unwrap()
  assert_eq(retained.layout.width, Some(20.0))
  assert_eq(unused_reads.val, 0)
}

///|
test "snapshots share paint input and box model geometry" {
  let frames : Array[@foundation.Rect] = []
  let padding = @foundation.Insets::symmetric(horizontal=7.0, vertical=3.0)
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @view.row(
            [
              @view.box(style=@style.BoxStyle().width(10.0).height(20.0)),
              @view.interactive(
                @view.element(
                  style=@style.BoxStyle().width(25.0).height(20.0),
                  painter=@view.Painter(fn(_, frame) { frames.push(frame) }),
                ),
                on_click=fn() { () },
              ),
            ],
            style=@view.FlexStyle().padding(padding).spacing(4.0).height(40.0),
          ),
        ],
        style=@view.FlexStyle().surface(
          @style.BoxStyle().padding(@foundation.Insets::all(5.0)),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let snapshot = root.snapshot().unwrap()
  let nodes = snapshot.tree.nodes
  assert_eq(nodes.length(), 4)
  assert_eq(nodes[0].component_name, "Column")
  assert_eq(nodes[1].component_name, "Row")
  assert_eq(nodes[2].component_name, "Box")
  assert_eq(nodes[3].component_name, "Custom")
  assert_eq(nodes[0].parent_id, None)
  assert_eq(nodes[0].children, ReadOnlyArray::from_array([nodes[1].id]))
  assert_eq(
    nodes[1].children,
    ReadOnlyArray::from_array([nodes[2].id, nodes[3].id]),
  )
  assert_eq(nodes[3].parent_id, Some(nodes[1].id))
  assert_eq(nodes[3].frame, frames[0])
  assert_eq(nodes[1].padding, padding)
  assert_eq(
    nodes[1].content,
    nodes[1].frame.inset(nodes[1].border).inset(padding),
  )
  let target = nodes[3]
  let point = @foundation.Point(
    x=target.frame.origin.x + target.frame.size.width / 2.0,
    y=target.frame.origin.y + target.frame.size.height / 2.0,
  )
  assert_true(root.pointer_down(size=snapshot.tree.size, point~))
  assert_true(root.snapshot() is None)
  snapshot_paint(root)
  let pressed = root.snapshot().unwrap()
  assert_eq(pressed.focused_node_id, Some(target.id))
  assert_eq(pressed.captured_node_id, Some(target.id))
  assert_eq(pressed.tree.nodes[3].frame, target.frame)
  assert_true(root.pointer_cancel())
  snapshot_paint(root)
  assert_eq(root.snapshot().unwrap().captured_node_id, None)
}

///|
test "logical regions and disabled descendants remain inspectable" {
  let root = @runtime.mount(
    fn() {
      @view.interactive(
        @view.fragment([
          @view.show(fn() { true }, fn() { @controls.button("button") }),
          @view.stack([@controls.text_input()]),
        ]),
        disabled=true,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let snapshot = root.snapshot().unwrap()
  assert_eq(
    snapshot.tree.nodes.map(node => node.component_name),
    ReadOnlyArray::from_array([
      "Fragment", "Show", "Button", "Stack", "TextInput",
    ]),
  )
  assert_true(snapshot.tree.nodes.all(node => node.disabled))
  assert_true(snapshot.tree.nodes[2].focusable)
  assert_true(snapshot.tree.nodes[4].focusable)
  assert_eq(snapshot.tree.nodes[1].children[0], snapshot.tree.nodes[2].id)
  assert_eq(snapshot.tree.nodes[4].parent_id, Some(snapshot.tree.nodes[3].id))
}

///|
test "keyed selection survives reorder and snapshots do not retain removed lifetimes" {
  let items = @reactive.signal([1, 2])
  let visible = @reactive.signal(true)
  let cleanup : Array[Int32] = []
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @view.for_each(fn() { items.get() }, fn(item) { item }, fn(item) {
          let key = item()
          @reactive.on_cleanup(fn() { cleanup.push(key) })
          @view.text(@reactive.bind(fn() { item().to_string() }))
        })
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let original = root.snapshot().unwrap()
  let ids = original.tree.nodes[1].children
  assert_eq(original.tree.nodes[1].component_name, "ForEach")
  items.set([2, 1])
  assert_true(root.snapshot() is None)
  snapshot_paint(root)
  let reordered = root.snapshot().unwrap()
  assert_eq(reordered.tree.nodes[1].id, original.tree.nodes[1].id)
  assert_eq(
    reordered.tree.nodes[1].children,
    ReadOnlyArray::from_array([ids[1], ids[0]]),
  )
  items.set([2])
  assert_eq(cleanup, [1])
  snapshot_paint(root)
  assert_false(
    root.snapshot().unwrap().tree.nodes.any(node => node.id == ids[0]),
  )
  assert_eq(original.tree.nodes[1].children, ids)
  visible.set(false)
  assert_eq(cleanup, [1, 2])
  snapshot_paint(root)
  assert_eq(root.snapshot().unwrap().tree.nodes.length(), 1)
  visible.set(true)
  snapshot_paint(root)
  let reinserted = root.snapshot().unwrap()
  assert_true(reinserted.tree.nodes[1].children[0] != ids[1])
  root.dispose()
  assert_eq(cleanup, [1, 2, 2])
  assert_eq(original.tree.nodes.length(), 4)
  assert_true(root.snapshot() is None)
}

///|
test "snapshot identities and geometry are independent across component instances" {
  let create = fn() { @view.text("shared") }
  let first = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer first.dispose()
  let second = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  snapshot_paint(first)
  second.paint(
    TextRunRecorder::{ text: Ref(None), },
    size=Size(width=300.0, height=150.0),
  )
  let a = first.snapshot().unwrap()
  let b = second.snapshot().unwrap()
  assert_true(a.root_id != b.root_id)
  assert_true(a.tree.nodes[0].id != b.tree.nodes[0].id)
  assert_eq(a.tree.nodes[0].frame.size, a.tree.size)
  assert_eq(b.tree.nodes[0].frame.size, b.tree.size)
  first.dispose()
  assert_true(first.snapshot() is None)
  assert_eq(second.snapshot(), Some(b))
}

///|
test "on demand snapshots and observer attachment keep an idle root idle" {
  let measurements = Ref(0)
  let root = @runtime.mount(
    fn() { @view.text("text") },
    text_layout_system=test_text_layout_system(on_measure=fn() {
      measurements.val += 1
    }),
  )
  defer root.dispose()
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  assert_true(root.snapshot() is None)
  snapshot_paint(root)
  root.record_present(root.paint_revision())
  let before = root.frame_stats()
  let measured = measurements.val
  let callbacks = Ref(0)
  let stop = root.observe_snapshots(fn(_) { callbacks.val += 1 })
  assert_eq(callbacks.val, 1)
  for _ in 0..<5 {
    let snapshot = root.snapshot().unwrap()
    assert_eq(snapshot.frame, before)
    assert_eq(snapshot.tree.nodes[0].component_name, "Text")
  }
  stop()
  stop()
  assert_eq(measurements.val, measured)
  assert_eq(root.frame_stats(), before)
  assert_eq(wakeups.val, 0)
  assert_eq(callbacks.val, 1)
  assert_false(root.needs_frame())
}

///|
test "unstable paints never publish mixed logical and layout snapshots" {
  for during_measure in [true, false] {
    let value = @reactive.signal("before")
    let first = Ref(true)
    fn change() {
      if first.val {
        first.val = false
        value.set("after")
      }
    }
    let root = @runtime.mount(
      fn() {
        @view.column([
          @view.element(
            style=@style.BoxStyle(),
            painter=@view.Painter(fn(_, _) { if !during_measure { change() } }),
          ),
          @view.text_of(value),
        ])
      },
      text_layout_system=test_text_layout_system(on_measure=fn() {
        if during_measure {
          change()
        }
      }),
    )
    defer root.dispose()
    let snapshots : Array[@runtime.UiSnapshot] = []
    let stop = root.observe_snapshots(fn(snapshot) { snapshots.push(snapshot) })
    defer stop()
    snapshot_paint(root)
    assert_true(root.needs_frame())
    assert_true(root.snapshot() is None)
    assert_eq(snapshots.length(), 0)
    snapshot_paint(root)
    assert_false(root.needs_frame())
    assert_eq(snapshots.length(), 1)
    assert_eq(snapshots[0].frame.paint_count, 2)
    assert_eq(snapshots[0], root.snapshot().unwrap())
  }
}

///|
test "snapshots are captured before frame observers mutate the live tree" {
  let visible = @reactive.signal(true)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() { @controls.button("old") })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let first = Ref(true)
  let order : Array[Int32] = []
  let frames = root.observe_frames(fn(event) {
    if event is Painted(_) {
      order.push(1)
      if first.val {
        first.val = false
        visible.set(false)
      }
    }
  })
  defer frames()
  let snapshots : Array[@runtime.UiSnapshot] = []
  let stop = root.observe_snapshots(fn(snapshot) {
    order.push(2)
    snapshots.push(snapshot)
  })
  defer stop()
  snapshot_paint(root)
  assert_eq(order, [1, 2])
  assert_eq(snapshots[0].tree.nodes.length(), 2)
  assert_eq(snapshots[0].frame.paint_count, 1)
  assert_true(root.snapshot() is None)
  root.record_present(1)
  snapshot_paint(root)
  let current = root.snapshot().unwrap()
  assert_eq(current.tree.nodes.length(), 1)
  assert_eq(current.frame.paint_count, 2)
  assert_eq(current.frame.presented_frame, 1)
  assert_eq(current.frame.present_count, 1)
  root.record_present(1)
  assert_eq(root.snapshot().unwrap().frame.present_count, 2)
  assert_eq(snapshots.length(), 2)
  assert_eq(snapshots[0].tree.nodes.length(), 2)
}

///|
test "snapshot observers isolate tracking subscriptions and cleanup" {
  let trigger = @reactive.signal(0)
  let unrelated = @reactive.signal(0)
  let root = @runtime.mount(
    @view.empty,
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let first = Ref(true)
  let cleanup = Ref(0)
  let owned_runs = Ref(0)
  let caller_runs = Ref(0)
  let stop_observer : Ref[() -> Unit] = Ref(fn() { () })
  let stop_caller = @reactive.effect(fn() {
    ignore(trigger.get())
    caller_runs.val += 1
    ignore(root.snapshot())
    if first.val {
      first.val = false
      stop_observer.val = root.observe_snapshots(fn(_) {
        ignore(unrelated.get())
        @reactive.on_cleanup(fn() { cleanup.val += 1 })
        ignore(
          @reactive.effect(fn() {
            ignore(unrelated.get())
            owned_runs.val += 1
          }),
        )
      })
    }
  })
  defer stop_caller()
  unrelated.set(1)
  assert_eq(caller_runs.val, 1)
  assert_eq(owned_runs.val, 2)
  trigger.set(1)
  assert_eq(caller_runs.val, 2)
  assert_eq(cleanup.val, 0)
  (stop_observer.val)()
  (stop_observer.val)()
  assert_eq(cleanup.val, 1)
  unrelated.set(2)
  assert_eq(owned_runs.val, 2)
  root.dispose()
  assert_eq(cleanup.val, 1)
}

///|
test "observer replacement disposal and captured delivery respect lifetimes" {
  let root = @runtime.mount(
    @view.empty,
    text_layout_system=test_text_layout_system(),
  )
  let a = Ref(0)
  let b = Ref(0)
  let stop_a = root.observe_snapshots(fn(_) { a.val += 1 })
  snapshot_paint(root)
  assert_eq(a.val, 1)
  let stop_b = root.observe_snapshots(fn(_) { b.val += 1 })
  assert_eq(b.val, 1)
  stop_a()
  snapshot_paint(root)
  assert_eq(a.val, 1)
  assert_eq(b.val, 2)
  let frame_stop = root.observe_frames(fn(event) {
    if event is Painted(_) {
      root.dispose()
    }
  })
  snapshot_paint(root)
  assert_eq(b.val, 2)
  stop_b()
  frame_stop()
  let late = root.observe_snapshots(fn(_) { b.val += 1 })
  late()
  assert_eq(b.val, 2)
}

///|
test "immediate snapshot delivery cannot reenter paint actions or present" {
  let root = @runtime.mount(
    @view.empty,
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let calls = Ref(0)
  let actions = Ref(0)
  let stop = root.observe_snapshots(fn(_) {
    calls.val += 1
    if calls.val == 1 {
      ignore(root.post(fn() { actions.val += 1 }))
      root.drain_actions()
      root.record_present(1)
      snapshot_paint(root)
    }
  })
  defer stop()
  assert_eq(calls.val, 1)
  assert_eq(actions.val, 0)
  assert_eq(root.frame_stats().paint_count, 1)
  assert_eq(root.frame_stats().present_count, 0)
  assert_true(root.needs_frame())
  root.drain_actions()
  assert_eq(actions.val, 1)
  snapshot_paint(root)
  assert_eq(calls.val, 2)
}

///|
test "hit testing another viewport never relabels its layout as painted geometry" {
  let root = @runtime.mount(
    @view.empty,
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  snapshot_paint(root)
  let original = root.snapshot().unwrap()
  assert_false(
    root.click_at(
      size=Size(width=300.0, height=150.0),
      point=Point(x=1000.0, y=1000.0),
    ),
  )
  assert_false(root.needs_frame())
  assert_true(root.snapshot() is None)
  snapshot_paint(root)
  let current = root.snapshot().unwrap()
  assert_eq(current.tree, original.tree)
  assert_eq(current.frame.paint_count, 2)
  assert_eq(current.frame.layout_count, 3)
}

///|
test "a projection replaced during drawing is not published as that paint" {
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let first = Ref(true)
  let root = @runtime.mount(
    fn() {
      @view.element(
        style=@style.BoxStyle(),
        painter=@view.Painter(fn(_, _) {
          if first.val {
            first.val = false
            ignore(
              root_ref.val
              .unwrap()
              .click_at(
                size=Size(width=300.0, height=150.0),
                point=Point(x=1000.0, y=1000.0),
              ),
            )
          }
        }),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root_ref.val = Some(root)
  let frames : Array[Int32] = []
  let stop = root.observe_snapshots(fn(snapshot) {
    frames.push(snapshot.frame.paint_count)
  })
  defer stop()
  snapshot_paint(root)
  assert_false(root.needs_frame())
  assert_true(root.snapshot() is None)
  assert_eq(frames, [])
  snapshot_paint(root)
  assert_eq(frames, [2])
  assert_eq(root.snapshot().unwrap().tree.size, Size(width=200.0, height=100.0))
}
