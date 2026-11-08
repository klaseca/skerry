///|
test "computed text and disabled materialize once and preserve idle layout and IDs" {
  let source = @reactive.signal(0)
  let text_reads = Ref(0)
  let disabled_reads = Ref(0)
  let builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      builds.val += 1
      let label = @reactive.computed(() => {
        text_reads.val += 1
        (source.get() / 2).to_string()
      })
      let blocked = @reactive.computed(() => {
        disabled_reads.val += 1
        source.get() / 2 == 0
      })
      @view.column([
        @view.text(label),
        @view.text(label),
        @controls.button("Save", disabled=blocked),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq((text_reads.val, disabled_reads.val), (1, 1))
  let size = @foundation.Size(width=200.0, height=120.0)
  let recorder = text_color_recorder()
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), ["0", "0", "Save"])
  let before = root.snapshot().unwrap()
  let ids = before.tree.nodes.map(node => node.id)
  assert_true(before.tree.nodes[3].disabled)
  let wakeups = Ref(0)
  root.set_wakeup(() => wakeups.val += 1)
  source.set(1)
  assert_eq((text_reads.val, disabled_reads.val), (2, 2))
  assert_eq(root.dirty(), Clean)
  assert_eq(wakeups.val, 0)
  source.set(2)
  assert_eq((text_reads.val, disabled_reads.val), (3, 3))
  assert_eq(root.dirty(), NeedsLayout)
  assert_eq(wakeups.val, 1)
  recorder.runs.clear()
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), ["1", "1", "Save"])
  let after = root.snapshot().unwrap()
  assert_eq(after.tree.nodes.map(node => node.id), ids)
  assert_false(after.tree.nodes[3].disabled)
  root.paint(recorder, size=Size(width=240.0, height=140.0))
  ignore(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  ignore(root.pointer_up(size~, point=Point(x=10.0, y=10.0)))
  ignore(root.snapshot())
  assert_eq((text_reads.val, disabled_reads.val), (3, 3))
  assert_eq(builds.val, 1)
  root.dispose()
  source.set(4)
  assert_eq((text_reads.val, disabled_reads.val), (3, 3))
}

///|
test "one Computed shares its model cache across independent root consumers" {
  let model = @reactive.signal("first")
  let reads = Ref(0)
  let value = @reactive.computed(() => {
    reads.val += 1
    model.get()
  })
  let create = fn() { @view.text(value) }
  let a = @runtime.mount(create, text_layout_system=test_text_layout_system())
  defer a.dispose()
  let b = @runtime.mount(create, text_layout_system=test_text_layout_system())
  defer b.dispose()
  assert_eq(reads.val, 1)
  let size = @foundation.Size(width=200.0, height=40.0)
  let first = TextRunRecorder::{ text: Ref(None), }
  let second = TextRunRecorder::{ text: Ref(None), }
  a.paint(first, size~)
  b.paint(second, size~)
  model.set("second")
  a.paint(first, size~)
  b.paint(second, size~)
  assert_eq((first.text.val, second.text.val), (Some("second"), Some("second")))
  assert_eq(reads.val, 2)
  a.dispose()
  model.set("third")
  b.paint(second, size~)
  assert_eq(second.text.val, Some("third"))
  assert_eq(reads.val, 3)
  b.dispose()
  model.set("unmounted")
  assert_eq(reads.val, 3)
}

///|
test "detaching computed text stops reads and remount refreshes its shared cache" {
  let visible = @reactive.signal(false)
  let model = @reactive.signal("first")
  let reads = Ref(0)
  let value = @reactive.computed(() => {
    reads.val += 1
    model.get()
  })
  let root = @runtime.mount(
    fn() {
      @view.show(() => visible.get(), fn() {
        @view.column([@view.text(value), @view.text(value)])
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(reads.val, 0)
  visible.set(true)
  assert_eq(reads.val, 1)
  visible.set(false)
  model.set("hidden")
  assert_eq(reads.val, 1)
  visible.set(true)
  assert_eq(reads.val, 2)
  let recorder = text_color_recorder()
  root.paint(recorder, size=Size(width=200.0, height=80.0))
  assert_eq(recorder.runs.map(run => run.text), ["hidden", "hidden"])
  assert_eq(reads.val, 2)
}
