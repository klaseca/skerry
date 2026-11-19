///|
fn dialog_surface(root : @runtime.UiRoot) -> @diagnostics.NodeSnapshot {
  for node in root.snapshot().unwrap().tree.nodes {
    if node.components.any(component => component.name == "DialogSurface") {
      return node
    }
  }
  abort("missing dialog surface")
}

///|
test "dialog owns visibility enters focus traps Tab and restores after closing" {
  let focused : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.dialog(
          popup_test_button("open", on_focus=fn() { focused.push("open") }),
          fn(close) {
            @view.column([
              popup_test_button("first", on_focus=fn() { focused.push("first") }),
              popup_test_button("close", on_click=close, on_focus=fn() {
                focused.push("close")
              }),
            ])
          },
        ),
        popup_test_button("outside", on_focus=fn() { focused.push("outside") }),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=640.0, height=480.0)
  assert_true(root.click_at(size~, point=Point(x=5.0, y=5.0)))
  assert_eq(focused, ["open", "first"])
  assert_true(root.key_down(test_shift_key_event(KeyTab)))
  assert_eq(focused.last(), Some("close"))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(focused.last(), Some("first"))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_true(root.view().overlay_targets().is_empty())
  assert_eq(focused.last(), Some("open"))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(root.view().overlay_targets().length(), 1)
  assert_eq(focused.last(), Some("first"))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_eq(focused.last(), Some("open"))
}

