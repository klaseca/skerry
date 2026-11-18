///|
test "explicit normal appearance survives automatic feedback without layout changes" {
  let appearance = @style.Appearance()
    .background(@foundation.Color::rgb(r=120, g=150, b=180))
    .color(@foundation.Color::black())
    .stroke(@foundation.Color::accent(), width=3.0)
    .radius(7.0)
  let size = @foundation.Size(width=150.0, height=50.0)
  for kind in 0..<4 {
    let measures = Ref(0)
    let style = @style.BoxStyle()
      .appearance(appearance)
      .width(100.0)
      .height(40.0)
    let root = @runtime.mount(
      fn() { state_test_control(kind, style, false) },
      text_layout_system=test_text_layout_system(on_measure=fn() {
        measures.val += 1
      }),
    )
    defer root.dispose()
    let renderer = StyleRecorder()
    root.paint(renderer, size~)
    let initial = root.snapshot().unwrap().tree.nodes[0]
    let counts = root.frame_stats()
    let measured = measures.val
    for step in 0..<5 {
      match step {
        0 => ignore(root.pointer_move(size~, point=Point(x=10.0, y=10.0)))
        1 => assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
        2 => assert_true(root.pointer_cancel())
        3 => root.pointer_leave()
        _ => root.focus_lost()
      }
      root.paint(renderer, size~)
      let node = root.snapshot().unwrap().tree.nodes[0]
      let palette = node.computed_style.unwrap()
      assert_eq(palette, {
        ..initial.computed_style.unwrap(),
        outline_color: if node.state.focused {
          Some(node.theme.resolve(@style.accent_token))
        } else {
          None
        },
        outline_width: if node.state.focused {
          Some(2.0)
        } else {
          None
        },
        outline_offset: if node.state.focused {
          Some(2.0)
        } else {
          None
        },
      })
      assert_eq(node.id, initial.id)
      assert_eq(node.frame, initial.frame)
      assert_eq(
        palette.background,
        appearance.background.map(value => value.resolve(node.theme)),
      )
      assert_eq(
        palette.color,
        appearance.color.map(value => value.resolve(node.theme)),
      )
      assert_eq(
        palette.stroke_color,
        appearance.stroke_color.map(value => value.resolve(node.theme)),
      )
      assert_eq(palette.stroke_width, Some(3.0))
      assert_eq(palette.background, Some(renderer.fills[0].0))
      assert_eq(palette.radius, Some(renderer.fills[0].1))
      assert_eq(palette.radius, Some(renderer.strokes[0].2))
      assert_eq(palette.color, Some(renderer.text[0].color))
      assert_eq(root.frame_stats().layout_count, counts.layout_count)
      assert_eq(root.frame_stats().layout_pass_count, counts.layout_pass_count)
      assert_eq(measures.val, measured)
    }
  }
}

