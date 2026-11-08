///|
test "button callback can be hit tested from laid out view" {
  let clicked = Ref(0)
  let view : @view.View = @controls.button("Increment", on_click=fn() {
    clicked.val = clicked.val + 1
  })
  assert_true(
    view.click_at(
      size=Size(width=120.0, height=40.0),
      point=Point(x=10.0, y=10.0),
      text_layout_system=test_text_layout_system(),
    ),
  )
  inspect(clicked.val, content="1")
  assert_true(
    !view.click_at(
      size=Size(width=120.0, height=40.0),
      point=Point(x=200.0, y=10.0),
      text_layout_system=test_text_layout_system(),
    ),
  )
  inspect(clicked.val, content="1")
}

///|
test "interactive exposes click focus and keyboard events" {
  let clicked = Ref(0)
  let focused = Ref(0)
  let blurred = Ref(0)
  let key_down = Ref(0)
  let view = @view.interactive(
    on_click=fn() { clicked.val = clicked.val + 1 },
    on_focus=fn() { focused.val = focused.val + 1 },
    on_blur=fn() { blurred.val = blurred.val + 1 },
    on_key_down=fn(event) {
      if event.key == KeyEnter {
        key_down.val = key_down.val + 1
      }
    },
  ) <| @view.box(style=@style.BoxStyle().width(80.0).height(32.0))
  let root = @runtime.mount(
    fn() { view },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=120.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  inspect(clicked.val, content="1")
  inspect(focused.val, content="1")
  assert_true(root.key_down(test_key_event(KeyEnter)))
  inspect(key_down.val, content="1")
  assert_true(!root.click_at(size~, point=Point(x=200.0, y=80.0)))
  inspect(blurred.val, content="1")
  root.dispose()
}

///|
test "interactive is focusable by default" {
  let focused = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.interactive(on_focus=fn() { focused.val = focused.val + 1 }) <| @view.box(
        style=@style.BoxStyle().width(80.0).height(32.0),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  assert_true(
    root.click_at(
      size=Size(width=120.0, height=60.0),
      point=Point(x=10.0, y=10.0),
    ),
  )
  inspect(focused.val, content="1")
  root.dispose()
}

///|
test "interactive activates click from keyboard" {
  let clicked = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.interactive(on_click=fn() { clicked.val = clicked.val + 1 }) <| @view.box(
        style=@style.BoxStyle().width(80.0).height(32.0),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_true(root.key_down(test_key_event(KeySpace)))
  inspect(clicked.val, content="2")
  root.dispose()
}

///|
test "interactive pointer arguments receive local pointer events" {
  let down = Ref(0)
  let moved = Ref(0)
  let up = Ref(0)
  let local_x = Ref(0.0)
  let view = @view.interactive(
    on_pointer_down=fn(event) {
      if event.phase == PointerDown {
        down.val = down.val + 1
        local_x.val = event.position.x
      }
    },
    on_pointer_move=fn(event) {
      if event.phase == PointerMove {
        moved.val = moved.val + 1
      }
    },
    on_pointer_up=fn(event) {
      if event.phase == PointerUp {
        up.val = up.val + 1
      }
    },
  ) <| @view.box(style=@style.BoxStyle().width(80.0).height(32.0))
  let root = @runtime.mount(
    fn() { view },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=120.0, height=60.0)
  assert_true(root.pointer_down(size~, point=Point(x=12.0, y=10.0)))
  assert_true(root.pointer_move(size~, point=Point(x=18.0, y=10.0)))
  assert_true(root.pointer_up(size~, point=Point(x=18.0, y=10.0)))
  inspect(down.val, content="1")
  inspect(moved.val, content="1")
  inspect(up.val, content="1")
  inspect(local_x.val, content="12")
  root.dispose()
}

///|
test "disabled argument removes interaction and focus" {
  let clicked = Ref(0)
  let view = @controls.button(
    "Disabled",
    on_click=fn() { clicked.val = clicked.val + 1 },
    disabled=true,
  )
  let root = @runtime.mount(
    fn() { view },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=160.0, height=60.0)
  assert_true(!root.click_at(size~, point=Point(x=10.0, y=10.0)))
  inspect(clicked.val, content="0")
  assert_true(!root.key_down(test_key_event(KeyEnter)))
  root.dispose()
}

///|
test "disabled containers exclude descendants from every input path" {
  let callbacks = Ref(0)
  let value = @reactive.signal("abc")
  let style = @style.BoxStyle().width(120.0).height(32.0)
  let content = @view.column([
    @controls.button(
      "Run",
      style=@controls.ButtonStyle().surface(style),
      on_click=fn() { callbacks.val += 1 },
      on_focus=fn() { callbacks.val += 1 },
      on_pointer_down=fn(_) { callbacks.val += 1 },
      on_pointer_move=fn(_) { callbacks.val += 1 },
      on_pointer_up=fn(_) { callbacks.val += 1 },
    ),
    @controls.text_input(
      value~,
      style=@controls.TextInputStyle().surface(style),
      on_change=fn(_) { callbacks.val += 1 },
    ),
  ])
  let paths = content.focusable_paths()
  assert_eq(paths.length(), 2)
  let disabled = @view.interactive(content, disabled=true)
  let size = @foundation.Size(width=160.0, height=80.0)
  let state = @view.LayoutState(text_layout_system=test_text_layout_system())
  assert_eq(disabled.focusable_paths().length(), 0)
  assert_false(disabled.focus_path(paths[0]))
  assert_false(disabled.key_down_path(paths[0], test_key_event(KeyEnter)))
  assert_false(disabled.text_input_path(paths[1], "x"))
  assert_eq(disabled.text_edit_path(paths[1], PasteText("x")), TextEditIgnored)
  assert_false(
    state.pointer_down_path(
      disabled,
      size~,
      paths[0],
      point=Point(x=10.0, y=10.0),
    ),
  )
  assert_false(
    state.pointer_move_path(
      disabled,
      size~,
      paths[0],
      point=Point(x=15.0, y=10.0),
    ),
  )
  assert_false(
    state.pointer_up_path(
      disabled,
      size~,
      paths[0],
      point=Point(x=15.0, y=10.0),
    ),
  )
  assert_false(state.click_at(disabled, size~, point=Point(x=10.0, y=10.0)))
  assert_eq(callbacks.val, 0)
  assert_eq(value.get(), "abc")
  let enabled_layout = content.layout(
    size~,
    text_layout_system=test_text_layout_system(),
  )
  let disabled_layout = disabled.layout(
    size~,
    text_layout_system=test_text_layout_system(),
  )
  assert_eq(
    enabled_layout.children.map(child => (child.width, child.height)),
    disabled_layout.children.map(child => (child.width, child.height)),
  )
  let recorder = text_color_recorder()
  state.paint(disabled, size~, recorder, focused_path=None)
  assert_eq(recorder.runs.map(run => run.text), ["Run", "abc"])
}

///|
test "interactive wrappers preserve disabled controls" {
  for kind in ["button", "checkbox", "radio", "radio group", "input"] {
    for depth in [0, 1, 2] {
      let callbacks = Ref(0)
      let value = @reactive.signal("abc")
      let checked = @reactive.signal(false)
      let selected = @reactive.signal(false)
      let group_value = @reactive.signal(0)
      let style = @style.BoxStyle().width(120.0).height(32.0)
      let mut control = match kind {
        "button" =>
          @controls.button(
            "Run",
            style=@controls.ButtonStyle().surface(style),
            on_click=fn() { callbacks.val += 1 },
            disabled=true,
          )
        "checkbox" =>
          @controls.checkbox(
            checked~,
            style=@controls.CheckboxStyle().frame(style),
            disabled=true,
          )
        "radio" =>
          @controls.radio(
            selected~,
            style=@controls.RadioStyle().frame(style),
            disabled=true,
          )
        "radio group" =>
          @controls.radio_group(
            group_value,
            [0, 1],
            label=fn(_) { "Option" },
            style=@view.FlexStyle().surface(style),
            item_style=@controls.RadioStyle().frame(style),
            disabled=true,
          )
        _ =>
          @controls.text_input(
            value~,
            style=@controls.TextInputStyle().surface(style),
            disabled=true,
          )
      }
      for _ in 0..<depth {
        control = @view.interactive(
          control,
          on_click=fn() { callbacks.val += 1 },
          on_pointer_down=fn(_) { callbacks.val += 1 },
        )
      }
      let root = @runtime.mount(
        fn() { control },
        text_layout_system=test_text_layout_system(),
      )
      defer root.dispose()
      let size = @foundation.Size(width=160.0, height=60.0)
      assert_false(root.click_at(size~, point=Point(x=10.0, y=10.0)))
      assert_false(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
      assert_false(root.pointer_up(size~, point=Point(x=10.0, y=10.0)))
      assert_false(root.key_down(test_key_event(KeyTab)))
      assert_false(root.text_input("x"))
      assert_eq(callbacks.val, 0)
      assert_eq(value.get(), "abc")
      assert_false(checked.get())
      assert_false(selected.get())
      assert_eq(group_value.get(), 0)
    }
  }
}

///|
test "disabled layers block only their frame and respect stack order" {
  let behind = Ref(0)
  let front = Ref(0)
  let size = @foundation.Size(width=120.0, height=64.0)
  let back = @controls.button(
    "Behind",
    style=@controls.ButtonStyle().surface(
      @style.BoxStyle().width(120.0).height(64.0),
    ),
    on_click=fn() { behind.val += 1 },
  )
  let disabled = @view.interactive(
    @view.column(
      [@controls.button("Disabled")],
      style=@view.FlexStyle().surface(
        @style.BoxStyle().width(60.0).height(32.0),
      ),
    ),
    disabled=true,
  )
  let covered = @view.interactive(@view.stack([back, disabled]), on_click=fn() {
    behind.val += 100
  })
  assert_false(
    covered.click_at(
      size~,
      point=Point(x=10.0, y=10.0),
      text_layout_system=test_text_layout_system(),
    ),
  )
  assert_eq(behind.val, 0)
  assert_true(
    covered.click_at(
      size~,
      point=Point(x=90.0, y=45.0),
      text_layout_system=test_text_layout_system(),
    ),
  )
  assert_eq(behind.val, 1)
  let top = @controls.button(
    "Front",
    style=@controls.ButtonStyle().surface(
      @style.BoxStyle().width(20.0).height(20.0),
    ),
    on_click=fn() { front.val += 1 },
  )
  let stacked = @view.stack([covered, top])
  assert_true(
    stacked.click_at(
      size~,
      point=Point(x=10.0, y=10.0),
      text_layout_system=test_text_layout_system(),
    ),
  )
  assert_eq(front.val, 1)
  assert_eq(behind.val, 1)
}

///|
test "wrapped controls activate the same callback chain from mouse and keyboard" {
  for kind in ["button", "checkbox", "radio"] {
    for depth in [1, 2] {
      for input in ["pointer", "click", "enter", "space"] {
        let calls : Array[String] = []
        let keys = Ref(0)
        let checked = @reactive.signal(false)
        let selected = @reactive.signal(false)
        let style = @style.BoxStyle().width(120.0).height(32.0)
        let on_key_down = fn(_) { keys.val += 1 }
        let mut control = match kind {
          "button" =>
            @controls.button(
              "Run",
              style=@controls.ButtonStyle().surface(style),
              on_key_down~,
              on_click=fn() { calls.push("control") },
            )
          "checkbox" =>
            @controls.checkbox(
              checked~,
              style=@controls.CheckboxStyle().frame(style),
              on_key_down~,
              on_change=fn(_) { calls.push("control") },
            )
          _ =>
            @controls.radio(
              selected~,
              style=@controls.RadioStyle().frame(style),
              on_key_down~,
              on_change=fn(_) { calls.push("control") },
            )
        }
        for index in 0..<depth {
          control = @view.interactive(control, on_key_down~, on_click=fn() {
            calls.push("wrapper \{index}")
          })
        }
        let root = @runtime.mount(
          fn() { control },
          text_layout_system=test_text_layout_system(),
        )
        defer root.dispose()
        let size = @foundation.Size(width=160.0, height=60.0)
        let point = @foundation.Point(x=10.0, y=10.0)
        match input {
          "pointer" => {
            assert_true(root.pointer_down(size~, point~))
            assert_true(root.pointer_up(size~, point~))
          }
          "click" => assert_true(root.click_at(size~, point~))
          _ => {
            assert_true(root.key_down(test_key_event(KeyTab)))
            assert_true(
              root.key_down(
                test_key_event(
                  if input == "enter" {
                    KeyEnter
                  } else {
                    KeySpace
                  },
                ),
              ),
            )
          }
        }
        let expected = ["control"]
        for index in 0..<depth {
          expected.push("wrapper \{index}")
        }
        assert_eq(calls, expected)
        assert_eq(
          keys.val,
          if input == "enter" || input == "space" {
            depth + 1
          } else {
            0
          },
        )
        if kind == "checkbox" {
          assert_true(checked.get())
        }
        if kind == "radio" {
          assert_true(selected.get())
        }
      }
    }
  }
}
