///|
test "component instances resolve independent root themes and palette changes reuse layout" {
  let create = fn() {
    @view.column([
      @view.text("text"),
      @controls.button("button"),
      @controls.checkbox(label="check", checked=@reactive.signal(true)),
      @controls.radio(label="radio", selected=@reactive.signal(true)),
      @controls.text_input(placeholder="hint"),
      @controls.button("disabled", disabled=true),
    ])
  }
  let light = @style.Theme()
  let dark = @style.Theme(palette=@style.Palette::dark())
  let builds = Ref(0)
  let a = @runtime.mount(
    fn() {
      builds.val += 1
      create()
    },
    text_layout_system=test_text_layout_system(),
  )
  defer a.dispose()
  let b = @runtime.mount(
    create,
    theme=dark,
    text_layout_system=test_text_layout_system(),
  )
  defer b.dispose()
  let size = @foundation.Size(width=240.0, height=200.0)
  let renderer = StyleRecorder()
  a.paint(renderer, size~)
  let before = a.snapshot().unwrap()
  b.paint(renderer, size~)
  let other = b.snapshot().unwrap()
  assert_eq(before.theme, light)
  assert_eq(other.theme, dark)
  assert_true(before.tree.nodes[2].id != other.tree.nodes[2].id)
  assert_eq(
    before.tree.nodes[1].computed_style.unwrap().color,
    Some(light.resolve(@style.text_token)),
  )
  assert_eq(
    other.tree.nodes[1].computed_style.unwrap().color,
    Some(dark.resolve(@style.text_token)),
  )
  assert_eq(
    other.tree.nodes[2].computed_style.unwrap().background,
    Some(dark.resolve(@style.accent_token)),
  )
  assert_eq(
    other.tree.nodes[3].computed_style.unwrap().marker_color,
    Some(dark.resolve(@style.accent_token)),
  )
  assert_eq(
    other.tree.nodes[4].computed_style.unwrap().marker_color,
    Some(dark.resolve(@style.accent_token)),
  )
  assert_eq(
    other.tree.nodes[5].computed_style.unwrap().placeholder_color,
    Some(dark.resolve(@style.muted_text_token)),
  )
  assert_eq(
    before.tree.nodes[6].computed_style.unwrap().background,
    Some({ ..light.resolve(@style.accent_token), a: 0.45, }),
  )
  assert_eq(
    other.tree.nodes[6].computed_style.unwrap().background,
    Some({ ..dark.resolve(@style.accent_token), a: 0.45, }),
  )
  assert_eq(
    other.tree.nodes[6].computed_style.unwrap().color,
    Some({ ..dark.resolve(@style.on_accent_token), a: 0.45, }),
  )
  let wakeups = Ref(0)
  a.set_wakeup(fn() { wakeups.val += 1 })
  a.set_theme(dark)
  a.set_theme(dark)
  assert_eq(a.dirty(), NeedsPaint)
  assert_eq(a.snapshot(), None)
  assert_eq(wakeups.val, 1)
  assert_eq(b.snapshot(), Some(other))
  a.paint(renderer, size~)
  let after = a.snapshot().unwrap()
  assert_eq(after.theme, dark)
  assert_eq(builds.val, 1)
  for i in 0..<before.tree.nodes.length() {
    assert_eq(after.tree.nodes[i].id, before.tree.nodes[i].id)
    assert_eq(after.tree.nodes[i].frame, before.tree.nodes[i].frame)
    assert_eq(
      after.tree.nodes[i].specified_style,
      before.tree.nodes[i].specified_style,
    )
    assert_eq(
      after.tree.nodes[i].computed_style,
      other.tree.nodes[i].computed_style,
    )
  }
  assert_eq(after.frame.layout_count, before.frame.layout_count)
  assert_eq(after.frame.text_measure_count, before.frame.text_measure_count)
  assert_eq(after.frame.last_paint.unwrap().layout_count, 0)
  a.set_theme(dark)
  assert_false(a.needs_frame())
  assert_eq(a.next_action_delay(), None)
  assert_eq(wakeups.val, 1)
  assert_eq(before.theme, light)
  a.dispose()
  let disposed_wakeups = wakeups.val
  a.set_theme(light)
  assert_eq(a.theme(), dark)
  assert_eq(wakeups.val, disposed_wakeups)
}

