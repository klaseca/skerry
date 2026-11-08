///|
test "theme font measures paints and diagnoses text and every labeled control" {
  let font = @foundation.FontSpec::default().size(24.0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.text(
          "text",
          style=@view.TextStyle().frame(@style.BoxStyle().shrink(0.0)),
        ),
        @controls.button(
          "button",
          style=@controls.ButtonStyle().surface(@style.BoxStyle().shrink(0.0)),
        ),
        @controls.checkbox(
          label="check",
          style=@controls.CheckboxStyle().frame(@style.BoxStyle().shrink(0.0)),
        ),
        @controls.radio(
          label="radio",
          style=@controls.RadioStyle().frame(@style.BoxStyle().shrink(0.0)),
        ),
        @controls.text_input(
          placeholder="hint",
          style=@controls.TextInputStyle().surface(
            @style.BoxStyle().shrink(0.0),
          ),
        ),
      ])
    },
    theme=Theme(font~),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=300.0, height=300.0))
  let snapshot = root.snapshot().unwrap()
  assert_eq(renderer.text.length(), 5)
  for run in renderer.text {
    assert_eq(run.font, font)
  }
  for i in 1..<snapshot.tree.nodes.length() {
    let node = snapshot.tree.nodes[i]
    assert_eq(node.computed_style.unwrap().font, Some(font))
    assert_eq(node.specified_style.unwrap().layout.text.font, None)
    assert_eq(
      node.frame.size.height,
      if node.component_name == "Button" || node.component_name == "TextInput" {
        46.0
      } else {
        30.0
      },
    )
  }
}

///|
test "nearest container font wins with local overrides and no sibling leakage" {
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.text("root"),
        @view.row(
          [
            @view.text("row"),
            @view.column(
              [
                @controls.button("nested"),
                @view.text(
                  "local",
                  style=@view.TextStyle().frame(
                    @style.BoxStyle().font(
                      @foundation.FontSpec::default().size(32.0),
                    ),
                  ),
                ),
              ],
              style=@view.FlexStyle().surface(
                @style.BoxStyle().font(
                  @foundation.FontSpec::default().size(26.0),
                ),
              ),
            ),
          ],
          style=@view.FlexStyle().surface(
            @style.BoxStyle().font(@foundation.FontSpec::default().size(20.0)),
          ),
        ),
        @view.text("sibling"),
      ])
    },
    theme=Theme(font=@foundation.FontSpec::default().size(18.0)),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=600.0, height=400.0))
  assert_eq(renderer.text.map(run => (run.text, run.font.point_size())), [
    ("root", 18.0),
    ("row", 20.0),
    ("nested", 26.0),
    ("local", 32.0),
    ("sibling", 18.0),
  ])
}

///|
test "font changes reflow without rebuilding and retain cached font metrics" {
  let builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      builds.val += 1
      @view.column([@view.text("abcd"), @controls.button("ok")])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=200.0, height=200.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  let large = @style.Theme(font=@foundation.FontSpec::default().size(32.0))
  root.set_theme(large)
  assert_eq(root.dirty(), NeedsLayout)
  assert_eq(root.snapshot(), None)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap()
  assert_eq(after.tree.nodes[1].frame.size.height, 40.0)
  assert_eq(after.frame.layout_count, before.frame.layout_count + 1)
  assert_true(after.frame.text_measure_count > before.frame.text_measure_count)
  for i in 0..<after.tree.nodes.length() {
    assert_eq(after.tree.nodes[i].id, before.tree.nodes[i].id)
  }
  root.set_theme(Theme())
  root.paint(renderer, size~)
  let restored = root.snapshot().unwrap()
  assert_eq(restored.frame.text_measure_count, after.frame.text_measure_count)
  assert_eq(restored.tree.nodes[1].frame, before.tree.nodes[1].frame)
  root.set_theme(Theme())
  assert_false(root.needs_frame())
  assert_eq(builds.val, 1)
}

