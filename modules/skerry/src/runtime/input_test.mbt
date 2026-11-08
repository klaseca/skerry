///|
test "tab and shift tab move keyboard focus" {
  let focused : Array[String] = []
  let clicked : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.column(style=@view.FlexStyle().spacing(4.0)) <| [
        @controls.button(
          "One",
          on_click=fn() { clicked.push("one") },
          on_focus=fn() { focused.push("one") },
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(80.0).height(32.0),
          ),
        ),
        @controls.button(
          "Two",
          on_click=fn() { clicked.push("two") },
          on_focus=fn() { focused.push("two") },
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(80.0).height(32.0),
          ),
        ),
      ]
    },
    text_layout_system=test_text_layout_system(),
  )
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_true(root.key_down(test_shift_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  inspect(focused.join(","), content="one,two,one")
  inspect(clicked.join(","), content="one,two,one")
  root.dispose()
}

///|
test "shift tab focuses last element without current focus" {
  let focused : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.column(style=@view.FlexStyle().spacing(4.0)) <| [
        @controls.button(
          "One",
          on_focus=fn() { focused.push("one") },
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(80.0).height(32.0),
          ),
        ),
        @controls.button(
          "Two",
          on_focus=fn() { focused.push("two") },
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(80.0).height(32.0),
          ),
        ),
      ]
    },
    text_layout_system=test_text_layout_system(),
  )
  assert_true(root.key_down(test_shift_key_event(KeyTab)))
  inspect(focused.join(","), content="two")
  root.dispose()
}

