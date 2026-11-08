///|
test "checkbox proposals precede writes cancellation is per event and external writes are silent" {
  let checked = @reactive.signal(false)
  let observed : Array[Bool] = []
  let stop = @reactive.effect(fn() { observed.push(checked.get()) })
  defer stop()
  let cancel = Ref(true)
  let proposals : Array[(Bool, Bool)] = []
  let events : Array[@foundation.ChangeEvent[Bool]] = []
  let root = @runtime.mount(
    fn() {
      @controls.checkbox(checked~, on_change=fn(event) {
        proposals.push((checked.peek(), event.value))
        events.push(event)
        if cancel.val {
          event.prevent_default()
          event.prevent_default()
        }
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(proposals.length(), 0)
  checked.set(true)
  checked.set(false)
  assert_eq(proposals.length(), 0)
  assert_eq(observed, [false, true, false])
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_false(checked.peek())
  assert_eq(observed, [false, true, false])
  assert_true(events[0].default_prevented())
  cancel.val = false
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_true(checked.peek())
  events[1].prevent_default()
  assert_true(checked.peek())
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_false(checked.peek())
  assert_eq(proposals, [(false, true), (false, true), (true, false)])
  assert_false(events[2].default_prevented())
}

///|
test "radio and generic radio group cancel before selecting and ignore selected values" {
  let cancel = Ref(true)
  let selected = @reactive.signal(false)
  let radio_values : Array[(Bool, Bool)] = []
  let radio = @runtime.mount(
    fn() {
      @controls.radio(selected~, on_change=fn(event) {
        radio_values.push((selected.peek(), event.value))
        if cancel.val {
          event.prevent_default()
        }
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer radio.dispose()
  assert_true(radio.key_down(test_key_event(KeyTab)))
  assert_true(radio.key_down(test_key_event(KeySpace)))
  assert_false(selected.peek())
  cancel.val = false
  assert_true(radio.key_down(test_key_event(KeyEnter)))
  assert_true(radio.key_down(test_key_event(KeySpace)))
  assert_eq(radio_values, [(false, true), (false, true)])
  let first = (1, "first")
  let second = (2, "second")
  let choice = @reactive.signal(first)
  let proposals : Array[((Int32, String), (Int32, String))] = []
  let group = @runtime.mount(
    fn() {
      @controls.radio_group(
        choice,
        [first, second],
        label=fn(option) { option.1 },
        on_change=fn(event) {
          proposals.push((choice.peek(), event.value))
          if cancel.val {
            event.prevent_default()
          }
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer group.dispose()
  assert_true(group.key_down(test_key_event(KeyTab)))
  assert_true(group.key_down(test_key_event(KeySpace)))
  assert_eq(proposals.length(), 0)
  cancel.val = true
  assert_true(group.key_down(test_key_event(KeyArrowRight)))
  assert_eq(choice.peek(), first)
  cancel.val = false
  assert_true(group.key_down(test_key_event(KeyEnter)))
  assert_eq(choice.peek(), second)
  assert_eq(proposals, [(first, second), (first, second)])
}

///|
test "handler writes replace defaults only when explicitly canceled" {
  let value = @reactive.signal("old")
  let replace = Ref(false)
  let seen : Array[(String, String)] = []
  let root = @runtime.mount(
    fn() {
      @controls.text_input(value~, on_change=fn(event) {
        seen.push((value.peek(), event.value))
        value.set("custom")
        if replace.val {
          event.prevent_default()
        }
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.text_input("!"))
  assert_eq(value.peek(), "old!")
  replace.val = true
  assert_true(root.text_input("?"))
  assert_eq(value.peek(), "custom")
  assert_eq(seen, [("old", "old!"), ("old!", "old!?")])
}

///|
test "controls without supplied signals keep their own state with optional veto" {
  let cancel = Ref(true)
  let checked : Array[Bool] = []
  let selected : Array[Bool] = []
  let text : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.checkbox(on_change=fn(event) {
          checked.push(event.value)
          if cancel.val {
            event.prevent_default()
          }
        }),
        @controls.radio(on_change=fn(event) {
          selected.push(event.value)
          if cancel.val {
            event.prevent_default()
          }
        }),
        @controls.text_input(on_change=fn(event) {
          text.push(event.value)
          if cancel.val {
            event.prevent_default()
          }
        }),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  for allowed in [false, true] {
    cancel.val = !allowed
    assert_true(root.key_down(test_key_event(KeyTab)))
    assert_true(root.key_down(test_key_event(KeySpace)))
    assert_true(root.key_down(test_key_event(KeyTab)))
    assert_true(root.key_down(test_key_event(KeySpace)))
    assert_true(root.key_down(test_key_event(KeyTab)))
    assert_true(root.text_input("A"))
  }
  assert_true(root.text_input("B"))
  assert_eq(checked, [true, true])
  assert_eq(selected, [true, true])
  assert_eq(text, ["A", "A", "AB"])
}

///|
test "canceled text edits preserve selection caret scroll and idle layout" {
  let value = @reactive.signal("one two three four five")
  let cancel = Ref(true)
  let proposals : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        style=@controls.TextInputStyle().surface(@style.BoxStyle().width(95.0)),
        on_change=fn(event) {
          proposals.push(event.value)
          if cancel.val {
            event.prevent_default()
          }
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=95.0, height=40.0)
  let recorder = text_color_recorder()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_shift_key_event(KeyArrowLeft)))
  root.paint(recorder, size~)
  let run = recorder.runs[recorder.runs.length() - 1]
  let snapshot = root.snapshot().unwrap()
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  assert_eq(root.copy_text(), Some("e"))
  for
    event in [
      test_key_event(KeyBackspace),
      test_key_event(KeyDelete),
      test_control_key_event(KeyBackspace),
      test_control_key_event(KeyDelete),
    ] {
    assert_true(root.key_down(event))
    assert_eq(value.peek(), "one two three four five")
    assert_eq(root.copy_text(), Some("e"))
    assert_false(root.needs_frame())
  }
  assert_true(root.text_input("X"))
  assert_true(root.paste_text("Y"))
  assert_eq(root.cut_text(), None)
  assert_eq(proposals.length(), 7)
  assert_eq(value.peek(), "one two three four five")
  assert_eq(root.copy_text(), Some("e"))
  assert_false(root.needs_frame())
  assert_eq(wakeups.val, 0)
  assert_eq(root.snapshot(), Some(snapshot))
  root.mark_paint_dirty()
  root.paint(recorder, size~)
  assert_eq(recorder.runs[recorder.runs.length() - 1], run)
  assert_eq(
    root.snapshot().unwrap().frame.layout_count,
    snapshot.frame.layout_count,
  )
  cancel.val = false
  assert_true(root.text_input("!"))
  assert_eq(value.peek(), "one two three four fiv!")
  assert_eq(root.copy_text(), None)
}

///|
test "canceled edits without a selection preserve word boundaries and caret" {
  let value = @reactive.signal("one two")
  let cancel = Ref(true)
  let proposed : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @controls.text_input(value~, on_change=fn(event) {
        proposed.push(event.value)
        if cancel.val {
          event.prevent_default()
        }
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyHome)))
  assert_true(root.key_down(test_control_key_event(KeyArrowRight)))
  assert_true(root.key_down(test_key_event(KeyDelete)))
  assert_true(root.key_down(test_control_key_event(KeyDelete)))
  assert_true(root.key_down(test_key_event(KeyBackspace)))
  assert_true(root.key_down(test_control_key_event(KeyBackspace)))
  assert_eq(proposed, ["one wo", "one ", "onetwo", "two"])
  assert_eq(value.peek(), "one two")
  cancel.val = false
  assert_true(root.text_input("X"))
  assert_eq(value.peek(), "one Xtwo")
}

///|
test "identical input replacement changes only selection without a proposal" {
  let proposals = Ref(0)
  let value = @reactive.signal("same")
  let root = @runtime.mount(
    fn() {
      @controls.text_input(value~, on_change=fn(_) { proposals.val += 1 })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=160.0, height=40.0)
  let recorder = text_color_recorder()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_control_key_event(KeyA)))
  root.paint(recorder, size~)
  let layout_count = root.snapshot().unwrap().frame.layout_count
  assert_true(root.text_input("same"))
  assert_eq(proposals.val, 0)
  assert_eq(root.copy_text(), None)
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(recorder, size~)
  assert_eq(root.snapshot().unwrap().frame.layout_count, layout_count)
  value.set("external")
  assert_eq(proposals.val, 0)
}

///|
test "nested input supersedes the outer proposal and commits text with its selection" {
  let active : Ref[@runtime.UiRoot?] = Ref(None)
  let value = @reactive.signal("ab")
  let proposals : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @controls.text_input(value~, on_change=fn(event) {
        proposals.push(event.value)
        if proposals.length() == 1 {
          ignore(active.val.unwrap().text_input("Y"))
        }
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  active.val = Some(root)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.text_input("X"))
  assert_eq(proposals, ["abX", "abY"])
  assert_eq(value.peek(), "abY")
  assert_true(root.text_input("Z"))
  assert_eq(value.peek(), "abYZ")
}

///|
test "handler navigation keeps its new caret when accepting a text edit" {
  let active : Ref[@runtime.UiRoot?] = Ref(None)
  let value = @reactive.signal("ab")
  let navigate = Ref(true)
  let root = @runtime.mount(
    fn() {
      @controls.text_input(value~, on_change=fn(_) {
        if navigate.val {
          ignore(active.val.unwrap().key_down(test_key_event(KeyHome)))
        }
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  active.val = Some(root)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.text_input("X"))
  assert_eq(value.peek(), "abX")
  navigate.val = false
  assert_true(root.text_input("Y"))
  assert_eq(value.peek(), "YabX")
}

///|
test "disposing a root in a change handler skips the default write" {
  let active : Ref[@runtime.UiRoot?] = Ref(None)
  let checked = @reactive.signal(false)
  let root = @runtime.mount(
    fn() {
      @controls.checkbox(checked~, on_change=fn(_) {
        active.val.unwrap().dispose()
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  active.val = Some(root)
  assert_true(root.key_down(test_key_event(KeyTab)))
  ignore(root.key_down(test_key_event(KeySpace)))
  assert_false(checked.peek())
  assert_false(root.needs_frame())
}

///|
test "disabling an ancestor from a proposal blocks the default write" {
  let disabled = @reactive.signal(false)
  let checked = @reactive.signal(false)
  let root = @runtime.mount(
    fn() {
      @view.column(
        [@controls.checkbox(checked~, on_change=fn(_) { disabled.set(true) })],
        disabled~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_false(checked.peek())
  assert_false(root.key_down(test_key_event(KeySpace)))
}

///|
test "removing and remounting a fresh View cannot revive a pending change" {
  let visible = @reactive.signal(true)
  let checked = @reactive.signal(false)
  let create = fn() {
    @controls.checkbox(checked~, on_change=fn(_) { visible.set(false) })
  }
  let root = @runtime.mount(
    fn() { @view.show(fn() { visible.get() }, create) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  ignore(root.key_down(test_key_event(KeySpace)))
  assert_false(checked.peek())
  visible.set(true)
  assert_eq(root.view().focusable_paths().length(), 1)
}

///|
test "component instances use their roots change target and callback context" {
  let dispose_here = @reactive.Context(false)
  let active : Ref[@runtime.UiRoot?] = Ref(None)
  let checked = @reactive.signal(false)
  let create = fn() {
    @controls.checkbox(checked~, on_change=fn(_) {
      if dispose_here.get() {
        active.val.unwrap().dispose()
      }
    })
  }
  let first = @runtime.mount(
    create,
    providers=[dispose_here.provide(true)],
    text_layout_system=test_text_layout_system(),
  )
  let second = @runtime.mount(
    create,
    providers=[dispose_here.provide(false)],
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  active.val = Some(first)
  assert_true(first.key_down(test_key_event(KeyTab)))
  ignore(first.key_down(test_key_event(KeySpace)))
  assert_false(checked.peek())
  assert_true(second.key_down(test_key_event(KeyTab)))
  assert_true(second.key_down(test_key_event(KeySpace)))
  assert_true(checked.peek())
}

///|
test "low level host disposal cancels a pending control update" {
  let stop = Ref(fn() { () })
  let checked = @reactive.signal(false)
  let view = @controls.checkbox(checked~, on_change=fn(_) { (stop.val)() })
  stop.val = view.mount_reactivity(mark_layout_dirty=fn() { () }, mark_paint_dirty=fn() {
    ()
  })
  assert_true(
    view.click_at(
      size=Size(width=120.0, height=40.0),
      point=Point(x=8.0, y=8.0),
      text_layout_system=test_text_layout_system(),
    ),
  )
  assert_false(checked.peek())
  (stop.val)()
}

///|
test "replacing a control inside its handler does not commit the old proposal" {
  let stop = Ref(fn() { () })
  let remount = Ref(fn() { () })
  let checked = @reactive.signal(false)
  let view = @controls.checkbox(checked~, on_change=fn(_) {
    (stop.val)()
    (remount.val)()
  })
  remount.val = fn() {
    let replacement = @controls.checkbox(checked~)
    stop.val = replacement.mount_reactivity(mark_layout_dirty=fn() { () }, mark_paint_dirty=fn() {
      ()
    })
  }
  stop.val = view.mount_reactivity(mark_layout_dirty=fn() { () }, mark_paint_dirty=fn() {
    ()
  })
  defer (stop.val)()
  assert_true(
    view.click_at(
      size=Size(width=120.0, height=40.0),
      point=Point(x=8.0, y=8.0),
      text_layout_system=test_text_layout_system(),
    ),
  )
  assert_false(checked.peek())
}

///|
test "sequential edits inside a batch each apply before returning" {
  let value = @reactive.signal("old")
  let seen : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @controls.text_input(value~, on_change=fn(_) { seen.push(value.peek()) })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  let during : Array[(Bool, String)] = []
  @reactive.batch(fn() {
    let first = root.text_input("X")
    during.push((first, value.peek()))
    let second = root.text_input("Y")
    during.push((second, value.peek()))
  })
  assert_eq(during, [(true, "oldX"), (true, "oldXY")])
  assert_eq(seen, ["old", "oldX"])
  assert_eq(value.peek(), "oldXY")
}

///|
test "change handler side effects and default state are materialized before wakeup" {
  let value = @reactive.signal("old")
  let message = @reactive.signal("before")
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.text_input(value~, on_change=fn(_) { message.set("after") }),
        @view.text(message),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=160.0, height=80.0)
  let recorder = text_color_recorder()
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(recorder, size~)
  let observations : Array[(String, String)] = []
  root.set_wakeup(fn() { observations.push((value.peek(), message.peek())) })
  assert_true(root.text_input("!"))
  assert_eq(observations, [("old!", "after")])
}
