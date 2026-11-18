///|
fn focus_test_control(
  kind : Int32,
  style : @style.BoxStyle,
  disabled : &@value.BoolValue,
) -> @view.View {
  if kind < 4 {
    state_test_control(kind, style, disabled)
  } else {
    @controls.select(
      [@controls.SelectOption(1, label="Select")],
      style=@controls.SelectStyle().surface(style),
      disabled~,
    )
  }
}

///|
test "all built-in controls share a theme focus outline and keep their explicit border" {
  let border = @foundation.Color::rgb(r=180, g=40, b=50)
  for dark in [false, true] {
    let blocked = @reactive.signal(false)
    let root = @runtime.mount(
      fn() {
        @view.column(
          Array::makei(5, kind => {
            focus_test_control(
              kind,
              @style.BoxStyle().stroke(border, width=3.0).height(40.0),
              blocked,
            )
          }),
          style=@view.FlexStyle()
            .padding(@foundation.Insets::all(12.0))
            .spacing(12.0),
        )
      },
      theme=@style.Theme(
        palette=if dark { @style.Palette::dark() } else { @style.Palette() },
      ),
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=300.0, height=360.0)
    let recorder = StyleRecorder()
    root.paint(recorder, size~)
    let initial = root.snapshot().unwrap().tree.nodes
    let layouts = root.frame_stats().layout_count
    for focused in 0..<5 {
      assert_true(root.key_down(test_key_event(KeyTab)))
      root.paint(recorder, size~)
      let nodes = root.snapshot().unwrap().tree.nodes
        .iter()
        .filter(node => node.focusable)
        .to_array()
      assert_eq(nodes.length(), 5)
      for index, node in nodes {
        let computed = node.computed_style.unwrap()
        assert_eq(node.state.focused, index == focused)
        assert_eq(computed.stroke_color, Some(border))
        assert_eq(computed.stroke_width, Some(3.0))
        assert_eq(
          computed.outline_color,
          if index == focused {
            Some(node.theme.resolve(@style.accent_token))
          } else {
            None
          },
        )
        assert_eq(
          computed.outline_width,
          if index == focused {
            Some(2.0)
          } else {
            None
          },
        )
        assert_eq(
          computed.outline_offset,
          if index == focused {
            Some(2.0)
          } else {
            None
          },
        )
      }
    }
    let new_color = @foundation.Color::rgb(r=160, g=50, b=180)
    root.set_theme(root.theme().token(@style.accent_token, new_color))
    root.paint(recorder, size~)
    let tree = root.snapshot().unwrap().tree.nodes
    let focused = tree.iter().filter(node => node.state.focused).to_array()[0]
    assert_eq(focused.computed_style.unwrap().outline_color, Some(new_color))
    assert_eq(focused.computed_style.unwrap().stroke_color, Some(border))
    assert_eq(tree.length(), initial.length())
    for i in 0..<tree.length() {
      assert_eq(tree[i].id, initial[i].id)
      assert_eq(tree[i].frame, initial[i].frame)
    }
    assert_eq(root.frame_stats().layout_count, layouts)
    blocked.set(true)
    root.paint(recorder, size~)
    for node in root.snapshot().unwrap().tree.nodes {
      assert_false(node.state.focused)
      if node.computed_style is Some(style) {
        assert_eq(style.outline_color, None)
      }
    }
  }
}

///|
test "focus outlines compose theme and reactive local overrides without layout or snapshot reads" {
  let color = @reactive.signal(@foundation.Color::black())
  let hidden = @reactive.signal(false)
  let calls = Ref(0)
  let theme_color = @foundation.Color::rgb(r=160, g=20, b=40)
  let root = @runtime.mount(
    fn() {
      @controls.button(
        "Focus",
        style=@controls.ButtonStyle::computed(fn() {
          calls.val += 1
          @controls.ButtonStyle().focused(
            @style.Appearance().outline(
              color.get(),
              width=if hidden.get() { 0.0 } else { 3.0 },
              offset=-3.0,
            ),
          )
        }),
      )
    },
    theme=@style.Theme(
      styles=@style.Styles().add(
        @controls.ButtonStyle().focused(
          @style.Appearance().outline(theme_color, width=4.0),
        ),
      ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=200.0, height=60.0)
  assert_true(root.key_down(test_key_event(KeyTab)))
  let recorder = StyleRecorder()
  root.paint(recorder, size~)
  let layouts = root.frame_stats().layout_count
  for change in [false, true] {
    let next = if change {
      @foundation.Color::white()
    } else {
      @foundation.Color::black()
    }
    color.set(next)
    hidden.set(change)
    let reads = calls.val
    root.paint(recorder, size~)
    let node = root.snapshot().unwrap().tree.nodes[0]
    assert_eq(node.computed_style.unwrap().outline_color, Some(next))
    assert_eq(
      node.computed_style.unwrap().outline_width,
      Some(if change { 0.0 } else { 3.0 }),
    )
    assert_eq(node.computed_style.unwrap().outline_offset, Some(-3.0))
    assert_eq(recorder.strokes.length(), if change { 0 } else { 1 })
    assert_eq(calls.val, reads)
    assert_eq(root.frame_stats().layout_count, layouts)
  }
}

///|
test "zero surface stroke retains default focus while zero outline hides it on every control" {
  for kind in 0..<5 {
    for hide in [false, true] {
      let style = @style.BoxStyle().stroke(
        @foundation.Color::black(),
        width=0.0,
      )
      let style = if hide {
        style.focused(
          @style.Appearance().outline(@style.accent_token, width=0.0),
        )
      } else {
        style
      }
      let root = @runtime.mount(
        fn() { focus_test_control(kind, style, false) },
        text_layout_system=test_text_layout_system(),
      )
      defer root.dispose()
      assert_true(root.key_down(test_key_event(KeyTab)))
      let recorder = StyleRecorder()
      root.paint(recorder, size=Size(width=220.0, height=100.0))
      let node = root.snapshot().unwrap().tree.nodes
        .iter()
        .filter(node => node.state.focused)
        .to_array()[0]
      assert_eq(node.computed_style.unwrap().stroke_width, Some(0.0))
      assert_eq(
        node.computed_style.unwrap().outline_width,
        Some(if hide { 0.0 } else { 2.0 }),
      )
      assert_eq(recorder.strokes.length(), if hide { 0 } else { 1 })
    }
  }
}

///|
test "interactive text can opt into the same focus outline through its frame style" {
  let root = @runtime.mount(
    fn() {
      @view.interactive(
        @view.text(
          "Link",
          style=@view.TextStyle().frame(
            @style.BoxStyle().focused(
              @style.Appearance().outline(@style.accent_token),
            ),
          ),
        ),
        on_click=fn() { () },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let recorder = StyleRecorder()
  let size = @foundation.Size(width=200.0, height=80.0)
  root.paint(recorder, size~)
  assert_true(recorder.strokes.is_empty())
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(recorder, size~)
  let node = root.snapshot().unwrap().tree.nodes[0]
  assert_eq(
    node.computed_style.unwrap().outline_color,
    Some(node.theme.resolve(@style.accent_token)),
  )
  assert_eq(recorder.strokes.length(), 1)
  assert_eq(root.frame_stats().layout_count, 1)
}
