///|
test "checkbox and radio instances own independent values in each root" {
  for radio in [false, true] {
    let changes : Array[Bool] = []
    let create = fn() {
      if radio {
        @controls.radio(on_change=fn(event) { changes.push(event.value) })
      } else {
        @controls.checkbox(on_change=fn(event) { changes.push(event.value) })
      }
    }
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
    let size = @foundation.Size(width=100.0, height=40.0)
    first.paint(text_color_recorder(), size~)
    second.paint(text_color_recorder(), size~)
    assert_true(first.key_down(test_key_event(KeyTab)))
    assert_true(first.key_down(test_key_event(KeySpace)))
    assert_false(second.needs_frame())
    assert_true(second.key_down(test_key_event(KeyTab)))
    assert_true(second.key_down(test_key_event(KeySpace)))
    assert_eq(changes, [true, true])
    first.dispose()
    if !radio {
      assert_true(second.key_down(test_key_event(KeySpace)))
      assert_eq(changes, [true, true, false])
    }
  }
}

///|
test "separate uncontrolled inputs has separate text selection and invalidation per root" {
  let proposals : Array[String] = []
  let create = fn() {
    @controls.text_input(on_change=fn(event) { proposals.push(event.value) })
  }
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
  let size = @foundation.Size(width=140.0, height=40.0)
  first.paint(text_color_recorder(), size~)
  second.paint(text_color_recorder(), size~)
  assert_true(first.key_down(test_key_event(KeyTab)))
  assert_true(first.text_input("first"))
  assert_false(second.needs_frame())
  assert_true(first.key_down(test_shift_key_event(KeyHome)))
  assert_eq(first.copy_text(), Some("first"))
  assert_true(second.key_down(test_key_event(KeyTab)))
  assert_eq(second.copy_text(), None)
  assert_true(second.text_input("second"))
  assert_eq(first.copy_text(), Some("first"))
  assert_eq(proposals, ["first", "second"])
  first.dispose()
  assert_true(second.text_input("!"))
  assert_eq(proposals, ["first", "second", "second!"])
}

///|
test "an external input value shared by two instances keeps caret and selection separate per root" {
  let value = @reactive.signal("abcd")
  let create = fn() { @controls.text_input(value~) }
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
  assert_true(first.key_down(test_key_event(KeyTab)))
  assert_true(second.key_down(test_key_event(KeyTab)))
  assert_true(first.key_down(test_shift_key_event(KeyHome)))
  assert_eq(first.copy_text(), Some("abcd"))
  assert_eq(second.copy_text(), None)
  assert_true(second.key_down(test_key_event(KeyHome)))
  assert_eq(first.copy_text(), Some("abcd"))
  assert_true(second.text_input("X"))
  assert_eq(value.peek(), "Xabcd")
  assert_eq(first.copy_text(), Some("Xabc"))
  assert_eq(second.copy_text(), None)
  assert_true(first.text_input("Y"))
  assert_eq(value.peek(), "Yd")
}

///|
test "creating fresh uncontrolled controls after disposal starts a fresh state lifetime" {
  for radio in [false, true] {
    let changes : Array[Bool] = []
    let create = fn() {
      if radio {
        @controls.radio(on_change=fn(event) { changes.push(event.value) })
      } else {
        @controls.checkbox(on_change=fn(event) { changes.push(event.value) })
      }
    }
    for _ in 0..<2 {
      let root = @runtime.mount(
        create,
        text_layout_system=test_text_layout_system(),
      )
      assert_true(root.key_down(test_key_event(KeyTab)))
      assert_true(root.key_down(test_key_event(KeySpace)))
      root.dispose()
    }
    assert_eq(changes, [true, true])
  }
  let proposals : Array[String] = []
  let create = fn() {
    @controls.text_input(on_change=fn(event) { proposals.push(event.value) })
  }
  for _ in 0..<2 {
    let root = @runtime.mount(
      create,
      text_layout_system=test_text_layout_system(),
    )
    assert_true(root.key_down(test_key_event(KeyTab)))
    assert_true(root.text_input("A"))
    root.dispose()
  }
  assert_eq(proposals, ["A", "A"])
}

///|
test "creating a fresh controlled input resets editor state and retains external text" {
  let value = @reactive.signal("abcd")
  let create = fn() { @controls.text_input(value~) }
  let first = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  assert_true(first.key_down(test_key_event(KeyTab)))
  assert_true(first.key_down(test_shift_key_event(KeyHome)))
  assert_eq(first.copy_text(), Some("abcd"))
  first.dispose()
  value.set("updated")
  let second = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  assert_true(second.key_down(test_key_event(KeyTab)))
  assert_eq(second.copy_text(), None)
  assert_true(second.text_input("!"))
  assert_eq(value.peek(), "updated!")
}