///|
test "text input keeps theme surface and text colors across pointer transitions" {
  let root = @runtime.mount(
    fn() { @controls.text_input(value=@reactive.signal("input")) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=50.0)
  let point = @foundation.Point(x=12.0, y=12.0)
  for theme in [@style.Theme(), Theme(palette=@style.Palette::dark()), Theme()] {
    root.set_theme(theme)
    let check_surface = fn() raise {
      root.paint(renderer, size~)
      let computed = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
      assert_eq(
        computed.background,
        Some(theme.resolve(@style.control_surface_token)),
      )
      assert_eq(computed.color, Some(theme.resolve(@style.text_token)))
      assert_eq(
        renderer.fills[0].0,
        theme.resolve(@style.control_surface_token),
      )
      assert_eq(renderer.text[0].color, theme.resolve(@style.text_token))
    }
    check_surface()
    ignore(root.pointer_move(size~, point~))
    check_surface()
    assert_true(root.pointer_down(size~, point~))
    check_surface()
    let pressed = root.snapshot().unwrap().tree.nodes[0]
    assert_true(
      pressed.state.hovered && pressed.state.pressed && pressed.state.focused,
    )
    assert_eq(renderer.strokes[0].0, theme.resolve(@style.accent_token))
    assert_eq(renderer.strokes[0].1, 2.0)
    assert_true(root.pointer_up(size~, point~))
    check_surface()
    root.pointer_leave()
    check_surface()
  }
}

///|
test "component theme states resolve before local base and state overrides" {
  let normal = @foundation.Color::rgb(r=110, g=140, b=170)
  let hovered = @foundation.Color::rgb(r=30, g=70, b=120)
  let border = @foundation.Color::rgb(r=200, g=40, b=50)
  let custom_color = @foundation.Color::rgb(r=80, g=50, b=100)
  let component = @style.BoxStyle()
    .background(normal)
    .radius(8.0)
    .hovered(@style.Appearance().background(hovered).stroke(border, width=3.0))
    .focused(@style.Appearance().color(@foundation.Color::black()))
    .pressed(@style.Appearance().color(@foundation.Color::white()).radius(2.0))
  let theme = @style.Theme(
    styles=@style.Styles()
      .add(@controls.ButtonStyle().surface(component))
      .add(@controls.CheckboxStyle().frame(component))
      .add(@controls.RadioStyle().frame(component))
      .add(@controls.TextInputStyle().surface(component)),
  )
  let size = @foundation.Size(width=150.0, height=50.0)
  for kind in 0..<4 {
    for custom in [false, true] {
      let style = if custom {
        @style.BoxStyle()
        .background(custom_color)
        .radius(7.0)
        .hovered(@style.Appearance().stroke(custom_color, width=4.0))
        .pressed(@style.Appearance().color(custom_color))
      } else {
        BoxStyle()
      }
      let root = @runtime.mount(
        fn() { state_test_control(kind, style, false) },
        theme~,
        text_layout_system=test_text_layout_system(),
      )
      defer root.dispose()
      let renderer = StyleRecorder()
      assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
      root.paint(renderer, size~)
      let pressed = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
      assert_eq(
        pressed.background,
        Some(if custom { custom_color } else { hovered }),
      )
      assert_eq(
        pressed.color,
        Some(if custom { custom_color } else { @foundation.Color::white() }),
      )
      assert_eq(
        pressed.stroke_color,
        Some(if custom { custom_color } else { border }),
      )
      assert_eq(pressed.stroke_width, Some(if custom { 4.0 } else { 3.0 }))
      assert_eq(
        pressed.radius,
        Some(if kind == 2 { 9.0 } else if custom { 7.0 } else { 2.0 }),
      )
      assert_eq(pressed.background, Some(renderer.fills[0].0))
      assert_eq(pressed.color, Some(renderer.text[0].color))
      assert_eq(pressed.stroke_color, Some(renderer.strokes[0].0))
      assert_true(root.pointer_cancel())
      root.paint(renderer, size~)
      let focused = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
      assert_eq(focused.color, Some(@foundation.Color::black()))
      assert_eq(focused.background, pressed.background)
      assert_eq(focused.stroke_color, pressed.stroke_color)
    }
  }
}

///|
test "disabled theme colors remain literal while local normal colors still fade" {
  let themed = @foundation.Color::rgb(r=210, g=220, b=230)
  let custom_color = @foundation.Color::accent()
  let component = @style.BoxStyle()
    .disabled(@style.Appearance().background(themed).color(themed))
    .hovered(@style.Appearance().background(@foundation.Color::black()))
  let theme = @style.Theme(
    styles=@style.Styles()
      .add(@controls.ButtonStyle().surface(component))
      .add(@controls.CheckboxStyle().frame(component))
      .add(@controls.RadioStyle().frame(component))
      .add(@controls.TextInputStyle().surface(component)),
  )
  for kind in 0..<4 {
    for mode in 0..<3 {
      let style = match mode {
        1 => @style.BoxStyle().background(custom_color)
        2 =>
          @style.BoxStyle()
          .background(custom_color)
          .disabled(@style.Appearance().background(custom_color))
        _ => BoxStyle()
      }
      let root = @runtime.mount(
        fn() { state_test_control(kind, style, true) },
        theme~,
        text_layout_system=test_text_layout_system(),
      )
      defer root.dispose()
      let renderer = StyleRecorder()
      root.paint(renderer, size=Size(width=150.0, height=50.0))
      let palette = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
      assert_eq(
        palette.background,
        Some(
          match mode {
            1 => { ..custom_color, a: 0.45, }
            2 => custom_color
            _ => themed
          },
        ),
      )
      assert_eq(palette.color, Some(themed))
      assert_eq(palette.background, Some(renderer.fills[0].0))
      assert_eq(palette.color, Some(renderer.text[0].color))
    }
  }
}

///|
test "theme changes preserve text input focus capture selection and decoration geometry" {
  let value = @reactive.signal("abcdefghij")
  let root = @runtime.mount(
    fn() { @controls.text_input(value~) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=90.0, height=45.0)
  let renderer = StyleRecorder()
  assert_true(root.pointer_down(size~, point=Point(x=11.0, y=10.0)))
  assert_true(root.pointer_move(size~, point=Point(x=42.0, y=10.0)))
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap()
  let selected = root.copy_text().unwrap()
  assert_true(!selected.is_empty())
  let text_frame = renderer.text[0].frame
  let dark = @style.Theme(palette=@style.Palette::dark())
  root.set_theme(dark)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap()
  let palette = after.tree.nodes[0].computed_style.unwrap()
  assert_eq(after.focused_node_id, before.focused_node_id)
  assert_eq(after.captured_node_id, before.captured_node_id)
  assert_true(after.captured_node_id is Some(_))
  assert_eq(after.tree.nodes[0].id, before.tree.nodes[0].id)
  assert_eq(after.tree.nodes[0].frame, before.tree.nodes[0].frame)
  assert_eq(root.copy_text(), Some(selected))
  assert_eq(value.get(), "abcdefghij")
  assert_eq(renderer.text[0].frame, text_frame)
  assert_eq(palette.background, Some(renderer.fills[0].0))
  assert_eq(palette.selection_color, Some(renderer.fills[1].0))
  assert_eq(palette.caret_color, Some(renderer.fills[2].0))
  assert_eq(palette.selection_color, Some(dark.resolve(@style.selection_token)))
  assert_eq(palette.caret_color, Some(dark.resolve(@style.accent_token)))
  assert_eq(after.frame.layout_count, before.frame.layout_count)
  assert_eq(after.frame.text_measure_count, before.frame.text_measure_count)
  let parts = @controls.TextInputStyle()
    .caret_color(@foundation.Color::black())
    .selection_color(@foundation.Color::white())
  root.set_theme({ ..dark, styles: dark.styles.add(parts), })
  root.paint(renderer, size~)
  assert_eq(renderer.fills[1].0, @foundation.Color::white())
  assert_eq(renderer.fills[2].0, @foundation.Color::black())
  assert_eq(root.copy_text(), Some(selected))
}

///|
test "theme changes during paint keep one theme per frame and reject stale snapshots" {
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  defer (fn() { root_ref.val = None })()
  let dark = @style.Theme(palette=@style.Palette::dark())
  let seen : Array[@style.Theme] = []
  let first = Ref(true)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.element(
          style=@style.BoxStyle(),
          painter=@view.Painter(fn(context, _) {
            seen.push(context.theme)
            if first.val {
              first.val = false
              root_ref.val.unwrap().set_theme(dark)
            }
          }),
        ),
        @controls.button("button"),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root_ref.val = Some(root)
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=160.0, height=80.0)
  root.paint(renderer, size~)
  assert_eq(renderer.fills[0].0, @foundation.Color::accent())
  assert_eq(root.dirty(), NeedsPaint)
  assert_eq(root.snapshot(), None)
  root.paint(renderer, size~)
  assert_eq(seen, [Theme(), dark])
  assert_eq(renderer.fills[0].0, dark.resolve(@style.accent_token))
  assert_eq(root.snapshot().unwrap().theme, dark)
  assert_eq(root.frame_stats().layout_count, 1)
}

///|
test "custom layout hosts change themes without losing layout or input caches" {
  let dark = @style.Theme(palette=@style.Palette::dark())
  let state = @view.LayoutState(
    text_layout_system=test_text_layout_system(),
    theme=dark,
  )
  defer state.dispose()
  let view = @view.box()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=50.0)
  state.paint(view, renderer, size~, focused_path=None)
  assert_eq(renderer.fills[0].0, dark.resolve(@style.surface_token))
  assert_true(state.snapshot(view) is Some(_))
  assert_true(state.set_theme(Theme()))
  assert_eq(state.snapshot(view), None)
  assert_false(state.set_theme(Theme()))
  state.paint(view, renderer, size~, focused_path=None)
  assert_eq(renderer.fills[0].0, @foundation.Color::surface())
  assert_eq(state.layout_count(), 1)
  state.dispose()
  assert_false(state.set_theme(dark))
}