///|
test "dialog backdrop consumes presses without activating its anchor or background" {
  let open = @reactive.signal(true)
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.stack([
        @controls.dialog(popup_test_button("open"), open~, fn(_close) {
          popup_test_button("inside")
        }),
        @view.interactive(
          @view.box(style=@style.BoxStyle().width(640.0).height(480.0)),
          on_click=fn() { clicks.val += 1 },
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=640.0, height=480.0)
  assert_true(root.pointer_down(size~, point=Point(x=5.0, y=5.0)))
  assert_false(open.get())
  assert_false(root.pointer_up(size~, point=Point(x=5.0, y=5.0)))
  assert_eq(clicks.val, 0)
  assert_true(root.click_at(size~, point=Point(x=5.0, y=5.0)))
  assert_eq(clicks.val, 1)
}

///|
test "dialog dismissal policies leave explicit close available and changes cancellable" {
  let open = @reactive.signal(true)
  let prevent = Ref(true)
  let proposals : Array[Bool] = []
  let close : Ref[(() -> Unit)?] = Ref(None)
  let root = @runtime.mount(
    fn() {
      @controls.dialog(
        popup_test_button("open"),
        open~,
        close_on_backdrop=false,
        close_on_escape=false,
        on_change=fn(event) {
          proposals.push(event.value)
          if prevent.val {
            event.prevent_default()
          }
        },
        fn(action) {
          close.val = Some(action)
          popup_test_button("close", on_click=action)
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=640.0, height=480.0)
  assert_true(root.click_at(size~, point=Point(x=5.0, y=5.0)))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_true(open.get())
  assert_eq(proposals, [])
  close.val.unwrap()()
  assert_eq(proposals, [false])
  assert_true(open.get())
  prevent.val = false
  close.val.unwrap()()
  assert_false(open.get())
  assert_eq(proposals, [false, false])
}

///|
test "prevented backdrop and Escape dismissal do not release modal input" {
  let open = @reactive.signal(true)
  let proposals = Ref(0)
  let root = @runtime.mount(
    fn() {
      @controls.dialog(
        popup_test_button("open"),
        open~,
        on_change=fn(event) {
          proposals.val += 1
          event.prevent_default()
        },
        fn(_close) { @view.text("No controls") },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=640.0, height=480.0)
  assert_true(root.pointer_down(size~, point=Point(x=5.0, y=5.0)))
  assert_false(root.pointer_up(size~, point=Point(x=5.0, y=5.0)))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(open.get())
  assert_eq(proposals.val, 2)
}

///|
test "dialog without focusable content blocks background keyboard text and scrolling" {
  let open = @reactive.signal(false)
  let value = @reactive.signal("")
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([
          @controls.text_input(value~),
          @controls.dialog(
            popup_test_button("open"),
            open~,
            close_on_backdrop=false,
            fn(_close) { @view.text("Please wait") },
          ),
          @view.fill_box(1000.0),
        ]),
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=640.0, height=480.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.text_input("before"))
  open.set(true)
  assert_false(root.text_input("after"))
  assert_eq(value.get(), "before")
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_shift_key_event(KeyTab)))
  ignore(root.key_down(test_key_event(KeyPageDown), size~))
  assert_false(
    root.scroll_at(
      size~,
      point=Point(x=5.0, y=100.0),
      delta=Point(x=0.0, y=100.0),
    ),
  )
  assert_eq(offset.get(), 0.0)
  open.set(false)
  assert_true(root.text_input(" restored"))
  assert_eq(value.get(), "before restored")
}

///|
test "dialog geometry centers resizes and scrolls tall content without background extent" {
  let open = @reactive.signal(true)
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @controls.dialog(popup_test_button("open"), open~, fn(_close) {
          @view.column([@view.fill_box(1000.0), popup_test_button("last")])
        }),
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=640.0, height=480.0)
  root.paint(ScrollRecorder(), size~)
  let surface = dialog_surface(root)
  assert_eq(surface.frame.size.width, 420.0)
  assert_eq(surface.frame.origin.x, 110.0)
  assert_true(surface.frame.origin.y >= 24.0)
  assert_true(surface.frame.size.height <= 432.0)
  assert_true(surface.scroll.unwrap().max_offset > 0.0)
  assert_true(
    root.snapshot().unwrap().tree.nodes.any(node => {
      node.component_name == "Modal" &&
      node.frame == @foundation.Rect::from_size(size)
    }),
  )
  assert_true(
    root.scroll_at(
      size~,
      point=Point(x=150.0, y=100.0),
      delta=Point(x=0.0, y=-40.0),
    ),
  )
  assert_eq(offset.get(), 0.0)
  let small = @foundation.Size(width=240.0, height=180.0)
  root.paint(ScrollRecorder(), size=small)
  let surface = dialog_surface(root)
  assert_true(surface.frame.size.width <= 192.0)
  assert_true(surface.frame.size.height <= 132.0)
  assert_eq(
    surface.frame.origin.x * 2.0 + surface.frame.size.width,
    small.width,
  )
}

///|
test "nested dialog and popup close top first restoring each focus owner" {
  let focused : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @controls.dialog(
        popup_test_button("outer", on_focus=fn() { focused.push("outer") }),
        fn(_close) {
          @controls.dialog(
            popup_test_button("inner", on_focus=fn() { focused.push("inner") }),
            fn(_close) {
              @view.popup(
                popup_test_button("menu", on_focus=fn() { focused.push("menu") }),
                fn(_close) {
                  popup_test_button("entry", on_focus=fn() {
                    focused.push("entry")
                  })
                },
              )
            },
          )
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=640.0, height=480.0)
  assert_true(root.click_at(size~, point=Point(x=5.0, y=5.0)))
  assert_eq(focused.last(), Some("inner"))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(focused.last(), Some("menu"))
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(focused.last(), Some("entry"))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_eq(focused.last(), Some("menu"))
  assert_eq(root.view().overlay_targets().length(), 2)
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_eq(focused.last(), Some("inner"))
  assert_eq(root.view().overlay_targets().length(), 1)
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_eq(focused.last(), Some("outer"))
}

///|
test "dialog sessions dispose once and stale close cannot close a later session" {
  let open = @reactive.signal(false)
  let creates = Ref(0)
  let disposes = Ref(0)
  let close : Ref[(() -> Unit)?] = Ref(None)
  let root = @runtime.mount(
    fn() {
      @controls.dialog(popup_test_button("open"), open~, fn(action) {
        creates.val += 1
        @reactive.on_cleanup(fn() { disposes.val += 1 })
        close.val = Some(action)
        popup_test_button("close", on_click=action)
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  for _ in 0..<100 {
    open.set(true)
    let stale = close.val.unwrap()
    open.set(false)
    open.set(true)
    stale()
    assert_true(open.get())
    open.set(false)
  }
  assert_eq(creates.val, 200)
  assert_eq(disposes.val, 200)
  open.set(true)
  let stale = close.val.unwrap()
  root.dispose()
  assert_eq(disposes.val, 201)
  stale()
  assert_true(open.get())
}

///|
test "modal rejects background focus requests including redirects from focus callbacks" {
  let open = @reactive.signal(false)
  let context : Ref[@view.MountContext?] = Ref(None)
  let outside = Ref(-1)
  let redirected : Ref[Bool?] = Ref(None)
  let root = @runtime.mount(
    fn() {
      let background = popup_test_button("outside")
      outside.val = background.node_id_at_path([]).unwrap()
      @view.column([
        background,
        @controls.dialog(popup_test_button("open"), open~, fn(_close) {
          @controls.button("inside", on_focus=fn() {
            redirected.val = Some(
              context.val.unwrap().request_focus(outside.val),
            )
          })
        }),
        @view.element(
          style=@style.BoxStyle(),
          painter=@view.Painter::empty(),
          reactivity=@view.Reactivity(mount=fn(host) {
            context.val = Some(host)
            fn() { context.val = None }
          }),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let host = context.val.unwrap()
  assert_true(host.request_focus(outside.val))
  open.set(true)
  assert_eq(redirected.val, Some(false))
  assert_false(host.request_focus(outside.val))
  root.paint(ScrollRecorder(), size=Size(width=640.0, height=480.0))
  assert_false(root.snapshot().unwrap().focused_node_id == Some(outside.val))
  open.set(false)
  root.paint(ScrollRecorder(), size=Size(width=640.0, height=480.0))
  assert_eq(root.snapshot().unwrap().focused_node_id, Some(outside.val))
}

///|
test "modal paints above later background popups and blocks their wheel and click" {
  let modal_open = @reactive.signal(true)
  let popup_open = @reactive.signal(true)
  let clicks = Ref(0)
  let backdrop = @foundation.Color::rgba(r=1, g=2, b=3, a=120)
  let surface = @foundation.Color::rgb(r=10, g=20, b=30)
  let background = @foundation.Color::rgb(r=200, g=0, b=0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.dialog(
          popup_test_button("modal"),
          open=modal_open,
          close_on_backdrop=false,
          style=@controls.DialogStyle()
            .surface(@style.BoxStyle().background(surface))
            .backdrop(@style.BoxStyle().background(backdrop)),
          fn(_close) { @view.text("Modal") },
        ),
        @view.popup(popup_test_button("popup"), open=popup_open, fn(_close) {
          @view.interactive(
            @view.box(
              style=@style.BoxStyle()
                .width(100.0)
                .height(50.0)
                .background(background),
            ),
            on_click=fn() { clicks.val += 1 },
          )
        }),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=640.0, height=480.0)
  let recorder = ScrollRecorder()
  root.paint(recorder, size~)
  let colors = recorder.fills.map(fill => fill.2)
  assert_eq(colors[colors.length() - 2:], [backdrop, surface])
  assert_true(root.click_at(size~, point=Point(x=5.0, y=60.0)))
  assert_eq(clicks.val, 0)
  assert_true(modal_open.get())
  assert_true(popup_open.get())
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_false(modal_open.get())
  assert_true(popup_open.get())
  assert_true(root.click_at(size~, point=Point(x=5.0, y=60.0)))
  assert_eq(clicks.val, 1)
}

///|
test "opening modal during background focus stops that background activation" {
  let open = @reactive.signal(false)
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.button("outside", on_focus=fn() { open.set(true) }, on_click=fn() {
          clicks.val += 1
        }),
        @controls.dialog(popup_test_button("open"), open~, fn(_close) {
          popup_test_button("inside")
        }),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(
    root.click_at(
      size=Size(width=640.0, height=480.0),
      point=Point(x=5.0, y=5.0),
    ),
  )
  assert_true(open.get())
  assert_eq(clicks.val, 0)
}