///|
test "modified tab does not move keyboard focus" {
  let clicked : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.column(style=@view.FlexStyle().spacing(4.0)) <| [
        @controls.button(
          "One",
          on_click=fn() { clicked.push("one") },
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(80.0).height(32.0),
          ),
        ),
        @controls.button(
          "Two",
          on_click=fn() { clicked.push("two") },
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(80.0).height(32.0),
          ),
        ),
      ]
    },
    text_layout_system=test_text_layout_system(),
  )
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(!root.key_down(test_control_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  inspect(clicked.join(","), content="one")
  root.dispose()
}

///|
test "focused element ignores unhandled key" {
  let clicked = Ref(0)
  let root = @runtime.mount(
    fn() {
      @controls.button(
        "Run",
        on_click=fn() { clicked.val = clicked.val + 1 },
        style=@controls.ButtonStyle().surface(
          @style.BoxStyle().width(80.0).height(32.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=120.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  inspect(clicked.val, content="1")
  root.paint(TextRunRecorder::{ text: Ref(None), }, size~)
  assert_true(root.dirty() == Clean)
  assert_true(!root.key_down(test_key_event(KeyUnknown)))
  assert_true(root.dirty() == Clean)
  assert_true(root.key_down(test_key_event(KeyEnter)))
  inspect(clicked.val, content="2")
  root.dispose()
}

///|
test "escape clears focus when focused element does not handle it" {
  let clicked = Ref(0)
  let blurred = Ref(0)
  let cancelled = Ref(0)
  let root = @runtime.mount(
    fn() {
      @controls.button(
        "Run",
        on_click=fn() { clicked.val = clicked.val + 1 },
        on_blur=fn() { blurred.val = blurred.val + 1 },
        on_pointer_cancel=fn() { cancelled.val += 1 },
        style=@controls.ButtonStyle().surface(
          @style.BoxStyle().width(80.0).height(32.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=120.0, height=60.0)
  assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
  inspect(clicked.val, content="1")
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  inspect(blurred.val, content="1")
  assert_eq(cancelled.val, 1)
  assert_false(root.pointer_up(size~, point=Point(x=10.0, y=10.0)))
  assert_true(!root.key_down(test_key_event(KeyEnter)))
  inspect(clicked.val, content="1")
  root.dispose()
}

///|
test "key observer does not suppress default escape blur" {
  let observed = Ref(0)
  let blurred = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.interactive(
        on_blur=fn() { blurred.val = blurred.val + 1 },
        on_key_down=fn(event) {
          if event.key == KeyEscape {
            observed.val = observed.val + 1
          }
        },
      ) <| @view.box(style=@style.BoxStyle().width(80.0).height(32.0))
    },
    text_layout_system=test_text_layout_system(),
  )
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  inspect(observed.val, content="1")
  inspect(blurred.val, content="1")
  assert_true(!root.key_down(test_key_event(KeyEnter)))
  root.dispose()
}

///|
test "pointer up requires a matching press and consumes it once" {
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button(
          "Button",
          on_click=fn() { clicks.val += 1 },
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(80.0).height(32.0),
          ),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=100.0)
  let inside = @foundation.Point(x=10.0, y=10.0)
  assert_false(root.pointer_up(size~, point=inside))
  assert_false(root.pointer_down(size~, point=Point(x=150.0, y=80.0)))
  assert_false(root.pointer_up(size~, point=inside))
  assert_eq(clicks.val, 0)
  assert_true(root.pointer_down(size~, point=inside))
  assert_true(root.pointer_up(size~, point=inside))
  assert_false(root.pointer_up(size~, point=inside))
  assert_eq(clicks.val, 1)
  assert_true(root.click_at(size~, point=inside))
  assert_eq(clicks.val, 2)
}

///|
test "removing a focused child blurs before subsequent input" {
  for keyed in [false, true] {
    let visible = @reactive.signal(true)
    let blurs = Ref(0)
    let root = @runtime.mount(
      fn() {
        let render = fn() {
          @controls.button("Button", on_blur=fn() { blurs.val += 1 })
        }
        if keyed {
          @view.for_each(
            fn() { if visible.get() { [1] } else { [] } },
            fn(id) { id },
            fn(_) { render() },
          )
        } else {
          @view.show(fn() { visible.get() }, render)
        }
      },
      text_layout_system=test_text_layout_system(),
    )
    assert_true(root.key_down(test_key_event(KeyTab)))
    visible.set(false)
    assert_eq(blurs.val, 1)
    assert_false(root.key_down(test_key_event(KeyEnter)))
    root.dispose()
    root.dispose()
    assert_eq(blurs.val, 1)
  }
}

///|
test "pointer callbacks cannot activate a target removed during dispatch" {
  for phase in ["focus", "down", "up"] {
    let visible = @reactive.signal(true)
    let blurs = Ref(0)
    let clicks = Ref(0)
    let root = @runtime.mount(
      fn() {
        @view.show(fn() { visible.get() }, fn() {
          @controls.button(
            "Button",
            on_focus=fn() { if phase == "focus" { visible.set(false) } },
            on_pointer_down=fn(_) { if phase == "down" { visible.set(false) } },
            on_pointer_up=fn(_) { if phase == "up" { visible.set(false) } },
            on_blur=fn() { blurs.val += 1 },
            on_click=fn() { clicks.val += 1 },
          )
        })
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=180.0, height=80.0)
    ignore(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
    ignore(root.pointer_up(size~, point=Point(x=10.0, y=10.0)))
    assert_eq(clicks.val, 0)
    assert_eq(blurs.val, 1)
    assert_false(root.key_down(test_key_event(KeyEnter)))
  }
}

///|
test "focus follows its target when blur removes the previous keyed child" {
  for keyboard in [false, true] {
    let order = @reactive.signal([1, 2])
    let first_value = @reactive.signal("")
    let second_value = @reactive.signal("")
    let second_focused = Ref(0)
    let root = @runtime.mount(
      fn() {
        @view.for_each(fn() { order.get() }, fn(id) { id }, fn(item) {
          let value = if item() == 1 { first_value } else { second_value }
          @controls.text_input(
            value~,
            style=@controls.TextInputStyle().surface(
              @style.BoxStyle().width(140.0).height(32.0),
            ),
            on_blur=fn() { if item() == 1 { order.set([2]) } },
            on_focus=fn() { if item() == 2 { second_focused.val += 1 } },
          )
        })
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    assert_true(root.key_down(test_key_event(KeyTab)))
    if keyboard {
      assert_true(root.key_down(test_key_event(KeyTab)))
    } else {
      let size = @foundation.Size(width=180.0, height=160.0)
      assert_true(root.pointer_down(size~, point=Point(x=10.0, y=60.0)))
    }
    assert_eq(second_focused.val, 1)
    assert_true(root.text_input("x"))
    assert_eq(first_value.get(), "")
    assert_eq(second_value.get(), "x")
  }
}

///|
test "pointer up over different target does not click it" {
  let clicked : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.column(style=@view.FlexStyle().spacing(4.0)) <| [
        @controls.button(
          "One",
          on_click=fn() { clicked.push("one") },
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(80.0).height(32.0),
          ),
        ),
        @controls.button(
          "Two",
          on_click=fn() { clicked.push("two") },
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(80.0).height(32.0),
          ),
        ),
      ]
    },
    text_layout_system=test_text_layout_system(),
  )
  let size = @foundation.Size(width=120.0, height=80.0)
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  assert_true(root.pointer_up(size~, point=Point(x=10.0, y=40.0)))
  inspect(clicked.join(","), content="")
  root.dispose()
}

///|
test "cancellation focus loss and disposal finish control sessions once" {
  for kind in ["button", "checkbox", "radio", "input"] {
    let cancelled = Ref(0)
    let wrapper_cancelled = Ref(0)
    let blurred = Ref(0)
    let root = @runtime.mount(
      fn() {
        let on_pointer_cancel = fn() { cancelled.val += 1 }
        let on_blur = fn() { blurred.val += 1 }
        let child = match kind {
          "button" => @controls.button("Button", on_pointer_cancel~, on_blur~)
          "checkbox" => @controls.checkbox(on_pointer_cancel~, on_blur~)
          "radio" => @controls.radio(on_pointer_cancel~, on_blur~)
          _ => @controls.text_input(on_pointer_cancel~, on_blur~)
        }
        @view.interactive(
          @view.interactive(child, on_pointer_cancel=fn() {
            wrapper_cancelled.val += 1
          }),
          on_pointer_cancel=fn() { wrapper_cancelled.val += 1 },
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    let size = @foundation.Size(width=180.0, height=80.0)
    let point = @foundation.Point(x=10.0, y=10.0)
    assert_true(root.pointer_down(size~, point~))
    assert_true(root.pointer_cancel())
    assert_false(root.pointer_cancel())
    assert_false(root.pointer_up(size~, point~))
    assert_eq(cancelled.val, 1)
    assert_eq(wrapper_cancelled.val, 2)
    assert_eq(blurred.val, 0)
    assert_true(root.pointer_down(size~, point~))
    root.focus_lost()
    root.focus_lost()
    assert_eq(cancelled.val, 2)
    assert_eq(wrapper_cancelled.val, 4)
    assert_eq(blurred.val, 1)
    assert_false(root.pointer_move(size~, point~))
    assert_false(root.pointer_up(size~, point~))
    assert_false(root.key_down(test_key_event(KeyEnter)))
    assert_true(root.pointer_down(size~, point~))
    root.dispose()
    root.dispose()
    assert_eq(cancelled.val, 3)
    assert_eq(wrapper_cancelled.val, 6)
    assert_eq(blurred.val, 2)
    assert_false(root.click_at(size~, point~))
    assert_false(root.pointer_down(size~, point~))
    assert_false(root.key_down(test_key_event(KeyTab)))
    assert_false(root.text_input("x"))
    assert_false(root.paste_text("x"))
  }
}

///|
test "removing a captured child cancels before replacement receives input" {
  for keyed in [false, true] {
    let visible = @reactive.signal(true)
    let cancelled = Ref(0)
    let blurred = Ref(0)
    let clicks = Ref(0)
    let root = @runtime.mount(
      fn() {
        let render = fn() {
          @controls.button(
            "Button",
            on_pointer_cancel=fn() { cancelled.val += 1 },
            on_blur=fn() { blurred.val += 1 },
            on_click=fn() { clicks.val += 1 },
          )
        }
        @view.stack([
          if keyed {
            @view.for_each(
              fn() { if visible.get() { [1] } else { [] } },
              fn(id) { id },
              fn(_) { render() },
            )
          } else {
            @view.show(fn() { visible.get() }, render)
          },
        ])
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=180.0, height=80.0)
    let point = @foundation.Point(x=10.0, y=10.0)
    assert_true(root.pointer_down(size~, point~))
    visible.set(false)
    assert_eq(cancelled.val, 1)
    assert_eq(blurred.val, 1)
    visible.set(true)
    assert_false(root.pointer_up(size~, point~))
    assert_false(root.pointer_move(size~, point~))
    assert_eq(clicks.val, 0)
    assert_true(root.pointer_down(size~, point~))
    assert_true(root.pointer_up(size~, point~))
    assert_eq(clicks.val, 1)
    assert_eq(cancelled.val, 1)
  }
}

///|
test "pointer capture follows keyed identity across reorder" {
  let order = @reactive.signal([1, 2])
  let events : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.for_each(fn() { order.get() }, fn(id) { id }, fn(item) {
        @controls.button(
          "Button",
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(80.0).height(32.0),
          ),
          on_pointer_down=fn(_) { events.push("down \{item()}") },
          on_pointer_up=fn(_) { events.push("up \{item()}") },
          on_pointer_cancel=fn() { events.push("cancel \{item()}") },
          on_blur=fn() { events.push("blur \{item()}") },
          on_click=fn() { events.push("click \{item()}") },
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=180.0, height=160.0)
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  order.set([2, 1])
  let layout = root
    .view()
    .layout(size~, text_layout_system=test_text_layout_system())
  assert_true(
    root.pointer_up(size~, point=Point(x=10.0, y=layout.children[1].y + 10.0)),
  )
  assert_eq(events[:], ["down 1", "up 1", "click 1"][:])
}

///|
test "synthetic activation does not dispatch pointer down or up" {
  let clicks = Ref(0)
  let pointers = Ref(0)
  let root = @runtime.mount(
    fn() {
      @controls.button(
        "Button",
        on_click=fn() { clicks.val += 1 },
        on_pointer_down=fn(_) { pointers.val += 1 },
        on_pointer_up=fn(_) { pointers.val += 1 },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=180.0, height=80.0)
  let point = @foundation.Point(x=10.0, y=10.0)
  assert_true(root.click_at(size~, point~))
  assert_eq(clicks.val, 1)
  assert_eq(pointers.val, 0)
  assert_true(root.pointer_down(size~, point~))
  assert_true(root.pointer_up(size~, point~))
  assert_eq(clicks.val, 2)
  assert_eq(pointers.val, 2)
}

///|
test "teardown callbacks can request teardown again without recursion" {
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let visible = @reactive.signal(true)
  let cancelled = Ref(0)
  let blurred = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @controls.button(
          "Button",
          on_pointer_cancel=fn() {
            cancelled.val += 1
            if root_ref.val is Some(root) {
              ignore(root.pointer_cancel())
            }
            visible.set(false)
          },
          on_blur=fn() {
            blurred.val += 1
            if root_ref.val is Some(root) {
              root.focus_lost()
            }
          },
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  root_ref.val = Some(root)
  defer root.dispose()
  let size = @foundation.Size(width=180.0, height=80.0)
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  root.focus_lost()
  assert_eq(cancelled.val, 1)
  assert_eq(blurred.val, 1)
  assert_false(root.pointer_up(size~, point=Point(x=10.0, y=10.0)))
}

///|
test "focus loss rejects focus requests from blur callbacks" {
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let refocused = Ref(false)
  let root = @runtime.mount(
    fn() {
      @controls.text_input(on_blur=fn() {
        if root_ref.val is Some(root) {
          refocused.val = root.key_down(test_key_event(KeyTab))
        }
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  root_ref.val = Some(root)
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.focus_lost()
  assert_false(refocused.val)
  assert_false(root.text_input("x"))
}

///|
test "cancellation that disposes the root cannot start another press" {
  for synthetic in [false, true] {
    let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
    let cancelled = Ref(0)
    let root = @runtime.mount(
      fn() {
        @controls.button("Button", on_pointer_cancel=fn() {
          cancelled.val += 1
          if root_ref.val is Some(root) {
            root.dispose()
          }
        })
      },
      text_layout_system=test_text_layout_system(),
    )
    root_ref.val = Some(root)
    let size = @foundation.Size(width=180.0, height=80.0)
    let point = @foundation.Point(x=10.0, y=10.0)
    assert_true(root.pointer_down(size~, point~))
    if synthetic {
      assert_false(root.click_at(size~, point~))
    } else {
      assert_false(root.pointer_down(size~, point~))
    }
    assert_false(root.pointer_cancel())
    assert_eq(cancelled.val, 1)
    root.dispose()
  }
}

///|
test "focused non text input does not consume text input events" {
  let root = @runtime.mount(
    fn() {
      @controls.button(
        "Run",
        style=@controls.ButtonStyle().surface(
          @style.BoxStyle().width(80.0).height(32.0),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(
    TextRunRecorder::{ text: Ref(None), },
    size=Size(width=120.0, height=60.0),
  )
  assert_true(root.dirty() == Clean)
  assert_true(!root.text_input("x"))
  assert_true(root.dirty() == Clean)
  root.dispose()
}

///|
test "disabling a subtree ends input sessions and skips it during focus traversal" {
  let disabled = @reactive.signal(false)
  let cancelled = Ref(0)
  let blurred = Ref(0)
  let outside_clicks = Ref(0)
  let value = @reactive.signal("abc")
  let input = @controls.text_input(
    value~,
    style=@controls.TextInputStyle().surface(
      @style.BoxStyle().width(120.0).height(32.0),
    ),
    on_pointer_cancel=fn() { cancelled.val += 1 },
    on_blur=fn() { blurred.val += 1 },
  )
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.column([input], disabled~),
        @controls.button(
          "Outside",
          style=@controls.ButtonStyle().surface(
            @style.BoxStyle().width(120.0).height(32.0),
          ),
          on_click=fn() { outside_clicks.val += 1 },
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=160.0, height=100.0)
  let point = @foundation.Point(x=10.0, y=10.0)
  assert_true(root.pointer_down(size~, point~))
  disabled.set(true)
  assert_eq(cancelled.val, 1)
  assert_eq(blurred.val, 1)
  assert_eq(root.view().focusable_paths().length(), 1)
  assert_false(root.pointer_move(size~, point~))
  assert_false(root.pointer_up(size~, point~))
  assert_false(root.text_input("x"))
  assert_false(root.paste_text("x"))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(outside_clicks.val, 1)
  assert_false(root.pointer_down(size~, point~))
  assert_false(root.pointer_cancel())
  assert_eq(value.get(), "abc")
  disabled.set(false)
  assert_true(root.pointer_down(size~, point~))
  assert_true(root.pointer_up(size~, point~))
  assert_true(root.text_input("z"))
  assert_eq(value.get(), "zabc")
  assert_eq(cancelled.val, 1)
  assert_eq(blurred.val, 1)
}

///|
test "disabling a target during focus prevents activation while retaining its identity" {
  for input in ["click", "pointer", "tab"] {
    let disabled = @reactive.signal(false)
    let clicks = Ref(0)
    let cancelled = Ref(0)
    let blurred = Ref(0)
    let button = @controls.button(
      "Run",
      style=@controls.ButtonStyle().surface(
        @style.BoxStyle().width(120.0).height(32.0),
      ),
      on_click=fn() { clicks.val += 1 },
      on_focus=fn() { disabled.set(true) },
      on_blur=fn() { blurred.val += 1 },
      on_pointer_cancel=fn() { cancelled.val += 1 },
    )
    let node_id = button.node_id_at_path([]).unwrap()
    let root = @runtime.mount(
      fn() { @view.column([button], disabled~) },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=160.0, height=60.0)
    let point = @foundation.Point(x=10.0, y=10.0)
    match input {
      "click" => assert_true(root.click_at(size~, point~))
      "pointer" => assert_false(root.pointer_down(size~, point~))
      _ => assert_true(root.key_down(test_key_event(KeyTab)))
    }
    assert_true(root.view().path_for_node_id(node_id) is Some(_))
    assert_true(disabled.get())
    assert_false(root.key_down(test_key_event(KeyEnter)))
    assert_false(root.pointer_up(size~, point~))
    assert_eq(clicks.val, 0)
    assert_eq(blurred.val, 1)
    assert_eq(cancelled.val, if input == "pointer" { 1 } else { 0 })
  }
}
