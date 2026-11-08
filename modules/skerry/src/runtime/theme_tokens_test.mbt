///|
test "shared local styles and inherited class rules resolve in each consuming palette" {
  let brand = @style.ThemeToken(
    "CardBorder",
    fallback=@foundation.Color::black(),
  )
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let blue = @foundation.Color::rgb(r=30, g=70, b=190)
  let green = @foundation.Color::rgb(r=40, g=170, b=80)
  let shared = @style.BoxStyle()
    .width(90.0)
    .height(30.0)
    .background(@style.accent_token)
    .stroke(brand)
  let local_theme = @style.Theme(palette={ ..Palette(), accent: green, })
  let builds = Ref(0)
  let root = @runtime.mount(
    fn() {
      builds.val += 1
      @view.style_scope(styles=@style.Styles().add(shared)) <| fn() {
        @view.column([
          @view.box(style=shared),
          @view.style_scope(light_theme=local_theme) <| fn() {
            @view.column([
              @view.box(),
              @view.box(
                style=@style.BoxStyle().width(90.0).height(30.0).background(red),
              ),
            ])
          },
        ])
      }
    },
    theme=@style.Theme().token(@style.accent_token, blue).token(brand, red),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=200.0, height=150.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap().tree.nodes
  let layouts = root.frame_stats().layout_count
  assert_eq(before[1].computed_style.unwrap().background, Some(blue))
  assert_eq(before[3].computed_style.unwrap().background, Some(green))
  assert_eq(before[3].computed_style.unwrap().stroke_color, Some(red))
  assert_eq(before[4].computed_style.unwrap().background, Some(red))
  assert_eq(
    before[1].specified_style.unwrap().layout.paint.background,
    Some(Token(@style.accent_token)),
  )
  root.set_theme(
    @style.Theme(palette=@style.Palette::dark()).token(brand, blue),
  )
  assert_eq(root.dirty(), NeedsPaint)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap().tree.nodes
  assert_eq(
    after[1].computed_style.unwrap().background,
    Some(@style.Palette::dark().accent),
  )
  assert_eq(after[3].computed_style.unwrap().background, Some(green))
  assert_eq(after[3].computed_style.unwrap().stroke_color, Some(blue))
  assert_eq(after[4].computed_style.unwrap().background, Some(red))
  assert_eq(renderer.fills[1].0, green)
  assert_eq(root.frame_stats().layout_count, layouts)
  assert_eq(builds.val, 1)
  for i in 0..<before.length() {
    assert_eq(before[i].id, after[i].id)
  }
}

///|
test "unified scopes keep application overlays across a new base theme and can isolate them" {
  let green = @foundation.Color::rgb(r=40, g=170, b=80)
  let local_theme = @style.Theme(
    palette={ ..Palette(), accent: green, },
    styles=@style.Styles().add(
      @controls.ButtonStyle().surface(@style.BoxStyle().height(70.0)),
    ),
  )
  let root = @runtime.mount(
    fn() {
      @view.style_scope(
        styles=@style.Styles().add(
          @controls.ButtonStyle().surface(
            @style.BoxStyle().height(54.0).background(@style.accent_token),
          ),
        ),
      ) <| fn() {
        @view.column([
          @view.style_scope(light_theme=local_theme, fn() {
            @controls.button("inherited")
          }),
          @view.style_scope(light_theme=local_theme, inherit_styles=false, fn() {
            @controls.button("isolated")
          }),
          @view.style_scope(light_theme=local_theme, fn() {
            @controls.button(
              "local",
              style=@controls.ButtonStyle().surface(
                @style.BoxStyle().height(31.0),
              ),
            )
          }),
        ])
      }
    },
    theme=Theme(
      styles=@style.Styles().add(
        @controls.ButtonStyle().surface(@style.BoxStyle().height(40.0)),
      ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=240.0, height=240.0))
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes[1].frame.size.height, 54.0)
  assert_eq(nodes[2].frame.size.height, 70.0)
  assert_eq(nodes[3].frame.size.height, 31.0)
  for i in 1..<4 {
    assert_eq(nodes[i].computed_style.unwrap().background, Some(green))
  }
}

///|
test "equal App themes still switch subtree variants and settle before wakeup" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let green = @foundation.Color::rgb(r=40, g=170, b=80)
  let builds = Ref(0)
  let app = @runtime.App(
    theme_mode=Light,
    light_theme=@style.Theme(),
    dark_theme=@style.Theme(),
    content=fn() {
      @view.style_scope(
        light_theme=@style.Theme(palette=Palette(accent=red)),
        dark_theme=@style.Theme(
          font=@foundation.FontSpec::default().size(22.0),
          palette=Palette(accent=green),
        ),
      ) <| fn() {
        builds.val += 1
        @controls.button("variant")
      }
    },
  )
  let root = app.mount(text_layout_system=test_text_layout_system())
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=220.0, height=70.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap().tree.nodes[0]
  let seen : Array[(@style.ColorScheme, @foundation.Color?, Double)] = []
  root.set_wakeup(fn() {
    root.paint(renderer, size~)
    if root.snapshot() is Some(snapshot) {
      let computed = snapshot.tree.nodes[0].computed_style.unwrap()
      seen.push(
        (
          root.color_scheme(),
          computed.background,
          computed.font.unwrap().point_size(),
        ),
      )
    }
  })
  app.set_theme_mode(Dark)
  assert_eq(root.theme(), Theme())
  assert_eq(root.color_scheme(), Dark)
  assert_true(!seen.is_empty())
  for entry in seen {
    assert_eq(entry, (Dark, Some(green), 22.0))
  }
  let after = root.snapshot().unwrap().tree.nodes[0]
  assert_eq(after.id, before.id)
  assert_eq(builds.val, 1)
  let count = seen.length()
  app.set_theme_mode(Dark)
  assert_eq(seen.length(), count)
}

