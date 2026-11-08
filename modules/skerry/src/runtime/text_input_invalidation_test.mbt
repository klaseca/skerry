///|
test "cursor and selection repaint the input without reflow or text measurement" {
  let value = @reactive.signal("one two")
  let root = @runtime.mount(
    fn() { @controls.text_input(value~) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=40.0)
  let renderer = StyleRecorder()
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  for
    event in [
      test_key_event(KeyArrowLeft),
      test_shift_key_event(KeyHome),
      test_control_key_event(KeyA),
      test_key_event(KeyHome),
      test_control_key_event(KeyArrowRight),
    ] {
    assert_true(root.key_down(event))
    assert_eq(root.dirty(), NeedsPaint)
    assert_eq(root.snapshot(), None)
    root.paint(renderer, size~)
    let after = root.snapshot().unwrap()
    assert_eq(after.frame.layout_count, before.frame.layout_count)
    assert_eq(after.frame.text_measure_count, before.frame.text_measure_count)
    assert_eq(after.tree.nodes[0].id, before.tree.nodes[0].id)
    assert_eq(after.tree.nodes[0].frame, before.tree.nodes[0].frame)
    assert_eq(after.focused_node_id, before.focused_node_id)
    assert_eq(after.frame.last_paint.unwrap().layout_count, 0)
    assert_false(root.needs_frame())
  }
  assert_eq(wakeups.val, 5)
  assert_eq(value.get(), "one two")
  assert_true(root.key_down(test_shift_key_event(KeyEnd)))
  root.paint(renderer, size~)
  assert_eq(root.copy_text(), Some("two"))
  assert_true(
    renderer.fills.any(fill => {
      fill.0 == root.theme().resolve(@style.selection_token)
    }),
  )
  assert_false(root.needs_frame())
}

///|
test "navigation bounds repeated selection empty edits copy and submit remain idle" {
  let changes = Ref(0)
  let submissions = Ref(0)
  let value = @reactive.signal("abc")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(value~, on_change=fn(_) { changes.val += 1 }, on_submit=fn(
        _,
      ) {
        submissions.val += 1
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=150.0, height=40.0)
  let renderer = StyleRecorder()
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  for
    event in [
      test_key_event(KeyEnd),
      test_key_event(KeyArrowRight),
      test_shift_key_event(KeyArrowRight),
      test_key_event(KeyDelete),
      test_key_event(KeyEnter),
    ] {
    assert_true(root.key_down(event))
    assert_false(root.needs_frame())
    assert_eq(root.snapshot(), Some(before))
  }
  assert_eq(root.copy_text(), None)
  assert_eq(root.cut_text(), None)
  assert_false(root.paste_text(""))
  assert_false(root.text_input(""))
  assert_eq(changes.val, 0)
  assert_eq(submissions.val, 1)
  assert_eq(wakeups.val, 0)
  assert_true(root.key_down(test_key_event(KeyHome)))
  root.paint(renderer, size~)
  for
    event in [
      test_key_event(KeyHome),
      test_key_event(KeyArrowLeft),
      test_shift_key_event(KeyArrowLeft),
      test_key_event(KeyBackspace),
    ] {
    assert_true(root.key_down(event))
    assert_false(root.needs_frame())
  }
  assert_true(root.key_down(test_control_key_event(KeyA)))
  root.paint(renderer, size~)
  assert_true(root.key_down(test_control_key_event(KeyA)))
  assert_eq(root.copy_text(), Some("abc"))
  assert_false(root.needs_frame())
  assert_eq(changes.val, 0)
  assert_eq(wakeups.val, 2)
}

///|
test "replacing a selection with identical text only repaints and does not emit on_change" {
  let value = @reactive.signal("abc")
  let changes = Ref(0)
  let root = @runtime.mount(
    fn() { @controls.text_input(value~, on_change=fn(_) { changes.val += 1 }) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=40.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  let before = root.frame_stats()
  for paste in [true, false] {
    assert_true(root.key_down(test_control_key_event(KeyA)))
    root.paint(renderer, size~)
    assert_eq(root.copy_text(), Some("abc"))
    assert_true(
      if paste {
        root.paste_text("abc")
      } else {
        root.text_input("abc")
      },
    )
    assert_eq(root.dirty(), NeedsPaint)
    root.paint(renderer, size~)
    assert_eq(root.copy_text(), None)
    assert_eq(root.frame_stats().layout_count, before.layout_count)
    assert_eq(root.frame_stats().text_measure_count, before.text_measure_count)
    assert_false(root.needs_frame())
  }
  assert_eq(value.get(), "abc")
  assert_eq(changes.val, 0)
}

///|
test "text insert delete cut paste and external values retain layout invalidation" {
  let value = @reactive.signal("abc")
  let changes : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @controls.text_input(value~, on_change=fn(text) {
        changes.push(text.value)
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=40.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  let initial = root.frame_stats()
  assert_true(root.text_input("d"))
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].text, "abcd")
  assert_true(root.key_down(test_key_event(KeyBackspace)))
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].text, "abc")
  assert_true(root.key_down(test_control_key_event(KeyA)))
  root.paint(renderer, size~)
  assert_eq(root.cut_text(), Some("abc"))
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  assert_eq(value.get(), "")
  assert_true(root.paste_text("next"))
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].text, "next")
  value.set("outside")
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].text, "outside")
  assert_eq(root.frame_stats().layout_count, initial.layout_count + 5)
  assert_eq(changes, ["abcd", "abc", "", "next"])
  assert_false(root.needs_frame())
}

