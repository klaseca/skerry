///|
fn radio_test_focus(root : @runtime.UiRoot) -> Int32? {
  root.paint(StyleRecorder(), size=Size(width=240.0, height=180.0))
  root.snapshot().unwrap().focused_node_id
}

///|
test "Tab enters the selected radio and leaves the group in either direction" {
  let selected = @reactive.signal(1)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button("Before"),
        @controls.radio_group(selected, [0, 1, 2], label=fn(value) {
          value.to_string()
        }),
        @controls.button("After"),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let id = fn(path) { root.view().node_id_at_path(path) }
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), id([0]))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), id([1, 1]))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), id([2]))
  assert_true(root.key_down(test_shift_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), id([1, 1]))
  assert_true(root.key_down(test_shift_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), id([0]))
  assert_eq(selected.peek(), 1)
}

///|
test "radio arrow keys select and focus with wrapping" {
  let selected = @reactive.signal(0)
  let changes : Array[Int32] = []
  let root = @runtime.mount(
    fn() {
      @controls.radio_group(
        selected,
        [0, 1, 2],
        label=fn(value) { value.to_string() },
        on_change=fn(event) { changes.push(event.value) },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  let steps : Array[(@foundation.Key, Int32)] = [
    (KeyArrowRight, 1),
    (KeyArrowDown, 2),
    (KeyArrowRight, 0),
    (KeyArrowLeft, 2),
    (KeyArrowUp, 1),
  ]
  for (key, expected) in steps {
    assert_true(root.key_down(test_key_event(key)))
    assert_eq(selected.peek(), expected)
    assert_eq(radio_test_focus(root), root.view().node_id_at_path([expected]))
  }
  assert_eq(changes, [1, 2, 0, 2, 1])
}

///|
test "a vetoed radio selection retains navigation focus and Tab exits the group" {
  let selected = @reactive.signal(0)
  let proposals : Array[Int32] = []
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.radio_group(
          selected,
          [0, 1, 2],
          label=fn(value) { value.to_string() },
          on_change=fn(event) {
            proposals.push(event.value)
            event.prevent_default()
          },
        ),
        @controls.button("After"),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyArrowRight)))
  assert_eq(selected.peek(), 0)
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([0, 1]))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([1]))
  assert_true(root.key_down(test_shift_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([0, 0]))
  assert_eq(proposals, [1])
}

///|
test "per option disabled is cold applied and skipped by Tab arrows and pointer" {
  let blocked = @reactive.signal([0, 2])
  let selected = @reactive.signal(99)
  let reads = Ref(0)
  let changes : Array[Int32] = []
  let group = @controls.radio_group(
    selected,
    [0, 1, 2],
    label=fn(value) { value.to_string() },
    item_style=@controls.RadioStyle().frame(
      @style.BoxStyle().width(160.0).height(30.0),
    ),
    item_disabled=fn(value) {
      reads.val += 1
      blocked.get().contains(value)
    },
    on_change=fn(event) { changes.push(event.value) },
  )
  assert_eq(reads.val, 0)
  let root = @runtime.mount(
    fn() { group },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(reads.val, 3)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([1]))
  assert_eq(selected.peek(), 99)
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_eq(selected.peek(), 1)
  ignore(radio_test_focus(root))
  assert_true(root.key_down(test_key_event(KeyArrowDown)))
  assert_false(root.needs_frame())
  assert_eq(changes, [1])
  assert_eq(reads.val, 3)
  assert_false(
    root.click_at(
      size=Size(width=160.0, height=100.0),
      point=Point(x=8.0, y=12.0),
    ),
  )
  assert_eq(changes, [1])
  blocked.set([])
  let after_update = reads.val
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([1]))
  assert_true(root.key_down(test_key_event(KeyArrowRight)))
  assert_eq(selected.peek(), 2)
  assert_eq(reads.val, after_update)
}