///|
test "missing variants follow the selected parent scheme independently for each App root" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let green = @foundation.Color::rgb(r=40, g=170, b=80)
  let app = @runtime.App(
    dark_theme=@style.Theme(palette=Palette(accent=green)),
    content=fn() {
      @view.style_scope(light_theme=@style.Theme(palette=Palette(accent=red))) <| fn() {
        @view.box(
          style=@style.BoxStyle()
            .width(70.0)
            .height(30.0)
            .background(@style.accent_token),
        )
      }
    },
  )
  let first = app.mount(
    text_layout_system=test_text_layout_system(),
    system_theme=Light,
  )
  defer first.dispose()
  let second = app.mount(
    text_layout_system=test_text_layout_system(),
    system_theme=Dark,
  )
  defer second.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=60.0)
  first.paint(renderer, size~)
  second.paint(renderer, size~)
  assert_eq(
    first.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().background,
    Some(red),
  )
  assert_eq(
    second.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().background,
    Some(green),
  )
  first.set_system_theme(Some(Dark))
  first.paint(renderer, size~)
  assert_eq(
    first.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().background,
    Some(green),
  )
  assert_false(second.needs_frame())
  assert_eq(app.theme_mode(), System)
  app.set_theme_mode(Light)
  first.paint(renderer, size~)
  second.paint(renderer, size~)
  assert_eq(
    second.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().background,
    Some(red),
  )
}