///|
test "scoped theme font changes preserve scope views and explicit inheritance" {
  let size = @reactive.signal(20.0)
  let builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.style_scope(
          light_theme=@reactive.bind(fn() {
            {
              ..@environment.current_theme(),
              font: @foundation.FontSpec::default().size(size.get()),
            }
          }),
          fn() {
            builds.val += 1
            @view.column([
              @view.text("scoped"),
              @controls.button("scoped button"),
            ])
          },
        ),
        @view.column(
          [
            @view.style_scope(
              light_theme=@reactive.bind(fn() {
                @style.Theme(
                  font=@foundation.FontSpec::default().size(size.get()),
                )
              }),
              inherit_styles=false,
              fn() { @view.text("explicit ancestor") },
            ),
          ],
          style=@view.FlexStyle().surface(
            @style.BoxStyle().font(@foundation.FontSpec::default().size(28.0)),
          ),
        ),
        @view.text("outside"),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let viewport = @foundation.Size(width=400.0, height=350.0)
  root.paint(renderer, size=viewport)
  let before = root.snapshot().unwrap()
  size.set(24.0)
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size=viewport)
  let after = root.snapshot().unwrap()
  assert_eq(renderer.text.map(run => run.font.point_size()), [
    24.0, 24.0, 28.0, 16.0,
  ])
  for i in 0..<before.tree.nodes.length() {
    assert_eq(before.tree.nodes[i].id, after.tree.nodes[i].id)
  }
  assert_eq(after.tree.nodes[2].frame.size.height, 30.0)
  assert_eq(builds.val, 1)
}

///|
test "component instances resolve root and scoped fonts independently" {
  let create = fn() {
    @view.column([
      @view.text("shared"),
      @controls.text_input(placeholder="input"),
    ])
  }
  let first = @runtime.mount(
    create,
    theme=Theme(font=@foundation.FontSpec::default().size(18.0)),
    text_layout_system=test_text_layout_system(),
  )
  defer first.dispose()
  let second = @runtime.mount(
    create,
    theme=Theme(font=@foundation.FontSpec::default().size(30.0)),
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=400.0, height=200.0)
  first.paint(renderer, size~)
  assert_eq(renderer.text.map(run => run.font.point_size()), [18.0, 18.0])
  second.paint(renderer, size~)
  let second_snapshot = second.snapshot().unwrap()
  assert_eq(renderer.text.map(run => run.font.point_size()), [30.0, 30.0])
  first.set_theme(Theme(font=@foundation.FontSpec::default().size(22.0)))
  first.paint(renderer, size~)
  assert_eq(renderer.text.map(run => run.font.point_size()), [22.0, 22.0])
  assert_eq(second.snapshot(), Some(second_snapshot))
}

///|
test "changing font preserves owned input text focus cursor and selection" {
  let changes = Ref(0)
  let root = @runtime.mount(
    fn() { @controls.text_input(on_change=fn(_) { changes.val += 1 }) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=120.0, height=60.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_true(root.text_input("abcdef"))
  assert_true(root.key_down(test_key_event(KeyHome)))
  assert_true(root.key_down(test_shift_key_event(KeyArrowRight)))
  assert_true(root.key_down(test_shift_key_event(KeyArrowRight)))
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  assert_eq(root.copy_text(), Some("ab"))
  root.set_theme(Theme(font=@foundation.FontSpec::default().size(32.0)))
  root.paint(renderer, size~)
  assert_eq(root.copy_text(), Some("ab"))
  assert_eq(root.snapshot().unwrap().focused_node_id, before.focused_node_id)
  assert_true(root.text_input("X"))
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].text, "Xcdef")
  assert_eq(renderer.text[0].font.point_size(), 32.0)
  assert_eq(changes.val, 2)
}

///|
test "pointer caret uses inherited font before a new frame is painted" {
  let value = @reactive.signal("abcd")
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @controls.text_input(
            value~,
            style=@controls.TextInputStyle().surface(
              @style.BoxStyle().height(60.0).shrink(0.0),
            ),
          ),
        ],
        style=@view.FlexStyle().surface(
          @style.BoxStyle().font(@foundation.FontSpec::default().size(30.0)),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=300.0, height=100.0)
  // Padding 10 + two 18px advances. The default 16px font would choose index 4.
  let point = @foundation.Point(x=46.0, y=20.0)
  assert_true(root.pointer_down(size~, point~))
  assert_true(root.pointer_up(size~, point~))
  assert_true(root.text_input("X"))
  assert_eq(value.get(), "abXcd")
}