///|
test "disabling a focused radio recovers to its neighbour without selecting it" {
  let blocked = @reactive.signal([])
  let selected = @reactive.signal(1)
  let changes = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.radio_group(
          selected,
          [0, 1, 2],
          label=fn(value) { value.to_string() },
          item_disabled=fn(value) { blocked.get().contains(value) },
          on_change=fn(_) { changes.val += 1 },
        ),
        @controls.button("After"),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(StyleRecorder(), size=Size(width=240.0, height=180.0))
  let before = root.snapshot().unwrap()
  blocked.set([1])
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([0, 2]))
  assert_eq(selected.peek(), 1)
  assert_eq(changes.val, 0)
  let after = root.snapshot().unwrap()
  assert_eq(after.frame.layout_count, before.frame.layout_count)
  assert_eq(after.frame.text_measure_count, before.frame.text_measure_count)
  assert_eq(after.tree.nodes[1].component_name, "Column")
  assert_eq(after.tree.nodes[1].components[0].name, "RadioGroup")
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([1]))
  blocked.set([0, 1, 2])
  assert_true(root.key_down(test_shift_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([1]))
  blocked.set([])
  assert_true(root.key_down(test_shift_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([0, 1]))
}

///|
test "disabled groups and empty groups have no Tab stop" {
  let disabled = @reactive.signal(false)
  let selected = @reactive.signal(1)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button("Before"),
        @controls.radio_group(selected, [], label=fn(value) {
          value.to_string()
        }),
        @controls.radio_group(
          selected,
          [0, 1],
          label=fn(value) { value.to_string() },
          disabled~,
        ),
        @controls.button("After"),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([2, 1]))
  disabled.set(true)
  assert_eq(radio_test_focus(root), None)
  assert_eq(selected.peek(), 1)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([0]))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([3]))
}

///|
test "radio navigation reveals the focused option instead of scrolling the key" {
  let selected = @reactive.signal(0)
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @controls.radio_group(
          selected,
          [0, 1, 2],
          label=fn(value) { value.to_string() },
          item_style=@controls.RadioStyle().frame(
            @style.BoxStyle().height(40.0),
          ),
        ),
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=180.0, height=60.0)
  root.paint(StyleRecorder(), size~)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(offset.peek(), 0.0)
  assert_true(root.key_down(test_key_event(KeyArrowDown)))
  assert_eq(selected.peek(), 1)
  assert_eq(offset.peek(), 20.0)
  assert_true(root.key_down(test_key_event(KeyArrowRight)))
  assert_eq(selected.peek(), 2)
  assert_eq(offset.peek(), 60.0)
  assert_true(root.key_down(test_key_event(KeyArrowDown)))
  assert_eq(selected.peek(), 0)
  assert_eq(offset.peek(), 0.0)
  assert_false(root.key_down(test_control_key_event(KeyArrowDown)))
  assert_false(root.key_down(test_shift_key_event(KeyArrowDown)))
  assert_eq(selected.peek(), 0)
  assert_eq(offset.peek(), 0.0)
}

///|
test "a handler can disable the proposed radio before its default write" {
  let blocked = @reactive.signal(false)
  let selected = @reactive.signal(0)
  let root = @runtime.mount(
    fn() {
      @controls.radio_group(
        selected,
        [0, 1, 2],
        label=fn(value) { value.to_string() },
        item_disabled=fn(value) { value == 1 && blocked.get() },
        on_change=fn(event) { if event.value == 1 { blocked.set(true) } },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  ignore(radio_test_focus(root))
  let observed : Array[Int32?] = []
  root.set_wakeup(fn() { observed.push(radio_test_focus(root)) })
  defer root.set_wakeup(fn() { () })
  assert_true(root.key_down(test_key_event(KeyArrowRight)))
  assert_eq(selected.peek(), 0)
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([2]))
  assert_eq(observed, [root.view().node_id_at_path([2])])
  assert_false(root.needs_frame())
}

///|
test "a radio change handler can remove the entire group" {
  let visible = @reactive.signal(true)
  let selected = @reactive.signal(0)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @controls.radio_group(
          selected,
          [0, 1],
          label=fn(value) { value.to_string() },
          on_change=fn(_) { visible.set(false) },
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyArrowRight)))
  assert_eq(selected.peek(), 0)
  assert_eq(radio_test_focus(root), None)
  assert_false(root.key_down(test_key_event(KeyArrowRight)))
}