///|
test "separate input instances keep horizontal scroll separate between roots" {
  let value = @reactive.signal("one two three four five six seven")
  let create = fn() {
    @controls.text_input(
      value~,
      style=@controls.TextInputStyle().surface(@style.BoxStyle().width(95.0)),
    )
  }
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
  let size = @foundation.Size(width=95.0, height=40.0)
  let first_paint = text_color_recorder()
  let second_paint = text_color_recorder()
  assert_true(first.key_down(test_key_event(KeyTab)))
  assert_true(second.key_down(test_key_event(KeyTab)))
  assert_true(first.key_down(test_shift_key_event(KeyArrowLeft)))
  first.paint(first_paint, size~)
  let before = first_paint.runs[first_paint.runs.length() - 1]
  assert_true(before.frame.origin.x < 0.0)
  assert_true(second.key_down(test_key_event(KeyHome)))
  second.paint(second_paint, size~)
  let start = second_paint.runs[second_paint.runs.length() - 1]
  assert_eq(start.frame.origin.x, 10.0)
  assert_eq(first.copy_text(), Some("n"))
  first.mark_paint_dirty()
  first.paint(first_paint, size~)
  assert_eq(first_paint.runs[first_paint.runs.length() - 1], before)
  assert_eq(second.copy_text(), None)
}

///|
test "pointer selection in separate input instances has a separate drag lifetime per root" {
  let value = @reactive.signal("abcdef")
  let create = fn() {
    @controls.text_input(
      value~,
      style=@controls.TextInputStyle().surface(@style.BoxStyle().width(160.0)),
    )
  }
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
  let size = @foundation.Size(width=160.0, height=40.0)
  let point = fn(index) {
    @foundation.Point(x=test_text_input_x_for_caret("abcdef", index), y=12.0)
  }
  assert_true(first.pointer_down(size~, point=point(1)))
  assert_true(second.pointer_down(size~, point=point(3)))
  assert_true(second.pointer_up(size~, point=point(3)))
  assert_true(first.pointer_move(size~, point=point(5)))
  assert_eq(first.copy_text(), Some("bcde"))
  assert_eq(second.copy_text(), None)
  assert_true(first.pointer_up(size~, point=point(5)))
  assert_eq(first.copy_text(), Some("bcde"))
}

///|
test "shared explicit checkbox and radio signals stay shared after one root disposes" {
  for radio in [false, true] {
    let selected = @reactive.signal(false)
    let create = fn() {
      if radio {
        @controls.radio(selected~)
      } else {
        @controls.checkbox(checked=selected)
      }
    }
    let first = @runtime.mount(
      create,
      text_layout_system=test_text_layout_system(),
    )
    let second = @runtime.mount(
      create,
      text_layout_system=test_text_layout_system(),
    )
    defer second.dispose()
    let size = @foundation.Size(width=100.0, height=40.0)
    second.paint(text_color_recorder(), size~)
    assert_true(first.key_down(test_key_event(KeyTab)))
    assert_true(first.key_down(test_key_event(KeySpace)))
    assert_true(selected.peek())
    assert_eq(second.dirty(), NeedsPaint)
    first.dispose()
    selected.set(false)
    assert_true(second.key_down(test_key_event(KeyTab)))
    assert_true(second.key_down(test_key_event(KeySpace)))
    assert_true(selected.peek())
  }
}

