///|
fn controls_with_text(source : &@value.StringValue) -> @view.View {
  let style = @style.BoxStyle().height(40.0).shrink(0.0)
  @view.column([
    @controls.button(source, style=@controls.ButtonStyle().surface(style)),
    @controls.checkbox(
      label=source,
      style=@controls.CheckboxStyle().frame(style),
    ),
    @controls.radio(label=source, style=@controls.RadioStyle().frame(style)),
    @controls.text_input(
      placeholder=source,
      style=@controls.TextInputStyle().surface(style),
    ),
  ])
}

///|
test "control labels and placeholders accept all StringValue forms" {
  let title = @reactive.signal("before")
  let computed = @reactive.computed(fn() { title.get() })
  let views = [
    controls_with_text("literal"),
    controls_with_text(@reactive.val("constant")),
    controls_with_text(title),
    controls_with_text(computed),
    controls_with_text(title.bind()),
  ]
  let size = @foundation.Size(width=200.0, height=160.0)
  for index, view in views {
    let root = @runtime.mount(
      fn() { view },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let recorder = text_color_recorder()
    root.paint(recorder, size~)
    let expected = match index {
      0 => "literal"
      1 => "constant"
      _ => title.peek()
    }
    assert_eq(recorder.runs.map(run => run.text), [
      expected, expected, expected, expected,
    ])
    recorder.runs.clear()
    title.set("after")
    root.paint(recorder, size~)
    let expected = if index < 2 { expected } else { "after" }
    assert_eq(recorder.runs.map(run => run.text), [
      expected, expected, expected, expected,
    ])
    title.set("before")
  }
  ignore(@controls.checkbox())
  ignore(@controls.radio())
  ignore(@controls.text_input())
}

///|
test "control text is cold equal results stay idle and mounted operations never pull producers" {
  let count = @reactive.signal(0)
  let reads = Ref(0)
  let construction_reads = Ref(-1)
  let builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      builds.val += 1
      let view = controls_with_text(
        @reactive.bind(fn() {
          reads.val += 1
          (count.get() / 2).to_string()
        }),
      )
      construction_reads.val = reads.val
      view
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(construction_reads.val, 0)
  assert_eq(reads.val, 4)
  let recorder = text_color_recorder()
  let size = @foundation.Size(width=200.0, height=180.0)
  root.paint(recorder, size~)
  ignore(root.snapshot())
  ignore(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  ignore(root.pointer_up(size~, point=Point(x=10.0, y=10.0)))
  ignore(root.key_down(test_key_event(KeyTab)))
  root.paint(recorder, size=Size(width=240.0, height=200.0))
  root.mark_paint_dirty()
  root.paint(recorder, size~)
  assert_eq(reads.val, 4)
  let before = root.snapshot().unwrap()
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  count.set(1)
  assert_eq(reads.val, 8)
  assert_eq(root.dirty(), Clean)
  assert_eq(wakeups.val, 0)
  assert_eq(root.snapshot(), Some(before))
  count.set(2)
  assert_eq(root.dirty(), NeedsLayout)
  assert_eq(wakeups.val, 1)
  recorder.runs.clear()
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), ["1", "1", "1", "1"])
  assert_eq(reads.val, 12)
  assert_eq(
    root.snapshot().unwrap().tree.nodes.map(node => node.id),
    before.tree.nodes.map(node => node.id),
  )
  assert_eq(builds.val, 1)
  root.dispose()
  count.set(4)
  assert_eq(reads.val, 12)
}