///|
test "radio group instances resolve per root item availability and focus" {
  let availability = @reactive.Context(@reactive.signal(false))
  let selected = @reactive.signal(0)
  let create = fn() {
    @controls.radio_group(
      selected,
      [0, 1, 2],
      label=fn(value) { value.to_string() },
      item_disabled=fn(value) { value == 1 && availability.get().get() },
    )
  }
  let first = @runtime.mount(
    create,
    providers=[availability.provide(@reactive.signal(true))],
    text_layout_system=test_text_layout_system(),
  )
  defer first.dispose()
  let second = @runtime.mount(
    create,
    providers=[availability.provide(@reactive.signal(false))],
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  assert_true(first.key_down(test_key_event(KeyTab)))
  assert_true(first.key_down(test_key_event(KeyArrowRight)))
  assert_eq(selected.peek(), 2)
  assert_eq(radio_test_focus(first), first.view().node_id_at_path([2]))
  assert_true(second.key_down(test_key_event(KeyTab)))
  assert_true(second.key_down(test_key_event(KeyArrowLeft)))
  assert_eq(selected.peek(), 1)
  assert_eq(radio_test_focus(first), first.view().node_id_at_path([2]))
  first.dispose()
  assert_true(second.key_down(test_key_event(KeyArrowLeft)))
  assert_eq(selected.peek(), 0)
}

///|
test "standalone radio arrows remain unhandled and repeat navigates a group" {
  let alone = @runtime.mount(
    fn() { @controls.radio() },
    text_layout_system=test_text_layout_system(),
  )
  defer alone.dispose()
  assert_true(alone.key_down(test_key_event(KeyTab)))
  assert_false(alone.key_down(test_key_event(KeyArrowRight)))
  let selected = @reactive.signal(0)
  let root = @runtime.mount(
    fn() {
      @controls.radio_group(selected, [0, 1, 2], label=fn(value) {
        value.to_string()
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(KeyEvent(key=KeyArrowRight, repeat=true)))
  assert_eq(selected.peek(), 1)
  assert_true(root.key_down(KeyEvent(key=KeyArrowRight, repeat=true)))
  assert_eq(selected.peek(), 2)
}

///|
test "nested navigation supersedes an older proposal for another option in the same group" {
  let active : Ref[@runtime.UiRoot?] = Ref(None)
  let selected = @reactive.signal(0)
  let proposals : Array[Int32] = []
  let root = @runtime.mount(
    fn() {
      @controls.radio_group(
        selected,
        [0, 1, 2],
        label=fn(value) { value.to_string() },
        on_change=fn(event) {
          proposals.push(event.value)
          if event.value == 1 {
            ignore(active.val.unwrap().key_down(test_key_event(KeyArrowRight)))
          }
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  active.val = Some(root)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyArrowRight)))
  assert_eq(proposals, [1, 2])
  assert_eq(selected.peek(), 2)
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([2]))
}

///|
test "nested activation of the selected option supersedes a pending group change" {
  let active : Ref[@runtime.UiRoot?] = Ref(None)
  let selected = @reactive.signal(0)
  let proposals : Array[Int32] = []
  let root = @runtime.mount(
    fn() {
      @controls.radio_group(
        selected,
        [0, 1],
        label=fn(value) { value.to_string() },
        item_style=@controls.RadioStyle().frame(
          @style.BoxStyle().width(160.0).height(30.0),
        ),
        on_change=fn(event) {
          proposals.push(event.value)
          ignore(
            active.val
            .unwrap()
            .click_at(
              size=Size(width=160.0, height=80.0),
              point=Point(x=8.0, y=12.0),
            ),
          )
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  active.val = Some(root)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyArrowRight)))
  assert_eq(selected.peek(), 0)
  assert_eq(proposals, [1])
  assert_eq(radio_test_focus(root), root.view().node_id_at_path([0]))
}
