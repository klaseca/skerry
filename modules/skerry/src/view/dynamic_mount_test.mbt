///|
test "show retains input identity selection and focus while its Bool stays equal" {
  let count = @reactive.signal(1)
  let alternative = @reactive.signal(1)
  let use_alternative = @reactive.signal(false)
  let builds = Ref(0)
  let cleanups = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.show(
        fn() {
          if use_alternative.get() {
            alternative.get() > 0
          } else {
            count.get() > 0
          }
        },
        fn() {
          builds.val += 1
          @reactive.on_cleanup(fn() { cleanups.val += 1 })
          @controls.text_input()
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.text_input("abcd"))
  assert_true(root.key_down(test_shift_key_event(KeyArrowLeft)))
  let id = root.view().node_id_at_path([0])
  count.set(2)
  use_alternative.set(true)
  count.set(0)
  @reactive.batch(fn() {
    alternative.set(0)
    alternative.set(3)
  })
  assert_eq(root.view().node_id_at_path([0]), id)
  assert_eq(root.copy_text(), Some("d"))
  assert_eq((builds.val, cleanups.val), (1, 0))
  assert_true(root.text_input("X"))
  assert_true(root.key_down(test_control_key_event(KeyA)))
  assert_eq(root.copy_text(), Some("abcX"))
  alternative.set(0)
  assert_eq(root.view().focusable_paths().length(), 0)
  assert_eq(cleanups.val, 1)
  alternative.set(-1)
  assert_eq((builds.val, cleanups.val), (1, 1))
  assert_false(root.text_input("detached"))
  alternative.set(1)
  assert_eq(builds.val, 2)
  assert_true(root.view().node_id_at_path([0]) != id)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(root.copy_text(), None)
}

///|
test "show instances have independent structure subscriptions and providers" {
  let label = @reactive.Context("outside")
  let visible = @reactive.signal(true)
  let cleanups = Ref(0)
  let create = fn() {
    @view.show(fn() { visible.get() }, fn() {
      let name = label.get()
      @reactive.on_cleanup(fn() { cleanups.val += 1 })
      @controls.text_input(placeholder=name)
    })
  }
  let first = @runtime.mount(
    fn() { @view.column([create()]) },
    text_layout_system=test_text_layout_system(),
    providers=[label.provide("first")],
  )
  let second = @runtime.mount(
    fn() { @view.column([create()]) },
    text_layout_system=test_text_layout_system(),
    providers=[label.provide("second")],
  )
  defer second.dispose()
  let first_id = first.view().node_id_at_path([0, 0])
  let second_id = second.view().node_id_at_path([0, 0])
  assert_true(first_id != second_id)
  let size = @foundation.Size(width=180.0, height=80.0)
  let first_paint = TextRunRecorder::{ text: Ref(None), }
  let second_paint = TextRunRecorder::{ text: Ref(None), }
  first.paint(first_paint, size~)
  second.paint(second_paint, size~)
  assert_eq(first_paint.text.val, Some("first"))
  assert_eq(second_paint.text.val, Some("second"))
  assert_true(first.key_down(test_key_event(KeyTab)))
  assert_true(first.text_input("one"))
  first.dispose()
  assert_eq(cleanups.val, 1)
  visible.set(false)
  assert_eq(second.view().focusable_paths().length(), 0)
  assert_eq(cleanups.val, 2)
  visible.set(true)
  second.paint(second_paint, size~)
  assert_eq(second_paint.text.val, Some("second"))
  let snapshot = second.snapshot().unwrap().tree
  assert_eq(snapshot.nodes.length(), 3)
  assert_true(second.key_down(test_key_event(KeyTab)))
  assert_true(second.text_input("two"))
  second.dispose()
  let remounted = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
    providers=[label.provide("remount")],
  )
  defer remounted.dispose()
  let paint = TextRunRecorder::{ text: Ref(None), }
  remounted.paint(paint, size~)
  assert_eq(paint.text.val, Some("remount"))
  visible.set(false)
  assert_eq(remounted.view().focusable_paths().length(), 0)
}