///|
test "active state patches compose after defaults and retain explicit hover properties" {
  let background = @foundation.Color::surface()
  let hovered = @foundation.Color::rgb(r=90, g=120, b=180)
  let border = @foundation.Color::rgb(r=220, g=40, b=50)
  let focused = @foundation.Color::rgb(r=20, g=100, b=40)
  let style = @style.BoxStyle()
    .width(100.0)
    .height(40.0)
    .background(background)
    .radius(7.0)
    .hovered(
      @style.Appearance()
      .background(hovered)
      .stroke(border, width=4.0)
      .radius(1.0),
    )
    .focused(@style.Appearance().color(focused))
    .pressed(@style.Appearance().color(@foundation.Color::white()).radius(2.0))
  let size = @foundation.Size(width=150.0, height=50.0)
  for kind in 0..<4 {
    let root = @runtime.mount(
      fn() { state_test_control(kind, style, false) },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let renderer = StyleRecorder()
    root.paint(renderer, size~)
    let initial = root.snapshot().unwrap().tree.nodes[0]
    let layouts = root.frame_stats().layout_count
    ignore(root.pointer_move(size~, point=Point(x=10.0, y=10.0)))
    assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
    root.paint(renderer, size~)
    let node = root.snapshot().unwrap().tree.nodes[0]
    assert_true(node.state.hovered && node.state.focused && node.state.pressed)
    let pressed = node.computed_style.unwrap()
    assert_eq(pressed.background, Some(hovered))
    assert_eq(pressed.stroke_color, Some(border))
    assert_eq(pressed.stroke_width, Some(4.0))
    assert_eq(pressed.color, Some(@foundation.Color::white()))
    assert_eq(pressed.radius, Some(if kind == 2 { 9.0 } else { 2.0 }))
    assert_eq(pressed.background, Some(renderer.fills[0].0))
    assert_eq(pressed.radius, Some(renderer.fills[0].1))
    assert_eq(pressed.stroke_color, Some(renderer.strokes[0].0))
    assert_eq(pressed.stroke_width, Some(renderer.strokes[0].1))
    assert_eq(pressed.radius, Some(renderer.strokes[0].2))
    assert_true(root.pointer_cancel())
    root.paint(renderer, size~)
    let released = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
    assert_eq(released.background, Some(hovered))
    assert_eq(released.stroke_color, Some(border))
    assert_eq(released.stroke_width, Some(4.0))
    assert_eq(released.color, Some(focused))
    assert_eq(released.radius, Some(if kind == 2 { 9.0 } else { 1.0 }))
    root.pointer_leave()
    root.paint(renderer, size~)
    let no_hover = root.snapshot().unwrap().tree.nodes[0].computed_style.unwrap()
    assert_eq(no_hover.background, Some(background))
    assert_eq(no_hover.color, Some(focused))
    assert_eq(
      no_hover.stroke_width,
      initial.computed_style.unwrap().stroke_width,
    )
    assert_eq(no_hover.outline_width, Some(2.0))
    root.focus_lost()
    root.paint(renderer, size~)
    assert_eq(
      root.snapshot().unwrap().tree.nodes[0].computed_style,
      initial.computed_style,
    )
    assert_eq(root.frame_stats().layout_count, layouts)
  }
}

///|
test "disabled feedback fades custom base colors and applies only disabled patches" {
  let background = @foundation.Color::accent()
  let style = @style.BoxStyle()
    .width(100.0)
    .height(40.0)
    .background(background)
    .color(@foundation.Color::black())
    .stroke(@foundation.Color::black(), width=3.0)
    .radius(7.0)
    .hovered(
      @style.Appearance().background(@foundation.Color::white()).radius(1.0),
    )
    .focused(@style.Appearance().background(@foundation.Color::white()))
    .pressed(@style.Appearance().background(@foundation.Color::white()))
  for kind in 0..<4 {
    for patch in [false, true] {
      let style = if patch {
        style.disabled(
          @style.Appearance()
          .color(@foundation.Color::white())
          .stroke(@foundation.Color::black(), width=0.0)
          .radius(0.0),
        )
      } else {
        style
      }
      let root = @runtime.mount(
        fn() { state_test_control(kind, style, true) },
        text_layout_system=test_text_layout_system(),
      )
      defer root.dispose()
      let renderer = StyleRecorder()
      root.paint(renderer, size=Size(width=150.0, height=50.0))
      let node = root.snapshot().unwrap().tree.nodes[0]
      let palette = node.computed_style.unwrap()
      assert_eq(node.state, ControlState(disabled=true))
      assert_eq(palette.background, Some({ ..background, a: 0.45, }))
      assert_eq(palette.background, Some(renderer.fills[0].0))
      assert_eq(palette.color.unwrap().a, if patch { 1.0 } else { 0.45 })
      assert_eq(palette.color, Some(renderer.text[0].color))
      assert_eq(palette.stroke_width, Some(if patch { 0.0 } else { 3.0 }))
      assert_eq(renderer.strokes.length(), if patch { 0 } else { 1 })
      assert_eq(
        palette.radius,
        Some(if kind == 2 { 9.0 } else if patch { 0.0 } else { 7.0 }),
      )
      assert_eq(palette.radius, Some(renderer.fills[0].1))
    }
  }
}

///|
fn appearance_test_surface(kind : Int32, style : @style.BoxStyle) -> @view.View {
  match kind {
    0 => @view.box(style~)
    1 => @view.fill_box(40.0, style~)
    2 => @view.row([], style=@view.FlexStyle().surface(style))
    3 => @view.column([], style=@view.FlexStyle().surface(style))
    _ => @view.scroll_view(@view.empty(), style~)
  }
}

///|
test "explicit zero base or hovered outline suppresses focus without removing the border" {
  for kind in 0..<4 {
    for hovered in [false, true] {
      let appearance = @style.Appearance().outline(
        @foundation.Color::black(),
        width=0.0,
      )
      let base = @style.BoxStyle()
        .width(100.0)
        .height(40.0)
        .stroke(@foundation.Color::black(), width=3.0)
      let style = if hovered {
        base.hovered(appearance)
      } else {
        base.appearance(appearance)
      }
      let root = @runtime.mount(
        fn() { state_test_control(kind, style, false) },
        text_layout_system=test_text_layout_system(),
      )
      defer root.dispose()
      let size = @foundation.Size(width=150.0, height=50.0)
      let renderer = StyleRecorder()
      assert_true(root.pointer_down(size~, point=Point(x=10.0, y=10.0)))
      root.paint(renderer, size~)
      let node = root.snapshot().unwrap().tree.nodes[0]
      assert_true(
        node.state.focused && node.state.hovered && node.state.pressed,
      )
      assert_eq(node.computed_style.unwrap().stroke_width, Some(3.0))
      assert_eq(node.computed_style.unwrap().outline_width, Some(0.0))
      assert_eq(renderer.strokes.length(), 1)
    }
  }
}

///|
test "surface outlines paint without a background and preserve layout geometry" {
  let border = @foundation.Color::accent()
  for kind in 0..<5 {
    for visible in [false, true] {
      let style = @style.BoxStyle()
        .width(100.0)
        .height(40.0)
        .radius(5.0)
        .stroke(border, width=if visible { 3.0 } else { 0.0 })
      let root = @runtime.mount(
        fn() { appearance_test_surface(kind, style) },
        text_layout_system=test_text_layout_system(),
      )
      defer root.dispose()
      let renderer = StyleRecorder()
      root.paint(renderer, size=Size(width=150.0, height=50.0))
      let node = root.snapshot().unwrap().tree.nodes[0]
      let palette = node.computed_style.unwrap()
      assert_eq(palette.stroke_color, Some(border))
      assert_eq(palette.stroke_width, Some(if visible { 3.0 } else { 0.0 }))
      assert_eq(renderer.strokes.length(), if visible { 1 } else { 0 })
      assert_eq(node.border, @foundation.Insets::all(0.0))
      assert_eq(renderer.fills.length(), if kind < 2 { 1 } else { 0 })
      if visible {
        assert_eq(palette.radius, Some(5.0))
        assert_eq(renderer.strokes[0], (border, 3.0, 5.0))
      }
    }
  }
}