///|
test "a fresh subtree starts with new uncontrolled state when recreated to the same root" {
  let visible = @reactive.signal(true)
  let checks : Array[Bool] = []
  let radios : Array[Bool] = []
  let edits : Array[String] = []
  let create = fn() {
    @view.column([
      @controls.checkbox(on_change=fn(event) { checks.push(event.value) }),
      @controls.radio(on_change=fn(event) { radios.push(event.value) }),
      @controls.text_input(on_change=fn(event) { edits.push(event.value) }),
    ])
  }
  let root = @runtime.mount(
    fn() { @view.show(fn() { visible.get() }, create) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  for _ in 0..<2 {
    assert_true(root.key_down(test_key_event(KeyTab)))
    assert_true(root.key_down(test_key_event(KeySpace)))
    assert_true(root.key_down(test_key_event(KeyTab)))
    assert_true(root.key_down(test_key_event(KeySpace)))
    assert_true(root.key_down(test_key_event(KeyTab)))
    assert_true(root.text_input("A"))
    assert_true(root.key_down(test_shift_key_event(KeyHome)))
    assert_eq(root.copy_text(), Some("A"))
    visible.set(false)
    assert_false(root.text_input("detached"))
    visible.set(true)
  }
  assert_eq(checks, [true, true])
  assert_eq(radios, [true, true])
  assert_eq(edits, ["A", "A"])
}

///|
test "keyed reorder retains control state and removing the key ends its lifetime" {
  let items = @reactive.signal([0, 1])
  let checks : Array[(Int32, Bool)] = []
  let edits : Array[(Int32, String)] = []
  let create = fn(key) {
    @view.column([
      @controls.checkbox(on_change=fn(event) { checks.push((key, event.value)) }),
      @controls.text_input(on_change=fn(event) {
        edits.push((key, event.value))
      }),
    ])
  }
  let renders = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.for_each(fn() { items.get() }, fn(key) { key }, fn(key) {
        renders.val += 1
        create(key())
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.text_input("abcd"))
  assert_true(root.key_down(test_shift_key_event(KeyArrowLeft)))
  assert_eq(root.copy_text(), Some("d"))
  let size = @foundation.Size(width=170.0, height=140.0)
  root.paint(text_color_recorder(), size~)
  let focused = root.snapshot().unwrap().focused_node_id
  items.set([1, 0])
  root.paint(text_color_recorder(), size~)
  assert_eq(root.snapshot().unwrap().focused_node_id, focused)
  assert_eq(root.copy_text(), Some("d"))
  assert_true(root.text_input("X"))
  assert_eq(edits, [(0, "abcd"), (0, "abcX")])
  assert_true(root.key_down(test_shift_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_eq(checks, [(0, true), (0, false)])
  assert_eq(renders.val, 2)
  items.set([1])
  items.set([0, 1])
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(root.copy_text(), None)
  assert_true(root.text_input("new"))
  assert_eq(checks, [(0, true), (0, false), (0, true)])
  assert_eq(edits, [(0, "abcd"), (0, "abcX"), (0, "new")])
  assert_eq(renders.val, 3)
}

///|
test "remount from a change handler cannot commit into the new editor state" {
  let visible = @reactive.signal(true)
  let remount = Ref(true)
  let edits : Array[String] = []
  let create = fn() {
    @controls.text_input(on_change=fn(event) {
      edits.push(event.value)
      if remount.val {
        remount.val = false
        visible.set(false)
        visible.set(true)
      }
    })
  }
  let root = @runtime.mount(
    fn() { @view.show(fn() { visible.get() }, create) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.text_input("discarded"))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(root.copy_text(), None)
  assert_true(root.text_input("accepted"))
  assert_eq(edits, ["discarded", "accepted"])
  assert_true(root.key_down(test_control_key_event(KeyA)))
  assert_eq(root.copy_text(), Some("accepted"))
}

///|
test "low level controls own editor state and dispose independently" {
  let edits : Array[String] = []
  let create = fn() {
    let view = @controls.text_input(on_change=fn(event) {
      edits.push(event.value)
    })
    let stop = view.mount_reactivity(mark_layout_dirty=fn() { () }, mark_paint_dirty=fn() {
      ()
    })
    (view, stop)
  }
  let (first, stop_first) = create()
  assert_true(first.text_input_path([], "first"))
  assert_true(first.key_down_path([], test_control_key_event(KeyA)))
  assert_eq(first.text_edit_path([], CopyText), TextEditText("first"))
  stop_first()
  let (second, stop_second) = create()
  defer stop_second()
  stop_first()
  assert_eq(second.text_edit_path([], CopyText), TextEditIgnored)
  assert_true(second.text_input_path([], "second"))
  assert_eq(edits, ["first", "second"])
}

///|
test "component function calls build independent control instances in each root" {
  let edits : Array[String] = []
  let create = fn() {
    @controls.text_input(on_change=fn(event) { edits.push(event.value) })
  }
  let first = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  let second = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  assert_true(first.key_down(test_key_event(KeyTab)))
  assert_true(first.text_input("first"))
  assert_true(second.key_down(test_key_event(KeyTab)))
  assert_true(second.text_input("second"))
  assert_eq(edits, ["first", "second"])
  first.dispose()
  assert_true(second.text_input("!"))
  assert_eq(edits, ["first", "second", "second!"])
}