///|
test "keyed instances isolate reorders cleanup and new construction" {
  let items = @reactive.signal([(1, "a"), (2, "b")])
  let context = @reactive.Context("outside")
  let cleanups = Ref(0)
  let submitted = Ref("")
  let create = fn() {
    @view.for_each(fn() { items.get() }, item => item.0, fn(item) {
      let label = context.get()
      @reactive.on_cleanup(fn() { cleanups.val += 1 })
      @controls.text_input(on_submit=fn(text) {
        submitted.val = label + ":" + item().1 + ":" + text
      })
    })
  }
  let first = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
    providers=[context.provide("first")],
  )
  let second = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
    providers=[context.provide("second")],
  )
  defer second.dispose()
  let first_id = first.view().node_id_at_path([0])
  let second_id = second.view().node_id_at_path([0])
  assert_true(first_id != second_id)
  assert_true(second.key_down(test_key_event(KeyTab)))
  assert_true(second.text_input("kept"))
  items.set([(2, "B"), (1, "A")])
  assert_eq(first.view().node_id_at_path([1]), first_id)
  assert_eq(second.view().node_id_at_path([1]), second_id)
  assert_true(second.key_down(test_key_event(KeyEnter)))
  assert_eq(submitted.val, "second:A:kept")
  first.dispose()
  assert_eq(cleanups.val, 2)
  items.set([])
  assert_eq(second.view().focusable_paths().length(), 0)
  assert_eq(cleanups.val, 4)
  second.dispose()
  items.set([(3, "c")])
  let remounted = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer remounted.dispose()
  assert_eq(remounted.view().focusable_paths().length(), 1)
  items.set([])
  assert_eq(remounted.view().focusable_paths().length(), 0)
}

///|
test "keyed removal from an input callback leaves the other instance live" {
  let items = @reactive.signal([1, 2])
  let create = fn() {
    @view.for_each(fn() { items.get() }, item => item, fn(item) {
      @controls.button("remove", on_click=fn() {
        items.set(items.peek().filter(x => x != item()))
      })
    })
  }
  let first = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  let second = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer first.dispose()
  defer second.dispose()
  assert_true(first.key_down(test_key_event(KeyTab)))
  assert_true(first.key_down(test_key_event(KeyEnter)))
  assert_eq(first.view().focusable_paths().length(), 1)
  assert_eq(second.view().focusable_paths().length(), 1)
  assert_true(second.key_down(test_key_event(KeyTab)))
  assert_true(second.key_down(test_key_event(KeyEnter)))
  assert_eq(first.view().focusable_paths().length(), 0)
  assert_eq(second.view().focusable_paths().length(), 0)
}

///|
test "keyed mount samples current items and retains surviving constructed instances" {
  let items = @reactive.signal([(1, "old one"), (2, "old two")])
  let ids : Array[(Int32, Int32)] = []
  let cleanups : Array[Int32] = []
  let root = @runtime.mount(
    fn() {
      let list = @view.for_each(fn() { items.get() }, item => item.0, fn(item) {
        let key = item().0
        @reactive.on_cleanup(fn() { cleanups.push(key) })
        let view = @view.text(@reactive.bind(fn() { item().1 }))
        ids.push((key, view.node_id_at_path([]).unwrap()))
        view
      })
      items.set([(2, "latest"), (3, "new")])
      list
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(ids.length(), 3)
  assert_eq(cleanups, [1])
  assert_eq(root.view().node_id_at_path([0]), Some(ids[1].1))
  assert_eq(root.view().node_id_at_path([1]), Some(ids[2].1))
  let recorder = text_color_recorder()
  let size = @foundation.Size(width=200.0, height=80.0)
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), ["latest", "new"])
  items.set([(3, "third"), (2, "second")])
  recorder.runs.clear()
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), ["third", "second"])
  assert_eq(ids.length(), 3)
  assert_eq(root.view().node_id_at_path([1]), Some(ids[1].1))
  root.dispose()
  assert_eq(cleanups, [1, 3, 2])
}

///|
test "dynamic instances retain their own nested construction providers" {
  let context = @reactive.Context("outside")
  let visible = @reactive.signal(true)
  let items = @reactive.signal([1])
  let create = fn() {
    @view.column([
      @view.show(fn() { visible.get() }, fn() { @view.text(context.get()) }),
      @view.for_each(fn() { items.get() }, item => item, fn(_) {
        @view.text(context.get())
      }),
    ])
  }
  let first = @runtime.mount(
    fn() { @reactive.provide([context.provide("local")], create) },
    text_layout_system=test_text_layout_system(),
    providers=[context.provide("first")],
  )
  defer first.dispose()
  let second = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
    providers=[context.provide("second")],
  )
  defer second.dispose()
  let size = @foundation.Size(width=180.0, height=100.0)
  let first_paint = TextRunRecorder::{ text: Ref(None), }
  let second_paint = TextRunRecorder::{ text: Ref(None), }
  first.paint(first_paint, size~)
  second.paint(second_paint, size~)
  assert_eq(first_paint.text.val, Some("local"))
  assert_eq(second_paint.text.val, Some("second"))
  first.dispose()
  visible.set(false)
  items.set([])
  visible.set(true)
  items.set([2])
  second.paint(second_paint, size~)
  assert_eq(second_paint.text.val, Some("second"))
}