///|
test "pointer caret uses changed scoped font and updated horizontal scroll" {
  let font_size = @reactive.signal(16.0)
  let value = @reactive.signal("abcdefghij")
  let root = @runtime.mount(
    fn() {
      @view.style_scope(
        light_theme=@reactive.bind(fn() {
          @style.Theme(
            font=@foundation.FontSpec::default().size(font_size.get()),
          )
        }),
        inherit_styles=false,
        fn() { @controls.text_input(value~) },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=60.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  font_size.set(30.0)
  root.paint(renderer, size~)
  assert_true(renderer.text[0].frame.origin.x < 0.0)
  let point = @foundation.Point(
    x=renderer.text[0].frame.origin.x + 8.0 * 18.0,
    y=20.0,
  )
  assert_true(root.pointer_down(size~, point~))
  assert_true(root.pointer_up(size~, point~))
  assert_true(root.text_input("X"))
  assert_eq(value.get(), "abcdefghXij")
}

///|
test "dynamic and keyed children inherit current font while retaining identity" {
  let visible = @reactive.signal(false)
  let items = @reactive.signal([1, 2])
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @view.show(fn() { visible.get() }, fn() { @view.text("late") }),
          @view.for_each(fn() { items.get() }, fn(item) { item }, fn(item) {
            @view.text(@reactive.bind(fn() { item().to_string() }))
          }),
        ],
        style=@view.FlexStyle().surface(
          @style.BoxStyle().font(@foundation.FontSpec::default().size(24.0)),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=300.0, height=300.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  let first = before.tree.nodes[3].id
  let second = before.tree.nodes[4].id
  visible.set(true)
  items.set([2, 1, 3])
  root.set_theme(Theme(font=@foundation.FontSpec::default().size(32.0)))
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap()
  assert_eq(after.tree.nodes[4].id, second)
  assert_eq(after.tree.nodes[5].id, first)
  assert_eq(renderer.text.map(run => run.text), ["late", "2", "1", "3"])
  for run in renderer.text {
    assert_eq(run.font.point_size(), 24.0)
  }
}

///|
test "custom hosts invalidate layout for root and scoped fonts and reuse colors" {
  let scope = @reactive.Scope::root()
  defer scope.dispose()
  let theme = @reactive.signal(@style.Theme())
  let view = scope.run(fn() {
    @view.style_scope(light_theme=theme, inherit_styles=false, fn() {
      @view.text("host")
    })
  })
  let state = @view.LayoutState(text_layout_system=test_text_layout_system())
  defer state.dispose()
  let stop = scope.run(fn() {
    view.mount_reactivity(
      mark_layout_dirty=fn() { state.invalidate() },
      mark_paint_dirty=fn() { () },
      on_theme_change=fn(id, next) {
        ignore(state.set_theme_override(id, next))
      },
    )
  })
  defer stop()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=200.0, height=100.0)
  state.paint(view, size~, renderer, focused_path=None)
  assert_false(state.needs_layout())
  theme.set(Theme(font=@foundation.FontSpec::default().size(24.0)))
  assert_true(state.needs_layout())
  assert_eq(state.snapshot(view), None)
  state.paint(view, size~, renderer, focused_path=None)
  assert_eq(renderer.text[0].font.point_size(), 24.0)
  let count = state.layout_count()
  theme.set(
    Theme(
      font=@foundation.FontSpec::default().size(24.0),
      palette=@style.Palette::dark(),
    ),
  )
  assert_false(state.needs_layout())
  state.paint(view, size~, renderer, focused_path=None)
  assert_eq(state.layout_count(), count)
  let plain = @view.text("plain")
  state.invalidate()
  assert_true(
    state.set_theme(Theme(font=@foundation.FontSpec::default().size(28.0))),
  )
  state.paint(plain, size~, renderer, focused_path=None)
  assert_eq(renderer.text[0].font.point_size(), 28.0)
  state.dispose()
  assert_false(state.needs_layout())
}

///|
test "theme font changes reflow wrapping and scroll extents" {
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([
          @view.text(
            "abcdefghij",
            style=@view.TextStyle().frame(@style.BoxStyle().shrink(0.0)),
          ),
          @controls.button(
            "last",
            style=@controls.ButtonStyle().surface(@style.BoxStyle().shrink(0.0)),
          ),
        ]),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=60.0, height=50.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  root.set_theme(Theme(font=@foundation.FontSpec::default().size(32.0)))
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap()
  assert_true(
    after.tree.nodes[2].frame.size.height >
    before.tree.nodes[2].frame.size.height,
  )
  assert_true(
    after.tree.nodes[0].scroll.unwrap().max_offset >
    before.tree.nodes[0].scroll.unwrap().max_offset,
  )
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  assert_true(
    root.snapshot().unwrap().tree.nodes[0].scroll.unwrap().offset > 0.0,
  )
}

///|
test "root theme font and scoped dependent themes settle before synchronous wakeup" {
  let root = @runtime.mount(
    fn() { @view.style_scope(fn() { @view.text("settled") }) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=300.0, height=100.0)
  root.paint(renderer, size~)
  let fonts : Array[Double] = []
  root.set_wakeup(fn() {
    root.paint(renderer, size~)
    fonts.push(renderer.text[0].font.point_size())
  })
  root.set_theme(Theme(font=@foundation.FontSpec::default().size(28.0)))
  root.set_wakeup(fn() { () })
  assert_eq(fonts, [28.0])
  assert_false(root.needs_frame())
}

///|
test "fonts cross stack scroll and radio groups and reach custom painters" {
  let custom_fonts : Array[@foundation.FontSpec] = []
  let font = @foundation.FontSpec::default().size(24.0)
  let selected = @reactive.signal(1)
  let root = @runtime.mount(
    fn() {
      @view.column(
        [
          @view.stack([
            @view.scroll_view(
              @controls.radio_group(selected, [1, 2], label=fn(value) {
                value.to_string()
              }),
              style=@style.BoxStyle().height(100.0),
            ),
          ]),
          @view.element(
            style=@style.BoxStyle(),
            painter=@view.Painter(fn(context, _) {
              custom_fonts.push(context.font)
            }),
          ),
        ],
        style=@view.FlexStyle().surface(@style.BoxStyle().font(font)),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=300.0, height=200.0))
  assert_eq(renderer.text.map(run => run.font), [font, font])
  assert_eq(custom_fonts, [font])
}

///|
test "application theme modes update typography without reconstructing content" {
  let builds = Ref(0)
  let app = @runtime.App(
    light_theme=@style.Theme(font=@foundation.FontSpec::default().size(18.0)),
    dark_theme=@style.Theme(
      font=@foundation.FontSpec::default().size(26.0),
      palette=@style.Palette::dark(),
    ),
    theme_mode=Light,
    content=fn() {
      builds.val += 1
      @view.text("app")
    },
  )
  let root = app.mount(text_layout_system=test_text_layout_system())
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=200.0, height=100.0)
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].font.point_size(), 18.0)
  app.set_theme_mode(Dark)
  assert_eq(root.dirty(), NeedsLayout)
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].font.point_size(), 26.0)
  app.set_theme_mode(Light)
  root.paint(renderer, size~)
  assert_eq(renderer.text[0].font.point_size(), 18.0)
  assert_eq(builds.val, 1)
}

///|
test "pointer caret updates font-dependent scroll before the next paint" {
  let value = @reactive.signal("abcdefghij")
  let root = @runtime.mount(
    fn() { @controls.text_input(value~) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=60.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(renderer, size~)
  root.set_theme(Theme(font=@foundation.FontSpec::default().size(30.0)))
  let point = @foundation.Point(x=46.0, y=20.0)
  assert_true(root.pointer_down(size~, point~))
  assert_true(root.pointer_up(size~, point~))
  assert_true(root.text_input("X"))
  assert_eq(value.get(), "abcdefghXij")
}
