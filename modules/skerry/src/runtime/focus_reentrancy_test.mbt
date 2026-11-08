///|
test "nested focus requests win and deliver exactly one matching blur" {
  for phase in ["focus", "blur"] {
    let root_slot : Ref[@runtime.UiRoot?] = Ref(None)
    let events : Array[String] = []
    let activated = Ref("")
    let size = @foundation.Size(width=120.0, height=150.0)
    let redirect = fn() {
      ignore(
        root_slot.val.unwrap().click_at(size~, point=Point(x=10.0, y=90.0)),
      )
    }
    let style = @controls.ButtonStyle().surface(
      @style.BoxStyle().width(100.0).height(40.0),
    )
    let root = @runtime.mount(
      fn() {
        @view.column([
          @controls.button(
            "A",
            style~,
            on_focus=fn() {
              events.push("A+")
              if phase == "focus" {
                redirect()
              }
            },
            on_blur=fn() {
              events.push("A-")
              if phase == "blur" {
                redirect()
              }
            },
          ),
          @controls.button("B", style~, on_focus=fn() { events.push("B+") }, on_blur=fn() {
            events.push("B-")
          }),
          @controls.button(
            "C",
            style~,
            on_focus=fn() { events.push("C+") },
            on_blur=fn() { events.push("C-") },
            on_click=fn() { activated.val = "C" },
          ),
        ])
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    root_slot.val = Some(root)
    assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
    if phase == "blur" {
      assert_true(root.click_at(size~, point=Point(x=10.0, y=50.0)))
    }
    assert_eq(events, ["A+", "A-", "C+"])
    activated.val = ""
    assert_true(root.key_down(test_key_event(KeyEnter)))
    assert_eq(activated.val, "C")
    root.focus_lost()
    root.focus_lost()
    root.dispose()
    assert_eq(events, ["A+", "A-", "C+", "C-"])
  }
}

///|
test "blur callbacks cannot focus a disabled removed or disposed target" {
  for action in ["disable", "remove", "dispose", "focus lost"] {
    let blocked = @reactive.signal(false)
    let visible = @reactive.signal(true)
    let slot : Ref[@runtime.UiRoot?] = Ref(None)
    let events : Array[String] = []
    let size = @foundation.Size(width=120.0, height=100.0)
    let style = @controls.ButtonStyle().surface(
      @style.BoxStyle().width(100.0).height(40.0),
    )
    let root = @runtime.mount(
      fn() {
        @view.column([
          @controls.button("A", style~, on_focus=fn() { events.push("A+") }, on_blur=fn() {
            events.push("A-")
            match action {
              "disable" => blocked.set(true)
              "remove" => visible.set(false)
              "dispose" => slot.val.unwrap().dispose()
              _ => slot.val.unwrap().focus_lost()
            }
          }),
          @view.show(fn() { visible.get() }, fn() {
            @controls.button(
              "B",
              style~,
              disabled=blocked,
              on_focus=fn() { events.push("B+") },
              on_blur=fn() { events.push("B-") },
            )
          }),
        ])
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    slot.val = Some(root)
    assert_true(root.click_at(size~, point=Point(x=10.0, y=10.0)))
    ignore(root.click_at(size~, point=Point(x=10.0, y=50.0)))
    assert_eq(events, ["A+", "A-"])
    assert_false(root.key_down(test_key_event(KeyEnter)))
  }
}

///|
test "on_focus removal or disable blurs the new focus once" {
  for remove in [false, true] {
    let blocked = @reactive.signal(false)
    let visible = @reactive.signal(true)
    let events : Array[String] = []
    let root = @runtime.mount(
      fn() {
        @view.show(fn() { visible.get() }, fn() {
          @controls.button(
            "temporary",
            disabled=blocked,
            on_focus=fn() {
              events.push("focus")
              if remove {
                visible.set(false)
              } else {
                blocked.set(true)
              }
            },
            on_blur=fn() { events.push("blur") },
          )
        })
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    ignore(root.key_down(test_key_event(KeyTab)))
    assert_eq(events, ["focus", "blur"])
    assert_false(root.key_down(test_key_event(KeyEnter)))
    root.dispose()
    assert_eq(events, ["focus", "blur"])
  }
}