///|
test "a shared theme binding has per-root subscriptions and snapshots do not run sources" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let green = @foundation.Color::rgb(r=40, g=170, b=80)
  let key = @style.ThemeToken("Brand", fallback=red)
  let color = @reactive.signal(red)
  let reads = Ref(0)
  let app = @runtime.App(
    light_theme=@reactive.bind(fn() {
      reads.val += 1
      @style.Theme().token(key, color.get())
    }),
    content=fn() {
      @view.box(
        style=@style.BoxStyle().width(70.0).height(30.0).background(key),
      )
    },
  )
  let first = app.mount(text_layout_system=test_text_layout_system())
  let second = app.mount(text_layout_system=test_text_layout_system())
  defer second.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=60.0)
  first.paint(renderer, size~)
  second.paint(renderer, size~)
  assert_eq(reads.val, 2)
  ignore(first.snapshot())
  ignore(second.snapshot())
  assert_eq(reads.val, 2)
  color.set(green)
  assert_eq(reads.val, 4)
  first.paint(renderer, size~)
  second.paint(renderer, size~)
  assert_eq(
    second.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().background,
    Some(green),
  )
  first.dispose()
  color.set(red)
  assert_eq(reads.val, 5)
  second.paint(renderer, size~)
  assert_eq(
    second.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().background,
    Some(red),
  )
  assert_eq(reads.val, 5)
}

///|
test "control decoration tokens and plain input colors use the same concrete palette" {
  let marker = @style.ThemeToken("Marker", fallback=@foundation.Color::black())
  let caret = @style.ThemeToken("Caret", fallback=@foundation.Color::black())
  let placeholder = @style.ThemeToken(
    "Placeholder",
    fallback=@foundation.Color::black(),
  )
  let selection = @style.ThemeToken(
    "Selection",
    fallback=@foundation.Color::black(),
  )
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let green = @foundation.Color::rgb(r=40, g=170, b=80)
  let theme = @style.Theme(
      styles=@style.Styles()
        .add(@controls.CheckboxStyle().marker_color(marker))
        .add(
          @controls.TextInputStyle()
          .caret_color(caret)
          .placeholder(@view.TextStyle().color(placeholder))
          .selection_color(selection),
        ),
    )
    .token(marker, red)
    .token(caret, green)
    .token(placeholder, red)
    .token(selection, green)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.checkbox(
          checked=@reactive.signal(true),
          style=@controls.CheckboxStyle().frame(@style.BoxStyle().height(30.0)),
        ),
        @controls.text_input(
          placeholder="Hint",
          style=@controls.TextInputStyle().surface(
            @style.BoxStyle().width(180.0).height(40.0),
          ),
        ),
      ])
    },
    theme~,
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=200.0, height=100.0))
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes[1].computed_style.unwrap().marker_color, Some(red))
  assert_eq(renderer.fills[1].0, red)
  let input = nodes[2].computed_style.unwrap()
  assert_eq(input.caret_color, Some(green))
  assert_eq(input.placeholder_color, Some(red))
  assert_eq(input.selection_color, Some(green))
  assert_true(renderer.text.any(run => run.text == "Hint" && run.color == red))
  let layouts = root.frame_stats().layout_count
  root.set_theme(theme.token(marker, green).token(placeholder, green))
  root.paint(renderer, size=Size(width=200.0, height=100.0))
  assert_eq(renderer.fills[1].0, green)
  assert_true(
    renderer.text.any(run => run.text == "Hint" && run.color == green),
  )
  assert_eq(root.frame_stats().layout_count, layouts)
}

