///|
fn popup_test_button(
  label : String,
  on_click? : () -> Unit,
  on_focus? : () -> Unit,
) -> @view.View {
  @controls.button(
    label,
    on_click?,
    on_focus?,
    style=@controls.ButtonStyle().surface(
      @style.BoxStyle()
      .width(80.0)
      .height(24.0)
      .padding(@foundation.Insets::all(0.0)),
    ),
  )
}

///|
fn popup_node(root : @runtime.UiRoot) -> @diagnostics.NodeSnapshot {
  let nodes = root.snapshot().unwrap().tree.nodes
  for node in nodes {
    if node.component_name == "Popup" {
      return node
    }
  }
  abort("missing popup")
}

///|
test "popup escapes ancestor clips and later siblings for paint and pointer input" {
  let open = @reactive.signal(true)
  let clicks : Array[String] = []
  let red = @foundation.Color::rgb(r=200, g=0, b=0)
  let blue = @foundation.Color::rgb(r=0, g=0, b=200)
  let root = @runtime.mount(
    fn() {
      @view.stack([
        @view.column(
          [
            @view.popup(popup_test_button("anchor"), open~, focus=false, fn(
              _close,
            ) {
              @view.interactive(
                @view.box(
                  style=@style.BoxStyle()
                    .width(100.0)
                    .height(40.0)
                    .background(red),
                ),
                on_click=fn() { clicks.push("popup") },
              )
            }),
          ],
          style=@view.FlexStyle().height(24.0),
        ).clip(),
        @view.interactive(
          @view.box(
            style=@style.BoxStyle().width(180.0).height(180.0).background(blue),
          ),
          on_click=fn() { clicks.push("background") },
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  let renderer = ScrollRecorder()
  root.paint(renderer, size~)
  let popup = popup_node(root)
  assert_eq(popup.frame, Rect(x=0.0, y=28.0, width=100.0, height=40.0))
  assert_eq(popup.clip, @foundation.Rect::from_size(size))
  assert_eq(popup.popup_anchor, root.view().node_id_at_path([0, 0, 0]))
  assert_eq(renderer.fills.last().unwrap().2, red)
  assert_eq(renderer.fills.last().unwrap().1, @foundation.Rect::from_size(size))
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=35.0)))
  assert_true(root.pointer_up(size~, point=Point(x=10.0, y=35.0)))
  assert_eq(clicks, ["popup"])
}

///|
test "popup flips at window edges and follows translated anchors on resize" {
  let open = @reactive.signal(true)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.popup(
          popup_test_button("anchor").translated(Point(x=140.0, y=150.0)),
          open~,
          focus=false,
          fn(_close) {
            @view.box(style=@style.BoxStyle().width(100.0).height(50.0))
          },
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(ScrollRecorder(), size=Size(width=200.0, height=200.0))
  assert_eq(
    popup_node(root).frame,
    Rect(x=100.0, y=96.0, width=100.0, height=50.0),
  )
  root.paint(ScrollRecorder(), size=Size(width=320.0, height=300.0))
  assert_eq(
    popup_node(root).frame,
    Rect(x=140.0, y=178.0, width=100.0, height=50.0),
  )
}

///|
test "popup outside dismissal consumes the whole press and can be prevented" {
  let open = @reactive.signal(true)
  let prevent = Ref(true)
  let proposals = Ref(0)
  let proposed : Array[Bool] = []
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.popup(
          popup_test_button("anchor"),
          open~,
          on_change=fn(event) {
            proposed.push(event.value)
            proposals.val += 1
            if prevent.val {
              event.prevent_default()
            }
          },
          fn(_close) { popup_test_button("inside") },
        ),
        popup_test_button("outside", on_click=fn() { clicks.val += 1 }).translated(
          Point(x=0.0, y=80.0),
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  let point = @foundation.Point(x=10.0, y=110.0)
  assert_true(root.pointer_down(size~, point~))
  assert_false(root.pointer_up(size~, point~))
  assert_true(open.get())
  assert_eq(clicks.val, 0)
  prevent.val = false
  assert_true(root.pointer_down(size~, point~))
  root.paint(ScrollRecorder(), size~)
  let outside = root.view().node_id_at_path([1]).unwrap()
  assert_true(
    root.snapshot().unwrap().tree.nodes.any(node => {
      node.id == outside && node.state.hovered
    }),
  )
  assert_false(root.pointer_up(size~, point~))
  assert_false(open.get())
  assert_eq(proposals.val, 2)
  assert_eq(proposed, [false, false])
  assert_eq(clicks.val, 0)
  assert_true(root.click_at(size~, point~))
  assert_eq(clicks.val, 1)
}

///|
test "opening from an anchor enters popup focus Tab stays inside and Escape restores" {
  let open = @reactive.signal(false)
  let focused : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.popup(
          popup_test_button("anchor", on_click=fn() { open.set(!open.get()) }, on_focus=fn() {
            focused.push("anchor")
          }),
          open~,
          fn(_close) {
            @view.column([
              popup_test_button("first", on_focus=fn() { focused.push("first") }),
              popup_test_button("second", on_focus=fn() {
                focused.push("second")
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
  let size = @foundation.Size(width=200.0, height=200.0)
  assert_true(root.click_at(size~, point=Point(x=5.0, y=5.0)))
  assert_eq(focused, ["anchor", "first"])
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(focused, ["anchor", "first", "second", "first"])
  assert_true(root.key_down(test_shift_key_event(KeyTab)))
  assert_eq(focused.last(), Some("second"))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_false(open.get())
  assert_eq(focused.last(), Some("anchor"))
}

///|
test "passive popup preserves focus and Escape works without a focus target" {
  let open = @reactive.signal(true)
  let focused = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.popup(
        popup_test_button("anchor", on_focus=fn() { focused.val += 1 }),
        open~,
        focus=false,
        fn(_close) { @view.text("hint") },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(focused.val, 0)
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_false(open.get())
  assert_eq(focused.val, 0)
}

///|
test "nested popup Escape closes only the top layer and restores its parent entry" {
  let outer = @reactive.signal(true)
  let inner = @reactive.signal(false)
  let focused : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.popup(
        popup_test_button("anchor", on_focus=fn() { focused.push("anchor") }),
        open=outer,
        fn(_close) {
          @view.popup(
            popup_test_button("submenu", on_click=fn() { inner.set(true) }, on_focus=fn() {
              focused.push("submenu")
            }),
            open=inner,
            placement=RightStart,
            fn(_close) {
              popup_test_button("entry", on_focus=fn() { focused.push("entry") })
            },
          )
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(focused, ["submenu"])
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(focused.last(), Some("entry"))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_false(inner.get())
  assert_true(outer.get())
  assert_eq(focused.last(), Some("submenu"))
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_false(outer.get())
  assert_eq(focused.last(), Some("anchor"))
}

///|
test "popup content has one reactive lifetime per session and no work after detach" {
  let open = @reactive.signal(false)
  let visible = @reactive.signal(true)
  let value = @reactive.signal(1)
  let builds = Ref(0)
  let runs = Ref(0)
  let stops = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @view.popup(popup_test_button("anchor"), open~, fn(_close) {
          builds.val += 1
          @reactive.on_cleanup(fn() { stops.val += 1 })
          @view.text(
            @reactive.bind(fn() {
              runs.val += 1
              value.get().to_string()
            }),
          )
        })
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(builds.val, 0)
  open.set(true)
  assert_eq(builds.val, 1)
  let before = runs.val
  value.set(2)
  assert_true(runs.val > before)
  assert_eq(builds.val, 1)
  open.set(false)
  assert_eq(stops.val, 1)
  let before = runs.val
  value.set(3)
  assert_eq(runs.val, before)
  open.set(true)
  assert_eq(builds.val, 2)
  visible.set(false)
  assert_eq(stops.val, 2)
  root.paint(ScrollRecorder(), size=Size(width=200.0, height=200.0))
  let before = runs.val
  value.set(4)
  open.set(false)
  assert_eq(runs.val, before)
  assert_false(root.needs_frame())
}

///|
test "popup follows scroll without changing the parent's content extent" {
  let open = @reactive.signal(true)
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.scroll_view(
          @view.column([
            @view.fill_box(20.0),
            @view.popup(popup_test_button("anchor"), open~, focus=false, fn(
              _close,
            ) {
              @view.box(style=@style.BoxStyle().width(100.0).height(80.0))
            }),
            @view.fill_box(100.0),
          ]),
          offset~,
          style=@style.BoxStyle().height(60.0),
          scrollbar=false,
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  root.paint(ScrollRecorder(), size~)
  assert_eq(popup_node(root).frame.origin.y, 48.0)
  let before = root.snapshot().unwrap().tree.nodes[1].scroll.unwrap()
  assert_eq(before.content_size.height, 144.0)
  offset.set(10.0)
  root.paint(ScrollRecorder(), size~)
  assert_eq(popup_node(root).frame.origin.y, 38.0)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[1].scroll.unwrap().content_size,
    before.content_size,
  )
  assert_eq(root.frame_stats().layout_count, 1)
}

///|
test "popup no-op updates keep instances and layout idle" {
  let open = @reactive.signal(true)
  let text = @reactive.signal("first")
  let root = @runtime.mount(
    fn() {
      @view.popup(popup_test_button("anchor"), open~, fn(_close) {
        @view.text(text)
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  root.paint(ScrollRecorder(), size~)
  let first = popup_node(root)
  open.set(true)
  assert_false(root.needs_frame())
  root.paint(ScrollRecorder(), size~)
  assert_eq(popup_node(root).id, first.id)
  assert_eq(root.frame_stats().layout_count, 1)
}

///|
test "popup measurement shrinks to content and wraps within the window" {
  let open = @reactive.signal(true)
  let root = @runtime.mount(
    fn() {
      @view.popup(popup_test_button("anchor"), open~, focus=false, fn(_close) {
        @view.text("small")
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(ScrollRecorder(), size=Size(width=300.0, height=200.0))
  assert_true(popup_node(root).frame.size.width < 100.0)
  assert_true(popup_node(root).frame.size.width > 0.0)
  root.paint(ScrollRecorder(), size=Size(width=20.0, height=200.0))
  assert_true(popup_node(root).frame.size.width <= 20.0)
}

///|
test "closing a popup by its own anchor does not reopen or activate a popup entry" {
  let open = @reactive.signal(false)
  let changes = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.popup(
        popup_test_button("anchor", on_click=fn() {
          open.set(!open.get())
          changes.val += 1
        }),
        open~,
        fn(_close) { popup_test_button("entry") },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  let point = @foundation.Point(x=5.0, y=5.0)
  assert_true(root.pointer_down(size~, point~))
  assert_true(root.pointer_up(size~, point~))
  assert_true(open.get())
  assert_true(root.pointer_down(size~, point~))
  assert_true(root.pointer_up(size~, point~))
  assert_false(open.get())
  assert_eq(changes.val, 2)
}

///|
test "disabled popup ancestor suspends floating input focus and paint without losing state" {
  let open = @reactive.signal(true)
  let disabled = @reactive.signal(false)
  let focused = Ref(0)
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @view.popup(popup_test_button("anchor"), open~, fn(_close) {
            popup_test_button("entry", on_click=fn() { clicks.val += 1 }, on_focus=fn() {
              focused.val += 1
            })
          }),
        ],
        disabled~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  root.paint(ScrollRecorder(), size~)
  assert_eq(focused.val, 1)
  disabled.set(true)
  assert_true(root.view().popup_targets().is_empty())
  assert_false(root.key_down(test_key_event(KeyEnter)))
  assert_false(root.click_at(size~, point=Point(x=5.0, y=32.0)))
  let renderer = ScrollRecorder()
  root.paint(renderer, size~)
  assert_eq(renderer.fills.length(), 1)
  assert_eq(clicks.val, 0)
  assert_true(open.get())
  disabled.set(false)
  assert_eq(focused.val, 2)
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(clicks.val, 1)
}

///|
test "popup radio group keeps a single Tab stop" {
  let open = @reactive.signal(true)
  let selected = @reactive.signal(1)
  let focused = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.popup(popup_test_button("anchor"), open~, fn(_close) {
        @view.column([
          @controls.radio_group(selected, [1, 2], label=fn(value) {
            value.to_string()
          }),
          popup_test_button("last", on_focus=fn() { focused.val += 1 }),
        ])
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(focused.val, 1)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.key_down(test_key_event(KeyArrowDown)))
  assert_eq(selected.get(), 2)
}

///|
test "popup focus reveal and wheel never scroll the anchor's outer viewport" {
  let open = @reactive.signal(true)
  let outer = @reactive.signal(10.0)
  let inner = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.scroll_view(
          @view.column([
            @view.fill_box(20.0),
            @view.popup(popup_test_button("anchor"), open~, fn(_close) {
              @view.scroll_view(
                @view.column([
                  popup_test_button("one"),
                  popup_test_button("two"),
                  popup_test_button("three"),
                ]),
                offset=inner,
                style=@style.BoxStyle().width(100.0).height(30.0),
                scrollbar=false,
              )
            }),
            @view.fill_box(100.0),
          ]),
          offset=outer,
          style=@style.BoxStyle().height(60.0),
          scrollbar=false,
        ),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  root.paint(ScrollRecorder(), size~)
  assert_eq(outer.get(), 10.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(ScrollRecorder(), size~)
  assert_true(inner.get() > 0.0)
  assert_eq(outer.get(), 10.0)
  assert_true(
    root.scroll_at(
      size~,
      point=Point(x=5.0, y=42.0),
      delta=Point(x=0.0, y=100.0),
    ),
  )
  assert_eq(inner.get(), 42.0)
  assert_false(
    root.scroll_at(
      size~,
      point=Point(x=5.0, y=42.0),
      delta=Point(x=0.0, y=100.0),
    ),
  )
  assert_eq(outer.get(), 10.0)
}

///|
test "popup focus handler can immediately close or dispose its owner" {
  for dispose in [false, true] {
    let open = @reactive.signal(false)
    let owner : Ref[@runtime.UiRoot?] = Ref(None)
    let root = @runtime.mount(
      fn() {
        @view.popup(popup_test_button("anchor"), open~, fn(_close) {
          popup_test_button("entry", on_focus=fn() {
            if dispose {
              owner.val.unwrap().dispose()
            } else {
              open.set(false)
            }
          })
        })
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    owner.val = Some(root)
    open.set(true)
    if dispose {
      assert_true(root.is_disposed())
    } else {
      assert_false(open.get())
    }
    assert_true(root.view().popup_targets().is_empty())
  }
}

///|
test "popup roots share an open model but keep independent instances and focus" {
  let open = @reactive.signal(true)
  let builds = Ref(0)
  let clicks = Ref(0)
  let create = fn() {
    @view.popup(popup_test_button("anchor"), open~, fn(_close) {
      builds.val += 1
      popup_test_button("entry", on_click=fn() { clicks.val += 1 })
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
  assert_eq(builds.val, 2)
  first.dispose()
  assert_true(second.key_down(test_key_event(KeyEscape)))
  assert_false(open.get())
  open.set(true)
  assert_eq(builds.val, 3)
  assert_true(second.key_down(test_key_event(KeyEnter)))
  assert_eq(clicks.val, 1)
}

///|
test "a popup opened below an existing layer does not steal its keyboard focus" {
  let first = @reactive.signal(false)
  let second = @reactive.signal(true)
  let clicks : Array[String] = []
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.popup(popup_test_button("anchor one"), open=first, fn(_close) {
          popup_test_button("one", on_click=fn() { clicks.push("one") })
        }),
        @view.popup(popup_test_button("anchor two"), open=second, fn(_close) {
          popup_test_button("two", on_click=fn() { clicks.push("two") })
        }),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  first.set(true)
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(clicks, ["two"])
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_false(second.get())
  assert_true(first.get())
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(clicks, ["two", "one"])
}

///|
test "popup keeps scoped themes and reactive local styles across the visual layer boundary" {
  let open = @reactive.signal(true)
  let width = @reactive.signal(100.0)
  let theme = @reactive.signal(@style.Theme(palette=@style.Palette::dark()))
  let root = @runtime.mount(
    fn() {
      @view.style_scope(light_theme=theme, inherit_styles=false, fn() {
        @view.popup(popup_test_button("anchor"), open~, focus=false, fn(
          _close,
        ) {
          @view.box(
            style=@style.BoxStyle()
              .width(width)
              .height(40.0)
              .background(@style.accent_token),
          ).debug(name="pane")
        })
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  root.paint(ScrollRecorder(), size~)
  let before = popup_node(root)
  assert_eq(
    before.theme.resolve(@style.surface_token),
    theme.peek().resolve(@style.surface_token),
  )
  assert_eq(before.frame.size.width, 100.0)
  width.set(120.0)
  root.paint(ScrollRecorder(), size~)
  assert_eq(popup_node(root).frame.size.width, 120.0)
  theme.set(@style.Theme())
  root.paint(ScrollRecorder(), size~)
  assert_eq(
    popup_node(root).theme.resolve(@style.surface_token),
    @style.Theme().resolve(@style.surface_token),
  )
  assert_eq(popup_node(root).id, before.id)
}

///|
test "popup dismissal skips the default model write when its handler detaches the owner" {
  let open = @reactive.signal(true)
  let visible = @reactive.signal(true)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @view.popup(
          popup_test_button("anchor"),
          open~,
          on_change=fn(_) { visible.set(false) },
          fn(_close) { popup_test_button("entry") },
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyEscape)))
  assert_true(open.get())
  assert_true(root.view().popup_targets().is_empty())
}

///|
test "popup infrastructure does not apply global flex styles a second time" {
  let open = @reactive.signal(true)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.popup(popup_test_button("anchor"), open~, focus=false, fn(
          _close,
        ) {
          @view.box(style=@style.BoxStyle().width(100.0).height(40.0))
        }),
      ])
    },
    theme=@style.Theme(
      styles=@style.Styles().add(
        @view.FlexStyle().padding(@foundation.Insets::all(10.0)),
      ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root.paint(ScrollRecorder(), size=Size(width=200.0, height=200.0))
  assert_eq(
    popup_node(root).frame,
    Rect(x=10.0, y=38.0, width=100.0, height=40.0),
  )
  assert_eq(popup_node(root).style_type, None)
}

///|
test "disabling only the anchor suspends popup focus input and painting" {
  let open = @reactive.signal(true)
  let disabled = @reactive.signal(false)
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.popup(@controls.button("anchor", disabled~), open~, fn(_close) {
        popup_test_button("entry", on_click=fn() { clicks.val += 1 })
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  disabled.set(true)
  assert_true(root.view().popup_targets().is_empty())
  assert_false(root.key_down(test_key_event(KeyEnter)))
  let size = @foundation.Size(width=200.0, height=200.0)
  let renderer = ScrollRecorder()
  root.paint(renderer, size~)
  assert_true(popup_node(root).clip.is_empty())
  assert_eq(renderer.fills.length(), 1)
  disabled.set(false)
  assert_true(root.key_down(test_key_event(KeyEnter)))
  assert_eq(clicks.val, 1)
}

///|
test "popup outside press never calls a stale dismiss handler after measurement disposes the root" {
  let open = @reactive.signal(true)
  let owner : Ref[@runtime.UiRoot?] = Ref(None)
  let changes = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.popup(
        popup_test_button("anchor"),
        open~,
        on_change=fn(_) { changes.val += 1 },
        fn(_close) { @view.text("measured popup") },
      )
    },
    text_layout_system=test_text_layout_system(on_measure=fn() {
      if owner.val is Some(root) {
        root.dispose()
      }
    }),
  )
  defer root.dispose()
  owner.val = Some(root)
  assert_true(
    root.pointer_down(
      size=Size(width=200.0, height=200.0),
      point=Point(x=190.0, y=190.0),
    ),
  )
  assert_true(root.is_disposed())
  assert_eq(changes.val, 0)
  assert_true(open.get())
}

///|
test "visible popup content overflow is inside for dismissal and pointer input" {
  let open = @reactive.signal(true)
  let clicks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.popup(popup_test_button("anchor"), open~, focus=false, fn(_close) {
        @view.interactive(
          @view.box(style=@style.BoxStyle().width(100.0).height(40.0)),
          on_click=fn() { clicks.val += 1 },
        ).translated(Point(x=80.0, y=0.0))
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=200.0)
  assert_true(root.click_at(size~, point=Point(x=140.0, y=35.0)))
  assert_true(open.get())
  assert_eq(clicks.val, 1)
}
