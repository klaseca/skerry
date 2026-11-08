///|
test "directly nested theme providers keep the closest theme on the same node" {
  let mode = @reactive.signal(false)
  let light = @style.Theme()
  let dark = @style.Theme(palette=@style.Palette::dark())
  let root = @runtime.mount(
    fn() {
      @view.style_scope(
        light_theme=@reactive.bind(fn() {
          if mode.get() {
            dark
          } else {
            light
          }
        }),
        inherit_styles=false,
        fn() {
          @view.style_scope(light_theme=dark, inherit_styles=false, fn() {
            @controls.button("button")
          })
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=50.0)
  root.paint(renderer, size~)
  assert_eq(root.snapshot().unwrap().tree.nodes.length(), 1)
  assert_eq(root.snapshot().unwrap().tree.nodes[0].theme, dark)
  mode.set(true)
  assert_false(root.needs_frame())
  mode.set(false)
  assert_false(root.needs_frame())
}

///|
test "subtree theme and nested derived theme update paint while keeping input and layout" {
  let dark = @reactive.signal(false)
  let accent = @foundation.Color::rgb(r=200, g=50, b=80)
  let initial : Array[@style.Theme] = []
  let root = @runtime.mount(
    fn() {
      @view.style_scope(
        light_theme=@reactive.bind(fn() {
          if dark.get() {
            @style.Theme(palette=@style.Palette::dark())
          } else {
            Theme()
          }
        }),
        inherit_styles=false,
        fn() {
          initial.push(@environment.current_theme())
          @view.column([
            @controls.text_input(
              value=@reactive.signal("input"),
              style=@controls.TextInputStyle().surface(
                @style.BoxStyle().height(40.0),
              ),
            ),
            @view.style_scope(
              light_theme=@reactive.bind(fn() {
                let parent = @environment.current_theme()
                parent.token(@style.accent_token, accent)
              }),
              fn() {
                initial.push(@environment.current_theme())
                @controls.checkbox(
                  label="checked",
                  checked=@reactive.signal(true),
                )
              },
            ),
          ])
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_eq(initial[0], Theme())
  assert_eq(initial[1].resolve(@style.accent_token), accent)
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=180.0, height=100.0)
  assert_true(root.pointer_down(size~, point=Point(x=12.0, y=12.0)))
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  dark.set(true)
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap()
  assert_eq(after.theme, Theme())
  assert_eq(after.tree.nodes.length(), 3)
  assert_eq(
    after.tree.nodes[0].theme.tokens,
    @style.Theme(palette=@style.Palette::dark()).tokens,
  )
  assert_eq(
    after.tree.nodes[1].computed_style.unwrap().background,
    Some(@style.Palette::dark().control_surface),
  )
  assert_eq(renderer.fills[0].0, @style.Palette::dark().control_surface)
  assert_eq(after.tree.nodes[2].theme.resolve(@style.accent_token), accent)
  assert_eq(
    after.tree.nodes[2].theme.resolve(@style.control_surface_token),
    @style.Palette::dark().control_surface,
  )
  assert_eq(
    after.tree.nodes[2].computed_style.unwrap().marker_color,
    Some(accent),
  )
  assert_eq(after.focused_node_id, before.focused_node_id)
  assert_eq(after.captured_node_id, before.captured_node_id)
  assert_eq(after.frame.layout_count, before.frame.layout_count)
  assert_eq(after.frame.text_measure_count, before.frame.text_measure_count)
  for index in 0..<before.tree.nodes.length() {
    assert_eq(after.tree.nodes[index].id, before.tree.nodes[index].id)
    assert_eq(after.tree.nodes[index].frame, before.tree.nodes[index].frame)
  }
}

///|
test "equal subtree themes stay idle and provider source stops with its branch" {
  let visible = @reactive.signal(true)
  let mode = @reactive.signal(0)
  let reads = Ref(0)
  let builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.show(fn() { visible.get() }, fn() {
        @view.style_scope(
          light_theme=@reactive.bind(fn() {
            reads.val += 1
            if mode.get() == 0 {
              @style.Theme()
            } else {
              Theme(palette=@style.Palette::dark())
            }
          }),
          inherit_styles=false,
          fn() {
            builds.val += 1
            @controls.button("button")
          },
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=60.0)
  root.paint(renderer, size~)
  assert_eq(reads.val, 1)
  mode.set(1)
  root.paint(renderer, size~)
  mode.set(2)
  assert_eq(reads.val, 3)
  assert_eq(builds.val, 1)
  assert_false(root.needs_frame())
  visible.set(false)
  root.paint(renderer, size~)
  mode.set(0)
  assert_eq(reads.val, 3)
  assert_false(root.needs_frame())
  visible.set(true)
  root.paint(renderer, size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].theme, Theme())
  assert_eq(builds.val, 2)
}

///|
test "scoped theme resolves scrollbar paint and input from the same geometry" {
  let reads = Ref(0)
  let offset = @reactive.signal(0.0)
  let dark = @style.Theme(palette=@style.Palette::dark())
  let root = @runtime.mount(
    fn() {
      @view.style_scope(
        light_theme=@reactive.bind(fn() {
          reads.val += 1
          dark
        }),
        inherit_styles=false,
        fn() { @view.scroll_view(@view.fill_box(200.0), offset~) },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=60.0)
  root.paint(renderer, size~)
  let node = root.snapshot().unwrap().tree.nodes[0]
  let scrollbar = node.scroll.unwrap().scrollbar.unwrap()
  assert_eq(scrollbar.track_color, dark.resolve(@style.scrollbar_track_token))
  assert_eq(scrollbar.thumb_color, dark.resolve(@style.scrollbar_thumb_token))
  assert_eq(
    renderer.fills[renderer.fills.length() - 2].0,
    scrollbar.track_color,
  )
  assert_eq(
    renderer.fills[renderer.fills.length() - 1].0,
    scrollbar.thumb_color,
  )
  let start = @foundation.Point(
    x=scrollbar.thumb.origin.x + 4.0,
    y=scrollbar.thumb.origin.y + 4.0,
  )
  assert_true(root.pointer_down(size~, point=start))
  assert_true(
    root.pointer_move(size~, point=Point(x=start.x, y=start.y + 15.0)),
  )
  assert_true(offset.get() > 0.0)
  assert_true(root.pointer_up(size~, point=Point(x=start.x, y=start.y + 15.0)))
  root.paint(renderer, size~)
  ignore(root.snapshot())
  assert_eq(reads.val, 1)
}

///|
test "a subtree theme changed during paint rejects a mixed snapshot" {
  let dark = @reactive.signal(false)
  let first = Ref(true)
  let root = @runtime.mount(
    fn() {
      @view.style_scope(
        light_theme=@reactive.bind(fn() {
          if dark.get() {
            @style.Theme(palette=@style.Palette::dark())
          } else {
            Theme()
          }
        }),
        inherit_styles=false,
        fn() {
          @view.column([
            @view.element(
              style=@style.BoxStyle(),
              painter=@view.Painter(fn(_, _) {
                if first.val {
                  first.val = false
                  dark.set(true)
                }
              }),
            ),
            @controls.button("button"),
          ])
        },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=70.0)
  root.paint(renderer, size~)
  assert_eq(root.snapshot(), None)
  assert_true(root.needs_frame())
  root.paint(renderer, size~)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[2].theme.tokens,
    @style.Theme(palette=@style.Palette::dark()).tokens,
  )
}

///|
test "subtree callbacks read the subtree theme rather than the root theme" {
  let dark = @style.Theme(palette=@style.Palette::dark())
  let seen : Array[@style.Theme] = []
  let root = @runtime.mount(
    fn() {
      @view.style_scope(light_theme=dark, inherit_styles=false, fn() {
        @controls.button(
          "button",
          on_focus=fn() { seen.push(@environment.current_theme()) },
          on_click=fn() { seen.push(@environment.current_theme()) },
        )
      })
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(
    root.click_at(
      size=Size(width=150.0, height=50.0),
      point=Point(x=12.0, y=12.0),
    ),
  )
  assert_eq(root.theme(), Theme())
  assert_eq(seen, [dark, dark])
}

///|
test "custom hosts apply subtree theme notifications without losing cached layout" {
  let scope = @reactive.Scope::root()
  defer scope.dispose()
  let dark = @reactive.signal(false)
  let view = scope.run(fn() {
    @view.style_scope(
      light_theme=@reactive.bind(fn() {
        if dark.get() {
          @style.Theme(palette=@style.Palette::dark())
        } else {
          Theme()
        }
      }),
      inherit_styles=false,
      fn() { @controls.button("button") },
    )
  })
  let layout = @view.LayoutState(text_layout_system=test_text_layout_system())
  defer layout.dispose()
  let paints = Ref(0)
  let stop = scope.run(fn() {
    view.mount_reactivity(
      mark_layout_dirty=fn() { abort("unexpected layout") },
      mark_paint_dirty=fn() { paints.val += 1 },
      on_theme_change=fn(id, theme) {
        if layout.set_theme_override(id, theme) {
          paints.val += 1
        }
      },
    )
  })
  defer stop()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=50.0)
  layout.paint(view, size~, renderer, focused_path=None)
  dark.set(true)
  assert_eq(layout.snapshot(view), None)
  layout.paint(view, size~, renderer, focused_path=None)
  assert_eq(
    layout.snapshot(view).unwrap().nodes[0].theme.tokens,
    @style.Theme(palette=@style.Palette::dark()).tokens,
  )
  assert_eq(layout.last_paint_stats().unwrap().layout_count, 0)
  assert_eq(paints.val, 2)
}