///|
test "theme scrollbar colors share input geometry and preserve an active thumb drag" {
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column(Array::makei(5, _ => @view.fill_box(50.0))),
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=100.0)
  root.paint(renderer, size~)
  let before = root.snapshot().unwrap().tree.nodes[0].scroll.unwrap().scrollbar.unwrap()
  let point = @foundation.Point(
    x=before.thumb.origin.x + 2.0,
    y=before.thumb.origin.y + 2.0,
  )
  assert_true(root.pointer_down(size~, point~))
  root.paint(renderer, size~)
  let capture = root.snapshot().unwrap().captured_node_id
  let layouts = root.frame_stats().layout_count
  let dark = @style.Theme(palette=@style.Palette::dark())
  root.set_theme(dark)
  root.paint(renderer, size~)
  let after = root.snapshot().unwrap()
  let bar = after.tree.nodes[0].scroll.unwrap().scrollbar.unwrap()
  assert_eq(after.captured_node_id, capture)
  assert_eq(bar.track, before.track)
  assert_eq(bar.thumb, before.thumb)
  assert_eq(bar.track_color, dark.resolve(@style.scrollbar_track_token))
  assert_eq(bar.thumb_color, dark.resolve(@style.scrollbar_thumb_token))
  assert_eq(renderer.fills[renderer.fills.length() - 2].0, bar.track_color)
  assert_eq(renderer.fills[renderer.fills.length() - 1].0, bar.thumb_color)
  assert_true(root.pointer_move(size~, point={ ..point, y: point.y + 30.0, }))
  assert_true(offset.get() > 0.0)
  assert_eq(root.frame_stats().layout_count, layouts)
}