///|
test "disabled token colors fade once and explicit state overrides remain literal" {
  let key = @style.ThemeToken("Control", fallback=@foundation.Color::accent())
  let color = @foundation.Color::rgba(r=120, g=150, b=180, a=200)
  let theme = @style.Theme(palette=@style.Palette::dark()).token(key, color)
  let style = @style.BoxStyle()
    .width(100.0)
    .height(40.0)
    .background(key)
    .color(@style.on_accent_token)
    .disabled(@style.Appearance().color(@style.text_token))
  for kind in 0..<4 {
    let root = @runtime.mount(
      fn() { state_test_control(kind, style, true) },
      theme~,
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let renderer = StyleRecorder()
    root.paint(renderer, size=Size(width=150.0, height=50.0))
    let computed = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
    assert_eq(computed.background, Some({ ..color, a: color.a * 0.45, }))
    assert_eq(computed.color, Some(theme.resolve(@style.text_token)))
    assert_eq(renderer.fills[0].0, computed.background.unwrap())
  }
}

///|
test "active state token appearances retheme without losing focus or pointer capture" {
  let style = @style.BoxStyle()
    .width(120.0)
    .height(40.0)
    .background(@style.accent_token)
    .hovered(@style.Appearance().background(@style.selection_token))
    .focused(@style.Appearance().color(@style.on_accent_token))
    .pressed(@style.Appearance().stroke(@style.border_token, width=3.0))
  let root = @runtime.mount(
    fn() {
      @controls.button("active", style=@controls.ButtonStyle().surface(style))
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=160.0, height=60.0)
  root.paint(renderer, size~)
  assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  let node = before.tree.nodes[0]
  assert_true(node.state.pressed && node.state.hovered && node.state.focused)
  assert_eq(
    node.computed_style.unwrap().background,
    Some(@style.Palette().selection),
  )
  let layouts = root.frame_stats().layout_count
  let dark = @style.Theme(palette=@style.Palette::dark())
  root.set_theme(dark)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap()
  let computed = after.tree.nodes[0].computed_style.unwrap()
  assert_eq(after.captured_node_id, before.captured_node_id)
  assert_eq(after.focused_node_id, before.focused_node_id)
  assert_eq(after.tree.nodes[0].state, node.state)
  assert_eq(computed.background, Some(dark.resolve(@style.selection_token)))
  assert_eq(computed.color, Some(dark.resolve(@style.on_accent_token)))
  assert_eq(computed.stroke_color, Some(dark.resolve(@style.border_token)))
  assert_eq(computed.stroke_width, Some(3.0))
  assert_eq(renderer.fills[0].0, dark.resolve(@style.selection_token))
  assert_eq(renderer.strokes[0].0, dark.resolve(@style.border_token))
  assert_eq(root.frame_stats().layout_count, layouts)
}

///|
test "custom scrollbar token colors and default projections preserve geometry" {
  let key = @style.ThemeToken("Track", fallback=@foundation.Color::black())
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let green = @foundation.Color::rgb(r=40, g=170, b=80)
  let theme = @style.Theme(palette=@style.Palette::dark()).token(key, red)
  for explicit in [true, false] {
    let scrollbar_style = if explicit {
      @style.ScrollbarStyle()
      .thickness(24.0)
      .track_color(key)
      .thumb_color(@style.accent_token)
    } else {
      @style.ScrollbarStyle().thickness(24.0)
    }
    let root = @runtime.mount(
      fn() { @view.scroll_view(@view.fill_box(300.0), scrollbar_style~) },
      theme~,
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let renderer = StyleRecorder()
    let size = @foundation.Size(width=140.0, height=100.0)
    root.paint(renderer, size~)
    let before = root.snapshot().unwrap().tree.nodes[0].scroll.unwrap().scrollbar.unwrap()
    assert_eq(
      before.track_color,
      if explicit {
        red
      } else {
        theme.resolve(@style.scrollbar_track_token)
      },
    )
    assert_eq(
      before.thumb_color,
      if explicit {
        theme.resolve(@style.accent_token)
      } else {
        theme.resolve(@style.scrollbar_thumb_token)
      },
    )
    let layouts = root.frame_stats().layout_count
    root.set_theme(theme.token(key, green).token(@style.accent_token, green))
    root.paint(renderer, size~)
    let after = root.snapshot().unwrap().tree.nodes[0].scroll.unwrap().scrollbar.unwrap()
    assert_eq(after.style, scrollbar_style)
    assert_eq(after.track, before.track)
    assert_eq(after.thumb, before.thumb)
    assert_eq(
      after.track_color,
      if explicit {
        green
      } else {
        theme.resolve(@style.scrollbar_track_token)
      },
    )
    assert_eq(renderer.fills[renderer.fills.length() - 2].0, after.track_color)
    assert_eq(renderer.fills[renderer.fills.length() - 1].0, after.thumb_color)
    assert_eq(root.frame_stats().layout_count, layouts)
  }
}

///|
test "low-level hosts can change scheme atomically without changing Theme data" {
  let root = @runtime.mount(
    fn() {
      @view.style_scope(
        light_theme=@style.Theme(
          font=@foundation.FontSpec::default().size(18.0),
        ),
        dark_theme=@style.Theme(font=@foundation.FontSpec::default().size(24.0)),
      ) <| fn() { @view.text("scheme") }
    },
    color_scheme=Dark,
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=160.0, height=60.0)
  root.paint(renderer, size~)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().font
    .unwrap()
    .point_size(),
    24.0,
  )
  root.set_theme(Theme(), color_scheme=Light)
  root.paint(renderer, size~)
  assert_eq(root.color_scheme(), Light)
  assert_eq(
    root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap().font
    .unwrap()
    .point_size(),
    18.0,
  )
}

///|
test "App reads only the active theme source and drops inactive dependencies" {
  let light = @reactive.signal(@style.Theme())
  let dark = @reactive.signal(@style.Theme(palette=@style.Palette::dark()))
  let reads = Ref(0)
  let dark_theme = @reactive.computed(fn() {
    reads.val += 1
    dark.get()
  })
  let app = @runtime.App(theme_mode=Light, light_theme=light, dark_theme~, content=fn() {
    @controls.button("active")
  })
  assert_eq(reads.val, 0)
  let root = app.mount(text_layout_system=test_text_layout_system())
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=160.0, height=60.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap().tree.nodes[0]
  assert_eq(reads.val, 0)
  let new_dark = @style.Theme(palette=@style.Palette::dark()).token(
    @style.accent_token,
    @foundation.Color::black(),
  )
  dark.set(new_dark)
  assert_false(root.needs_frame())
  assert_eq(reads.val, 0)
  app.set_theme_mode(Dark)
  root.paint(renderer, size~)
  assert_eq(root.theme(), new_dark)
  assert_eq(reads.val, 1)
  let new_light = @style.Theme(font=@foundation.FontSpec::default().size(22.0))
  light.set(new_light)
  assert_false(root.needs_frame())
  app.set_theme_mode(Light)
  root.paint(renderer, size~)
  assert_eq(root.theme(), new_light)
  assert_eq(root.snapshot().unwrap().tree.nodes[0].id, before.id)
  dark.set(Theme())
  assert_false(root.needs_frame())
  assert_eq(reads.val, 1)
  root.dispose()
  light.set(Theme())
  assert_eq(reads.val, 1)
}

///|
test "scope variants subscribe only while selected and stop on disposal" {
  let light = @reactive.signal(@style.Theme())
  let dark = @reactive.signal(@style.Theme(palette=@style.Palette::dark()))
  let light_reads = Ref(0)
  let dark_reads = Ref(0)
  let app = @runtime.App(theme_mode=Light, content=fn() {
    @view.style_scope(
      light_theme=@reactive.bind(fn() {
        light_reads.val += 1
        light.get()
      }),
      dark_theme=@reactive.bind(fn() {
        dark_reads.val += 1
        dark.get()
      }),
    ) <| fn() { @controls.button("scoped") }
  })
  assert_eq((light_reads.val, dark_reads.val), (0, 0))
  let root = app.mount(text_layout_system=test_text_layout_system())
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=160.0, height=60.0)
  root.paint(renderer, size~)
  assert_eq((light_reads.val, dark_reads.val), (1, 0))
  let custom_dark = @style.Theme(palette=@style.Palette::dark()).token(
    @style.accent_token,
    @foundation.Color::black(),
  )
  dark.set(custom_dark)
  assert_false(root.needs_frame())
  app.set_theme_mode(Dark)
  root.paint(renderer, size~)
  assert_eq((light_reads.val, dark_reads.val), (1, 1))
  assert_eq(root.snapshot().unwrap().tree.nodes[0].theme, custom_dark)
  light.set(Theme(font=@foundation.FontSpec::default().size(22.0)))
  assert_false(root.needs_frame())
  ignore(root.snapshot())
  root.paint(renderer, size~)
  assert_eq((light_reads.val, dark_reads.val), (1, 1))
  app.set_theme_mode(Light)
  root.paint(renderer, size~)
  assert_eq((light_reads.val, dark_reads.val), (2, 1))
  assert_eq(
    root.snapshot().unwrap().tree.nodes[0].theme.font.point_size(),
    22.0,
  )
  root.dispose()
  light.set(Theme())
  dark.set(Theme())
  assert_eq((light_reads.val, dark_reads.val), (2, 1))
}

///|
test "nested partial variants inherit the selected parent instead of the opposite variant" {
  let red = @foundation.Color::rgb(r=180, g=40, b=50)
  let green = @foundation.Color::rgb(r=40, g=170, b=80)
  let light = @style.Theme(palette=Palette(accent=red))
  let dark = @style.Theme(palette={ ..@style.Palette::dark(), accent: green, })
  let builds = Ref(0)
  let app = @runtime.App(theme_mode=Light, content=fn() {
    @view.style_scope(light_theme=light) <| fn() {
      @view.column([
        @view.style_scope(dark_theme=dark) <| fn() {
          builds.val += 1
          @controls.button("nested")
        },
        @controls.button("outer"),
      ])
    }
  })
  let root = app.mount(text_layout_system=test_text_layout_system())
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=200.0, height=120.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap().tree.nodes
  assert_eq(before[1].theme, light)
  assert_eq(before[2].theme, light)
  app.set_theme_mode(Dark)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap().tree.nodes
  assert_eq(after[1].theme, dark)
  assert_eq(after[2].theme, root.theme())
  assert_eq(after[1].id, before[1].id)
  app.set_theme_mode(Light)
  root.paint(renderer, size~)
  assert_eq(root.snapshot().unwrap().tree.nodes[1].theme, light)
  assert_eq(builds.val, 1)
}

///|
test "ordinary parent theme bindings retain effective styles once in both schemes" {
  let font_size = @reactive.signal(20.0)
  let app = @runtime.App(theme_mode=Light, content=fn() {
    @view.style_scope(
      styles=@style.Styles().add(
        @controls.ButtonStyle().surface(@style.BoxStyle().radius(13.0)),
      ),
    ) <| fn() {
      let font_theme = @reactive.bind(fn() {
        let parent = @environment.current_theme()
        { ..parent, font: parent.font.size(font_size.get()), }
      })
      @view.style_scope(
        light_theme=font_theme,
        dark_theme=font_theme,
        inherit_styles=false,
      ) <| fn() { @controls.button("derived") }
    }
  })
  let root = app.mount(text_layout_system=test_text_layout_system())
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=180.0, height=70.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap().tree.nodes[0]
  assert_eq(
    (before.theme.styles.get() : ReadOnlyArray[@controls.ButtonStyle]).length(),
    1,
  )
  assert_eq(before.computed_style.unwrap().radius, Some(13.0))
  font_size.set(24.0)
  app.set_theme_mode(Dark)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap().tree.nodes[0]
  assert_eq(
    (after.theme.styles.get() : ReadOnlyArray[@controls.ButtonStyle]).length(),
    1,
  )
  assert_eq(
    after.theme.tokens,
    @style.Theme(palette=@style.Palette::dark()).tokens,
  )
  assert_eq(after.computed_style.unwrap().radius, Some(13.0))
  assert_eq(after.computed_style.unwrap().font.unwrap().point_size(), 24.0)
  assert_eq(after.id, before.id)
}