///|
test "external truncation and equal text keep clamped cursor no-ops idle" {
  let value = @reactive.signal("abcdef")
  let root = @runtime.mount(
    fn() { @controls.text_input(value~) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=40.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  value.set("a")
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  assert_true(root.key_down(test_key_event(KeyArrowRight)))
  assert_true(root.key_down(test_key_event(KeyDelete)))
  assert_eq(root.copy_text(), None)
  value.set("\{value.get()}")
  assert_false(root.needs_frame())
  assert_eq(root.snapshot(), Some(before))
}

///|
test "input submit callback can repaint another control without reflow" {
  let checked = @reactive.signal(false)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.text_input(on_submit=fn(_) { checked.set(true) }),
        @controls.checkbox(checked~),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=90.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  let before = root.frame_stats()
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_true(checked.get())
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  assert_eq(root.frame_stats().layout_count, before.layout_count)
  assert_false(root.needs_frame())
}

///|
test "removed input stops selection and text subscriptions" {
  let visible = @reactive.signal(true)
  let value = @reactive.signal("abc")
  let input : Ref[@view.View?] = Ref(None)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        let view = @controls.text_input(value~)
        input.val = Some(view)
        view
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=40.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  visible.set(false)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  assert_true(input.val.unwrap().key_down_path([], test_key_event(KeyHome)))
  value.set("detached")
  assert_false(root.needs_frame())
  assert_eq(root.snapshot(), Some(before))
}

///|
test "custom host receives input invalidation through View.mount_reactivity" {
  let scope = @reactive.Scope::root()
  defer scope.dispose()
  let value = @reactive.signal("abc")
  let view = scope.run(fn() { @controls.text_input(value~) })
  let layout = @view.LayoutState(text_layout_system=test_text_layout_system())
  defer layout.dispose()
  let notifications : Array[@runtime.DirtyState] = []
  let stop = scope.run(fn() {
    view.mount_reactivity(
      mark_layout_dirty=fn() {
        layout.invalidate()
        notifications.push(NeedsLayout)
      },
      mark_paint_dirty=fn() { notifications.push(NeedsPaint) },
    )
  })
  defer stop()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=40.0)
  layout.paint(view, size~, renderer, focused_path=Some([]))
  assert_eq(notifications, [])
  assert_true(view.key_down_path([], test_key_event(KeyHome)))
  assert_eq(notifications, [NeedsPaint])
  layout.paint(view, size~, renderer, focused_path=Some([]))
  assert_eq(layout.last_paint_stats().unwrap().layout_count, 0)
  assert_true(view.key_down_path([], test_key_event(KeyHome)))
  assert_eq(notifications, [NeedsPaint])
  assert_true(view.text_input_path([], "x"))
  assert_eq(notifications, [NeedsPaint, NeedsLayout])
  layout.paint(view, size~, renderer, focused_path=Some([]))
  assert_eq(renderer.text[0].text, "xabc")
  assert_eq(layout.last_paint_stats().unwrap().layout_count, 1)
  stop()
  value.set("detached")
  assert_true(view.key_down_path([], test_key_event(KeyEnd)))
  assert_eq(notifications, [NeedsPaint, NeedsLayout])
}

///|
test "cursor navigation updates horizontal text scrolling without reflow" {
  let root = @runtime.mount(
    fn() {
      @controls.text_input(value=@reactive.signal("abcdefghijklmnopqrst"))
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=40.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  let before = root.frame_stats()
  let scrolled = renderer.text[0].frame.origin.x
  assert_true(scrolled < 10.0)
  assert_true(root.key_down(test_key_event(KeyHome)))
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].frame.origin.x, 10.0)
  assert_true(root.key_down(test_key_event(KeyEnd)))
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].frame.origin.x, scrolled)
  assert_eq(root.frame_stats().layout_count, before.layout_count)
  assert_eq(root.frame_stats().text_measure_count, before.text_measure_count)
  assert_true(root.key_down(test_key_event(KeyEnd)))
  assert_false(root.needs_frame())
}

///|
test "cursor changes during paint defer the snapshot until a consistent frame" {
  let active : Ref[@runtime.UiRoot?] = Ref(None)
  let first = Ref(true)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.element(
          style=@style.BoxStyle(),
          painter=@view.Painter(fn(_, _) {
            if first.val {
              first.val = false
              ignore(active.val.unwrap().key_down(test_key_event(KeyHome)))
            }
          }),
        ),
        @controls.text_input(value=@reactive.signal("abc")),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  active.val = Some(root)
  assert_true(root.key_down(test_key_event(KeyTab)))
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=90.0)
  root.paint(renderer, size~)
  assert_eq(root.snapshot(), None)
  assert_eq(root.dirty(), NeedsPaint)
  let before = root.frame_stats()
  root.paint(renderer, size~)
  assert_true(root.snapshot() is Some(_))
  assert_eq(root.frame_stats().layout_count, before.layout_count)
  assert_eq(root.frame_stats().text_measure_count, before.text_measure_count)
  assert_false(root.needs_frame())
}
