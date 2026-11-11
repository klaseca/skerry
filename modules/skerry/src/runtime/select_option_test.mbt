///|
test "select options accept mixed constant signal computed and binding sources" {
  let title = @reactive.signal("Two")
  let blocked = @reactive.signal(false)
  let computed_title = @reactive.computed(fn() { title.get() + " computed" })
  let computed_blocked = @reactive.computed(fn() { blocked.get() })
  let options = [
    @controls.SelectOption(1, label="One"),
    @controls.SelectOption(2, label=title, disabled=blocked),
    @controls.SelectOption(3, label=computed_title, disabled=computed_blocked),
    @controls.SelectOption(
      4,
      label=@reactive.bind(fn() { title.get() + " bound" }),
      disabled=@reactive.bind(fn() { blocked.get() }),
    ),
    @controls.SelectOption(5, label="Five", disabled=true),
  ]
  let selected = @reactive.signal(Some(2))
  let root = @runtime.mount(
    fn() { @controls.select(options, selected~) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = StyleRecorder()
  let size = @foundation.Size(width=320.0, height=400.0)
  root.paint(recorder, size~)
  assert_eq(recorder.text[0].text, "Two")
  title.set("Updated")
  root.paint(recorder, size~)
  assert_eq(recorder.text[0].text, "Updated")
  select_test_open(root)
  root.paint(recorder, size~)
  let text = recorder.text.map(run => run.text)
  assert_true(text.contains("Updated computed"))
  assert_true(text.contains("Updated bound"))
  assert_eq(select_test_active(root), Some(1))
  blocked.set(true)
  let nodes = select_test_nodes(root)
  assert_false(nodes[0].disabled)
  for index in 1..<5 {
    assert_true(nodes[index].disabled)
  }
  assert_eq(select_test_active(root), Some(0))
  assert_eq(selected.peek(), Some(2))
  blocked.set(false)
  assert_true(root.key_down(test_key_event(KeyEnd)))
  assert_eq(select_test_active(root), Some(3))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(selected.peek(), Some(4))
}

///|
test "constructing reusable options is cold and each root owns applied labels and availability" {
  let title = @reactive.Context(@reactive.signal("Default"))
  let blocked = @reactive.Context(@reactive.signal(false))
  let label_reads = Ref(0)
  let disabled_reads = Ref(0)
  let option = @controls.SelectOption(
    1,
    label=@reactive.bind(fn() {
      label_reads.val += 1
      title.get().get()
    }),
    disabled=@reactive.bind(fn() {
      disabled_reads.val += 1
      blocked.get().get()
    }),
  )
  let options = [option, @controls.SelectOption(2, label="Fallback")]
  assert_eq(label_reads.val, 0)
  assert_eq(disabled_reads.val, 0)
  let first_title = @reactive.signal("First")
  let second_title = @reactive.signal("Second")
  let first_blocked = @reactive.signal(false)
  let second_blocked = @reactive.signal(true)
  let create = fn() {
    @controls.select(options, selected=@reactive.signal(Some(1)))
  }
  let first = @runtime.mount(
    create,
    providers=[title.provide(first_title), blocked.provide(first_blocked)],
    text_layout_system=test_text_layout_system(),
  )
  defer first.dispose()
  let second = @runtime.mount(
    create,
    providers=[title.provide(second_title), blocked.provide(second_blocked)],
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  assert_eq(label_reads.val, 2)
  assert_eq(disabled_reads.val, 0)
  let size = @foundation.Size(width=320.0, height=400.0)
  let recorder = StyleRecorder()
  first.paint(recorder, size~)
  assert_eq(recorder.text[0].text, "First")
  second.paint(recorder, size~)
  assert_eq(recorder.text[0].text, "Second")
  assert_eq(label_reads.val, 2)
  select_test_open(first)
  select_test_open(second)
  assert_eq(select_test_active(first), Some(0))
  assert_eq(select_test_active(second), Some(1))
  let reads = (label_reads.val, disabled_reads.val)
  first.paint(recorder, size~)
  second.paint(recorder, size~)
  ignore(first.snapshot())
  ignore(second.snapshot())
  assert_eq((label_reads.val, disabled_reads.val), reads)
  first.dispose()
  let stopped = (label_reads.val, disabled_reads.val)
  first_title.set("Disposed")
  first_blocked.set(true)
  assert_eq((label_reads.val, disabled_reads.val), stopped)
  second_title.set("Live")
  second_blocked.set(false)
  second.paint(recorder, size~)
  assert_eq(recorder.text[0].text, "Live")
  assert_false(select_test_nodes(second)[0].disabled)
  assert_true(second.key_down(test_key_event(KeyEscape)))
  let closed_disabled = disabled_reads.val
  second_blocked.set(true)
  assert_eq(disabled_reads.val, closed_disabled)
  second_title.set("Closed")
  second.paint(recorder, size~)
  assert_eq(recorder.text[0].text, "Closed")
}

///|
#derive(Eq)
struct SelectOptionTestValue {
  id : Int32
}

///|
test "select copies option descriptions and compares model values without Show" {
  let selected = @reactive.signal(Some(SelectOptionTestValue::{ id: 1, }))
  let options = [
    @controls.SelectOption(SelectOptionTestValue::{ id: 1, }, label="First"),
    @controls.SelectOption(SelectOptionTestValue::{ id: 2, }, label="Second"),
  ]
  let control = @controls.select(options, selected~)
  options.clear()
  let root = @runtime.mount(
    fn() { control },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  assert_eq(select_test_nodes(root).length(), 2)
  assert_eq(select_test_active(root), Some(0))
  assert_true(root.key_down(test_key_event(KeyEnd)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_true(selected.peek() is Some({ id: 2, }))
}