///|
test "explicit scrollbar colors stay fixed while omitted roles follow the theme" {
  let custom_scrollbar = @style.ScrollbarStyle()
    .thickness(24.0)
    .thumb_color(@foundation.Color::accent())
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(@view.fill_box(300.0), scrollbar_style=custom_scrollbar)
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=100.0, height=100.0)
  for theme in [@style.Theme(), Theme(palette=@style.Palette::dark())] {
    root.set_theme(theme)
    root.paint(renderer, size~)
    let bar = root.snapshot().unwrap().tree.nodes[0].scroll.unwrap().scrollbar.unwrap()
    assert_eq(bar.style, custom_scrollbar)
    assert_eq(
      renderer.fills[renderer.fills.length() - 2].0,
      custom_scrollbar.track_color.resolve(theme),
    )
    assert_eq(
      renderer.fills[renderer.fills.length() - 1].0,
      custom_scrollbar.thumb_color.resolve(theme),
    )
  }
}

///|
test "component part colors override palette roles independently of local text style" {
  let marker = @foundation.Color::rgb(r=200, g=50, b=70)
  let placeholder = @foundation.Color::rgb(r=40, g=130, b=80)
  let theme = @style.Theme(
    palette=@style.Palette::dark(),
    styles=@style.Styles()
      .add(@controls.CheckboxStyle().marker_color(marker))
      .add(@controls.RadioStyle().marker_color(marker))
      .add(
        @controls.TextInputStyle().placeholder(
          @view.TextStyle().color(placeholder),
        ),
      ),
  )
  let root = @runtime.mount(
    fn() {
      @view.column([
        @controls.checkbox(label="check", checked=@reactive.signal(true)),
        @controls.radio(label="radio", selected=@reactive.signal(true)),
        @controls.text_input(
          placeholder="hint",
          style=@controls.TextInputStyle().surface(
            @style.BoxStyle().color(marker),
          ),
        ),
      ])
    },
    theme~,
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=240.0, height=150.0))
  let nodes = root.snapshot().unwrap().tree.nodes
  assert_eq(nodes[1].computed_style.unwrap().marker_color, Some(marker))
  assert_eq(nodes[2].computed_style.unwrap().marker_color, Some(marker))
  assert_eq(
    nodes[3].computed_style.unwrap().placeholder_color,
    Some(placeholder),
  )
  assert_eq(nodes[3].computed_style.unwrap().color, Some(marker))
  assert_eq(renderer.fills[1].0, marker)
  assert_eq(renderer.fills[3].0, marker)
  assert_eq(renderer.text[2].color, placeholder)
}