///|
test "button label changes preserve focus pointer capture and keyboard press" {
  let label = @reactive.signal("before")
  let clicks = Ref(0)
  let blurs = Ref(0)
  let cancels = Ref(0)
  let root = @runtime.mount(
    fn() {
      @controls.button(
        label,
        on_click=fn() { clicks.val += 1 },
        on_blur=fn() { blurs.val += 1 },
        on_pointer_cancel=fn() { cancels.val += 1 },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = text_color_recorder()
  let size = @foundation.Size(width=200.0, height=40.0)
  root.paint(recorder, size~)
  let id = root.snapshot().unwrap().tree.nodes[0].id
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  label.set("during pointer press")
  root.paint(recorder, size~)
  let pressed = root.snapshot().unwrap()
  assert_eq(pressed.focused_node_id, Some(id))
  assert_eq(pressed.captured_node_id, Some(id))
  assert_true(pressed.tree.nodes[0].state.pressed)
  assert_true(root.pointer_up(size~, point=Point(x=10.0, y=10.0)))
  assert_eq(clicks.val, 1)
  assert_true(root.key_down(test_key_event(KeySpace)))
  label.set("during keyboard press")
  root.paint(recorder, size~)
  assert_true(root.snapshot().unwrap().tree.nodes[0].state.pressed)
  assert_eq(root.snapshot().unwrap().focused_node_id, Some(id))
  assert_true(root.key_up(test_key_event(KeySpace)))
  assert_eq(clicks.val, 2)
  assert_eq((blurs.val, cancels.val), (0, 0))
}

///|
test "label wrapping and empty choice labels remeasure without changing models or ids" {
  let label = @reactive.signal("")
  let checked = @reactive.signal(true)
  let selected = @reactive.signal(true)
  let root = @runtime.mount(
    fn() {
      let style = @style.BoxStyle().shrink(0.0)
      @view.column([
        @controls.button(label, style=@controls.ButtonStyle().surface(style)),
        @controls.checkbox(
          checked~,
          label~,
          style=@controls.CheckboxStyle().frame(style),
        ),
        @controls.radio(
          selected~,
          label~,
          style=@controls.RadioStyle().frame(style),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=600.0)
  let recorder = text_color_recorder()
  root.paint(recorder, size~)
  let before = root.snapshot().unwrap()
  assert_eq(before.tree.nodes[2].frame.size.height, 18.0)
  assert_eq(before.tree.nodes[3].frame.size.height, 18.0)
  label.set("a long label that wraps over several lines")
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(recorder, size~)
  let after = root.snapshot().unwrap()
  for index in 1..<4 {
    assert_eq(after.tree.nodes[index].id, before.tree.nodes[index].id)
    assert_true(
      after.tree.nodes[index].frame.size.height >
      before.tree.nodes[index].frame.size.height,
    )
  }
  assert_true(checked.peek())
  assert_true(selected.peek())
  label.set("")
  recorder.runs.clear()
  root.paint(recorder, size~)
  let empty = root.snapshot().unwrap()
  assert_eq(empty.tree.nodes[2].frame, before.tree.nodes[2].frame)
  assert_eq(empty.tree.nodes[3].frame, before.tree.nodes[3].frame)
  assert_false(recorder.runs.any(run => !run.text.is_empty()))
}

///|
test "hidden placeholder updates stay idle preserve selection and appear after clearing" {
  let placeholder = @reactive.signal("first placeholder")
  let value = @reactive.signal("abcd")
  let changes : Array[String] = []
  let blurs = Ref(0)
  let root = @runtime.mount(
    fn() {
      @controls.text_input(
        value~,
        placeholder~,
        on_change=fn(next) { changes.push(next.value) },
        on_blur=fn() { blurs.val += 1 },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = text_color_recorder()
  let size = @foundation.Size(width=240.0, height=40.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_shift_key_event(KeyArrowLeft)))
  assert_true(root.key_down(test_shift_key_event(KeyArrowLeft)))
  root.paint(recorder, size~)
  assert_eq(root.copy_text(), Some("cd"))
  let before = root.snapshot().unwrap()
  let wakeups = Ref(0)
  root.set_wakeup(fn() { wakeups.val += 1 })
  placeholder.set("latest placeholder")
  assert_eq(root.dirty(), Clean)
  assert_eq(wakeups.val, 0)
  assert_eq(root.snapshot(), Some(before))
  assert_eq(root.copy_text(), Some("cd"))
  assert_true(root.text_input("X"))
  assert_eq(value.peek(), "abX")
  root.paint(recorder, size~)
  assert_eq(root.snapshot().unwrap().focused_node_id, before.focused_node_id)
  assert_true(root.key_down(test_key_event(KeyArrowLeft)))
  placeholder.set("newest placeholder")
  assert_true(root.text_input("Y"))
  assert_eq(value.peek(), "abYX")
  assert_true(root.key_down(test_control_key_event(KeyA)))
  assert_true(root.key_down(test_key_event(KeyBackspace)))
  recorder.runs.clear()
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), ["newest placeholder"])
  assert_eq(changes, ["abX", "abYX", ""])
  assert_eq(blurs.val, 0)
  assert_eq(root.snapshot().unwrap().tree.nodes[0].id, before.tree.nodes[0].id)
  let layouts = root.frame_stats().layout_count
  placeholder.set("visible update")
  assert_eq(root.dirty(), NeedsLayout)
  recorder.runs.clear()
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), ["visible update"])
  assert_eq(root.frame_stats().layout_count, layouts + 1)
}

///|
test "radio group label factories run once and accept reactive results" {
  let selected = @reactive.signal(1)
  let prefix = @reactive.signal("option")
  let builds = Ref(0)
  let reads = Ref(0)
  let root = @runtime.mount(
    fn() {
      @controls.radio_group(selected, [1, 2], label=fn(option) {
        builds.val += 1
        @reactive.bind(fn() {
          reads.val += 1
          "\{prefix.get()} \{option}"
        })
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = text_color_recorder()
  let size = @foundation.Size(width=200.0, height=100.0)
  root.paint(recorder, size~)
  let ids = root.snapshot().unwrap().tree.nodes.map(node => node.id)
  assert_eq(recorder.runs.map(run => run.text), ["option 1", "option 2"])
  prefix.set("new")
  selected.set(2)
  recorder.runs.clear()
  root.paint(recorder, size~)
  assert_eq(recorder.runs.map(run => run.text), ["new 1", "new 2"])
  assert_eq(root.snapshot().unwrap().tree.nodes.map(node => node.id), ids)
  assert_eq((builds.val, reads.val, selected.peek()), (2, 4, 2))
  let static_label : (Int32) -> String = option => option.to_string()
  ignore(@controls.radio_group(selected, [1, 2], label=static_label))
  ignore(@controls.radio_group(selected, [1, 2], label=fn(_) { prefix }))
  ignore(
    @controls.radio_group(selected, [1, 2], label=fn(option) {
      @reactive.computed(fn() { "\{prefix.get()} \{option}" })
    }),
  )
}

///|
test "control instances keep independent applied strings and root subscriptions" {
  let key = @reactive.Context(@reactive.signal("default"))
  let one = @reactive.signal("one")
  let two = @reactive.signal("two")
  let reads = Ref(0)
  let create = fn() {
    controls_with_text(
      @reactive.bind(fn() {
        reads.val += 1
        key.get().get()
      }),
    )
  }
  let a = @runtime.mount(
    create,
    providers=[key.provide(one)],
    text_layout_system=test_text_layout_system(),
  )
  defer a.dispose()
  let b = @runtime.mount(
    create,
    providers=[key.provide(two)],
    text_layout_system=test_text_layout_system(),
  )
  defer b.dispose()
  let size = @foundation.Size(width=240.0, height=160.0)
  let first = text_color_recorder()
  let second = text_color_recorder()
  a.paint(first, size~)
  b.paint(second, size~)
  assert_eq(first.runs.map(run => run.text), ["one", "one", "one", "one"])
  assert_eq(second.runs.map(run => run.text), ["two", "two", "two", "two"])
  one.set("updated")
  assert_eq(a.dirty(), NeedsLayout)
  assert_eq(b.dirty(), Clean)
  a.dispose()
  one.set("ignored")
  two.set("still live")
  second.runs.clear()
  b.paint(second, size~)
  assert_eq(second.runs.map(run => run.text), [
    "still live", "still live", "still live", "still live",
  ])
  assert_eq(reads.val, 16)
}

///|
test "detaching controls releases text subscriptions and remount samples once" {
  let visible = @reactive.signal(true)
  let value = @reactive.signal("before")
  let reads = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        controls_with_text(
          @reactive.bind(fn() {
            reads.val += 1
            value.get()
          }),
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(reads.val, 4)
  visible.set(false)
  value.set("hidden")
  assert_eq(reads.val, 4)
  visible.set(true)
  assert_eq(reads.val, 8)
  let recorder = text_color_recorder()
  root.paint(recorder, size=Size(width=200.0, height=160.0))
  assert_eq(recorder.runs.map(run => run.text), [
    "hidden", "hidden", "hidden", "hidden",
  ])
  assert_eq(reads.val, 8)
}

///|
test "frame wakeup sees final control strings after a batch" {
  let label = @reactive.signal("before")
  let placeholder = @reactive.signal("old hint")
  let value = @reactive.signal("filled")
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button(label),
        @controls.checkbox(label~),
        @controls.radio(label~),
        @controls.text_input(value~, placeholder~),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=160.0)
  root.paint(text_color_recorder(), size~)
  let frames : Array[Array[String]] = []
  root.set_wakeup(fn() {
    let recorder = text_color_recorder()
    root.paint(recorder, size~)
    frames.push(recorder.runs.map(run => run.text))
  })
  @reactive.batch(fn() {
    label.set("after")
    placeholder.set("new hint")
    value.set("")
  })
  assert_eq(frames, [["after", "after", "after", "new hint"]])
}

///|
test "standalone controls sample once and mounted low level hosts reuse applied strings" {
  let value = @reactive.signal("before")
  let reads = Ref(0)
  let view = controls_with_text(
    @reactive.bind(fn() {
      reads.val += 1
      value.get()
    }),
  )
  let size = @foundation.Size(width=200.0, height=160.0)
  ignore(view.layout(size~, text_layout_system=test_text_layout_system()))
  assert_eq(reads.val, 4)
  let state = @view.LayoutState(text_layout_system=test_text_layout_system())
  defer state.dispose()
  let recorder = text_color_recorder()
  state.paint(view, size~, recorder, focused_path=None)
  assert_eq(reads.val, 8)
  let scope = @reactive.Scope::root()
  defer scope.dispose()
  let stop = scope.run(fn() {
    view.mount_reactivity(mark_layout_dirty=fn() { state.invalidate() }, mark_paint_dirty=fn() {
      ()
    })
  })
  defer stop()
  assert_eq(reads.val, 12)
  state.paint(view, size~, recorder, focused_path=None)
  assert_eq(reads.val, 12)
  value.set("after")
  recorder.runs.clear()
  state.paint(view, size~, recorder, focused_path=None)
  assert_eq(recorder.runs.map(run => run.text), [
    "after", "after", "after", "after",
  ])
  assert_eq(reads.val, 16)
  stop()
  value.set("unmounted")
  assert_eq(reads.val, 16)
  state.invalidate()
  recorder.runs.clear()
  state.paint(view, size~, recorder, focused_path=None)
  assert_eq(recorder.runs.map(run => run.text), [
    "unmounted", "unmounted", "unmounted", "unmounted",
  ])
  assert_eq(reads.val, 20)
}
