///|
test "popup owns state and content can close it without an external signal" {
  let proposals : Array[Bool] = []
  let builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.popup(
        popup_test_button("anchor"),
        on_change=fn(event) { proposals.push(event.value) },
        fn(close) {
          builds.val += 1
          popup_test_button("close", on_click=close)
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  assert_true(root.view().overlay_targets().is_empty())
  assert_eq(builds.val, 0)
  assert_true(root.pointer_down(size~, point=Point(x=5.0, y=5.0)))
  assert_true(root.pointer_up(size~, point=Point(x=5.0, y=5.0)))
  assert_eq(root.view().overlay_targets().length(), 1)
  assert_eq(builds.val, 1)
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_true(root.view().overlay_targets().is_empty())
  assert_eq(proposals, [true, false])
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_eq(builds.val, 2)
  assert_eq(root.view().overlay_targets().length(), 1)
}

///|
test "popup change policy can prevent default opening and content closing" {
  let prevent = Ref(true)
  let proposals : Array[Bool] = []
  let close_ref : Ref[(() -> Unit)?] = Ref(None)
  let builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.popup(
        popup_test_button("anchor"),
        on_change=fn(event) {
          proposals.push(event.value)
          if prevent.val {
            event.prevent_default()
          }
        },
        fn(close) {
          close_ref.val = Some(close)
          builds.val += 1
          popup_test_button("entry")
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  let point = @foundation.Point(x=5.0, y=5.0)
  assert_true(root.click_at(size~, point~))
  assert_true(root.view().overlay_targets().is_empty())
  assert_eq(builds.val, 0)
  prevent.val = false
  assert_true(root.click_at(size~, point~))
  assert_eq(builds.val, 1)
  prevent.val = true
  close_ref.val.unwrap()()
  assert_eq(root.view().overlay_targets().length(), 1)
  prevent.val = false
  close_ref.val.unwrap()()
  assert_true(root.view().overlay_targets().is_empty())
  close_ref.val.unwrap()()
  assert_eq(proposals, [true, true, false, false])
}

///|
test "popup manual trigger preserves anchor behavior and uses the supplied model" {
  let open = @reactive.signal(false)
  let clicks = Ref(0)
  let proposals : Array[Bool] = []
  let close_ref : Ref[(() -> Unit)?] = Ref(None)
  let root = @runtime.mount(
    fn() {
      @view.popup(
        popup_test_button("anchor", on_click=fn() { clicks.val += 1 }),
        open~,
        trigger=Manual,
        focus=false,
        on_change=fn(event) { proposals.push(event.value) },
        fn(close) {
          close_ref.val = Some(close)
          popup_test_button("entry")
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  let point = @foundation.Point(x=5.0, y=5.0)
  assert_true(root.click_at(size~, point~))
  assert_eq(clicks.val, 1)
  assert_false(open.get())
  open.set(true)
  assert_eq(root.view().overlay_targets().length(), 1)
  assert_true(root.click_at(size~, point~))
  assert_eq(clicks.val, 2)
  assert_true(open.get())
  assert_true(proposals.is_empty())
  close_ref.val.unwrap()()
  assert_false(open.get())
  assert_eq(proposals, [false])
}

///|
test "popup click trigger preserves pointer and keyboard anchor handlers exactly once" {
  let open = @reactive.signal(false)
  let clicks = Ref(0)
  let proposals : Array[Bool] = []
  let root = @runtime.mount(
    fn() {
      @view.popup(
        popup_test_button("anchor", on_click=fn() { clicks.val += 1 }),
        open~,
        focus=false,
        on_change=fn(event) { proposals.push(event.value) },
        fn(_) { @view.text("hint") },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  assert_true(root.click_at(size~, point=Point(x=5.0, y=5.0)))
  assert_true(open.get())
  assert_eq(clicks.val, 1)
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_false(open.get())
  assert_eq(clicks.val, 2)
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_true(open.get())
  assert_eq(clicks.val, 3)
  assert_eq(proposals, [true, false, true])
}

///|
test "popup text anchor gets keyboard activation without repeating the toggle" {
  let proposals : Array[Bool] = []
  let root = @runtime.mount(
    fn() {
      @view.popup(
        @view.text("anchor"),
        focus=false,
        on_change=fn(event) { proposals.push(event.value) },
        fn(_) { @view.text("hint") },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(root.view().overlay_targets().length(), 1)
  assert_true(root.key_down(KeyEvent(key=KeyEnter, repeat=true)))
  assert_eq(root.view().overlay_targets().length(), 1)
  assert_eq(proposals, [true])
  assert_true(root.key_down(test_key_event(KeySpace)))
  assert_true(root.view().overlay_targets().is_empty())
  assert_eq(proposals, [true, false])
}

///|
test "popup close callback belongs to one session and becomes inert on detach" {
  let open = @reactive.signal(true)
  let closes : Array[() -> Unit] = []
  let proposals : Array[Bool] = []
  let root = @runtime.mount(
    fn() {
      @view.popup(
        popup_test_button("anchor"),
        open~,
        on_change=fn(event) { proposals.push(event.value) },
        fn(close) {
          closes.push(close)
          popup_test_button("entry")
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  open.set(false)
  open.set(true)
  assert_eq(closes.length(), 2)
  closes[0]()
  assert_true(open.get())
  assert_true(proposals.is_empty())
  closes[1]()
  assert_false(open.get())
  assert_eq(proposals, [false])
  open.set(true)
  assert_eq(closes.length(), 3)
  root.dispose()
  closes[2]()
  assert_true(open.get())
  assert_eq(proposals, [false])
}

///|
test "popup anchor explicit model changes and removal precede automatic behavior" {
  for remove in [false, true] {
    let open = @reactive.signal(false)
    let visible = @reactive.signal(true)
    let proposals : Array[Bool] = []
    let root = @runtime.mount(
      fn() {
        @view.show(fn() { visible.get() }, fn() {
          @view.popup(
            popup_test_button("anchor", on_click=fn() {
              if remove {
                visible.set(false)
              } else {
                open.set(true)
              }
            }),
            open~,
            on_change=fn(event) { proposals.push(event.value) },
            fn(_) { @view.text("hint") },
          )
        })
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    assert_true(
      root.click_at(
        size=Size(width=200.0, height=200.0),
        point=Point(x=5.0, y=5.0),
      ),
    )
    assert_eq(open.get(), !remove)
    assert_true(proposals.is_empty())
  }
}

///|
test "popup internal models remain independent across roots" {
  let create = fn() {
    @view.popup(popup_test_button("anchor"), fn(close) {
      popup_test_button("close", on_click=close)
    })
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
  let size = @foundation.Size(width=200.0, height=200.0)
  assert_true(first.click_at(size~, point=Point(x=5.0, y=5.0)))
  assert_eq(first.view().overlay_targets().length(), 1)
  assert_true(second.view().overlay_targets().is_empty())
  first.dispose()
  assert_true(second.click_at(size~, point=Point(x=5.0, y=5.0)))
  assert_eq(second.view().overlay_targets().length(), 1)
  assert_true(second.key_down(test_key_event(KeyEnter)))
  assert_true(second.view().overlay_targets().is_empty())
}

///|
test "popup click trigger respects a handled custom keyboard event" {
  let open = @reactive.signal(false)
  let root = @runtime.mount(
    fn() {
      @view.popup(
        @view.element(
          style=@style.BoxStyle().width(80.0).height(24.0),
          painter=@view.Painter(fn(_, _) { () }),
          events=@view.ElementEvents(focusable=true, handle_key_down=fn(_) {
            KeyHandled
          }),
        ),
        open~,
        fn(_) { @view.text("hint") },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_false(open.get())
}