///|
test "snapshot delivery keeps the painted theme when a frame observer changes defaults" {
  let root = @runtime.mount(
    fn() { @controls.button("button") },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let dark = @style.Theme(palette=@style.Palette::dark())
  let themes : Array[@style.Theme] = []
  let backgrounds : Array[@foundation.Color?] = []
  let stop_snapshots = root.observe_snapshots(fn(snapshot) {
    themes.push(snapshot.theme)
    backgrounds.push(snapshot.tree.nodes[0].computed_style.unwrap().background)
  })
  defer stop_snapshots()
  let stop_frames = root.observe_frames(fn(event) {
    if event is Painted(_) {
      root.set_theme(dark)
    }
  })
  defer stop_frames()
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=50.0)
  root.paint(renderer, size~)
  assert_eq(themes, [Theme()])
  assert_eq(root.snapshot(), None)
  root.paint(renderer, size~)
  assert_eq(themes, [Theme(), dark])
  assert_eq(backgrounds, [
    Some(@foundation.Color::accent()),
    Some(dark.resolve(@style.accent_token)),
  ])
  assert_false(root.needs_frame())
}

///|
test "App initializes root defaults before content and retains explicit window clear" {
  let dark = @style.Theme(palette=@style.Palette::dark())
  let observed : Array[@style.Theme] = []
  let app = @runtime.App(
    theme_mode=Dark,
    content=fn() {
      observed.push(@environment.current_theme())
      @view.text("text")
    },
    on_mount=fn(root) { observed.push(root.theme()) },
  )
  let root = app.mount(text_layout_system=test_text_layout_system())
  defer root.dispose()
  assert_eq(observed, [dark, dark])
  assert_eq(root.theme(), dark)
  assert_eq(app.options().clear, None)
  let renderer = StyleRecorder()
  root.paint(renderer, size=Size(width=150.0, height=50.0))
  assert_eq(renderer.text[0].color, dark.resolve(@style.text_token))
  let fixed = @runtime.App(
    theme_mode=Dark,
    clear=@foundation.Color::white(),
    content=@view.empty,
  )
  assert_eq(fixed.options().clear, Some(@foundation.Color::white()))
}

///|
test "App theme mode subscriptions belong to each root and only changed themes request paint" {
  let unrelated = @reactive.signal(0)
  let reads = Ref(0)
  let builds = Ref(0)
  let light = @style.Theme()
  let dark = @style.Theme(palette=@style.Palette::dark())
  let app = @runtime.App(theme_mode=Light, content=fn() {
    builds.val += 1
    ignore(
      @reactive.effect(fn() {
        ignore(@runtime.current_app().theme_mode())
        reads.val += 1
      }),
    )
    @controls.text_input(value=@reactive.signal("input"))
  })
  let first = app.mount(text_layout_system=test_text_layout_system())
  defer first.dispose()
  let second = app.mount(text_layout_system=test_text_layout_system())
  defer second.dispose()
  assert_eq(reads.val, 2)
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=50.0)
  assert_true(first.pointer_down(size~, point=Point(x=12.0, y=12.0)))
  first.paint(renderer, size~)
  let before = first.snapshot().unwrap()
  second.paint(renderer, size~)
  let wakeups = Ref(0)
  first.set_wakeup(fn() {
    ignore(unrelated.get())
    wakeups.val += 1
  })
  app.set_theme_mode(Dark)
  assert_eq(reads.val, 4)
  assert_eq(first.theme(), dark)
  assert_eq(second.theme(), dark)
  assert_eq(first.dirty(), NeedsPaint)
  assert_eq(second.dirty(), NeedsPaint)
  assert_eq(wakeups.val, 1)
  first.paint(renderer, size~)
  let after = first.snapshot().unwrap()
  assert_eq(after.tree.nodes[0].id, before.tree.nodes[0].id)
  assert_eq(after.tree.nodes[0].frame, before.tree.nodes[0].frame)
  assert_eq(after.focused_node_id, before.focused_node_id)
  assert_eq(after.captured_node_id, before.captured_node_id)
  assert_eq(after.frame.layout_count, before.frame.layout_count)
  assert_eq(after.frame.text_measure_count, before.frame.text_measure_count)
  assert_eq(renderer.fills[0].0, dark.resolve(@style.control_surface_token))
  assert_eq(renderer.text[0].color, dark.resolve(@style.text_token))
  second.paint(renderer, size~)
  app.set_theme_mode(Dark)
  first.set_system_theme(Some(Dark))
  assert_eq(reads.val, 4)
  assert_eq(builds.val, 2)
  assert_eq(wakeups.val, 1)
  assert_false(first.needs_frame())
  assert_false(second.needs_frame())
  unrelated.set(1)
  assert_eq(reads.val, 4)
  first.dispose()
  app.set_theme_mode(Light)
  assert_eq(reads.val, 5)
  assert_eq(first.theme(), dark)
  assert_eq(second.theme(), light)
  assert_eq(second.dirty(), NeedsPaint)
  second.paint(renderer, size~)
  second.dispose()
  app.set_theme_mode(Dark)
  assert_eq(reads.val, 5)
}

///|
test "System follows each host, preserves the preference, and falls back to Light when unknown" {
  let app = @runtime.App(content=fn() { @controls.button("button") })
  assert_eq(app.theme_mode(), System)
  let first = app.mount(
    text_layout_system=test_text_layout_system(),
    system_theme=Dark,
  )
  defer first.dispose()
  let second = app.mount(text_layout_system=test_text_layout_system())
  defer second.dispose()
  let dark = @style.Theme(palette=@style.Palette::dark())
  assert_eq(first.theme(), dark)
  assert_eq(second.theme(), Theme())
  let renderer = StyleRecorder()
  let size = @foundation.Size(width=150.0, height=50.0)
  first.paint(renderer, size~)
  second.paint(renderer, size~)
  first.set_system_theme(Some(Light))
  assert_eq(first.theme(), Theme())
  assert_eq(first.dirty(), NeedsPaint)
  assert_false(second.needs_frame())
  assert_eq(app.theme_mode(), System)
  first.paint(renderer, size~)
  app.set_theme_mode(Light)
  first.set_system_theme(Some(Dark))
  assert_false(first.needs_frame())
  assert_false(second.needs_frame())
  app.set_theme_mode(System)
  assert_eq(first.theme(), dark)
  assert_eq(second.theme(), Theme())
  first.paint(renderer, size~)
  first.set_system_theme(None)
  assert_eq(first.theme(), Theme())
  assert_eq(app.theme_mode(), System)
  first.paint(renderer, size~)
  first.set_system_theme(None)
  assert_false(first.needs_frame())
}

///|
test "App mode selects complete custom themes and remains independent from another App" {
  let accent = @foundation.Color::rgb(r=200, g=50, b=80)
  let light = @style.Theme(palette={ ..Palette(), accent, })
  let dark = @style.Theme(
    palette={ ..@style.Palette::dark(), accent, },
    styles=@style.Styles().add(
      @controls.ButtonStyle().surface(@style.BoxStyle().radius(8.0)),
    ),
  )
  let seen : Array[@style.Theme] = []
  let app = @runtime.App(light_theme=light, dark_theme=dark, content=fn() {
    seen.push(@environment.current_theme())
    @controls.button("button")
  })
  let root = app.mount(
    text_layout_system=test_text_layout_system(),
    system_theme=Dark,
  )
  defer root.dispose()
  let other = @runtime.App(content=@view.empty).mount(
    text_layout_system=test_text_layout_system(),
  )
  defer other.dispose()
  assert_eq(seen, [dark])
  assert_eq(root.theme(), dark)
  app.set_theme_mode(Light)
  assert_eq(root.theme(), light)
  assert_eq(other.theme(), Theme())
  app.set_theme_mode(Dark)
  assert_eq(root.theme(), dark)
}
