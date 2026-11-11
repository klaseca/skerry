///|
test "select option hover contrasts with light and dark backgrounds including selection" {
  for dark in [false, true] {
    for chosen in [false, true] {
      let palette = if dark { @style.Palette::dark() } else { @style.Palette() }
      let root = @runtime.mount(
        fn() {
          @controls.select(
            [@controls.SelectOption(1, label="Option")],
            selected=@reactive.signal(if chosen { Some(1) } else { None }),
          )
        },
        theme=Theme(palette~),
        text_layout_system=test_text_layout_system(),
      )
      defer root.dispose()
      select_test_open(root)
      let normal = select_test_nodes(root)[0]
      let color = normal.computed_style.unwrap().background.unwrap()
      let layouts = root.frame_stats().layout_count
      ignore(
        root.pointer_move(
          size=Size(width=320.0, height=400.0),
          point=Point(
            x=normal.frame.origin.x + 8.0,
            y=normal.frame.origin.y + 8.0,
          ),
        ),
      )
      let hovered = select_test_nodes(root)[0]
      assert_true(hovered.state.hovered)
      let feedback = hovered.computed_style.unwrap().background.unwrap()
      if dark {
        assert_true(
          feedback.r > color.r && feedback.g > color.g && feedback.b > color.b,
        )
      } else {
        assert_true(
          feedback.r < color.r && feedback.g < color.g && feedback.b < color.b,
        )
      }
      assert_eq(feedback.a, color.a)
      assert_eq(root.frame_stats().layout_count, layouts)
      let next = if dark { @style.Palette() } else { @style.Palette::dark() }
      root.set_theme(Theme(palette=next))
      let swapped = select_test_nodes(root)[0]
      assert_eq(swapped.id, normal.id)
      assert_true(swapped.state.hovered)
      let base = if chosen { next.selection } else { next.control_surface }
      let feedback = swapped.computed_style.unwrap().background.unwrap()
      if dark {
        assert_true(
          feedback.r < base.r && feedback.g < base.g && feedback.b < base.b,
        )
      } else {
        assert_true(
          feedback.r > base.r && feedback.g > base.g && feedback.b > base.b,
        )
      }
      assert_eq(root.frame_stats().layout_count, layouts)
    }
  }
}

///|
test "text input and select field retain their background during hover and press" {
  for dark in [false, true] {
    let root = @runtime.mount(
      fn() {
        @view.column([
          @controls.text_input(placeholder="Input"),
          @controls.select([@controls.SelectOption(1, label="Option")]),
        ])
      },
      theme=Theme(
        palette=if dark { @style.Palette::dark() } else { @style.Palette() },
      ),
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=240.0, height=180.0)
    let recorder = StyleRecorder()
    root.paint(recorder, size~)
    let fields = root.snapshot().unwrap().tree.nodes
      .iter()
      .filter(node => {
        node.component_name == "TextInput" || node.component_name == "Select"
      })
      .to_array()
    assert_eq(fields.length(), 2)
    for field in fields {
      let point = @foundation.Point(
        x=field.frame.origin.x + 4.0,
        y=field.frame.origin.y + 4.0,
      )
      ignore(root.pointer_move(size~, point~))
      assert_true(root.pointer_down(size~, point~))
      root.paint(recorder, size~)
      let pressed = root.snapshot().unwrap().tree.nodes
        .iter()
        .filter(node => node.id == field.id)
        .to_array()[0]
      assert_true(pressed.state.hovered && pressed.state.pressed)
      assert_eq(
        pressed.computed_style.unwrap().background,
        field.computed_style.unwrap().background,
      )
      assert_true(root.pointer_cancel())
    }
  }
}

///|
test "button checkbox and radio feedback stays visible at black and preserves direction on press" {
  let colors = [
    @foundation.Color::white(),
    @foundation.Color::black(),
    @foundation.Color::{ r: 0.49, g: 0.49, b: 0.49, a: 0.5, },
  ]
  for index, color in colors {
    let root = @runtime.mount(
      fn() {
        @view.column([
          @controls.button("Button"),
          @controls.checkbox(label="Checkbox"),
          @controls.radio(label="Radio"),
        ])
      },
      theme=Theme(palette=@style.Palette(control_surface=color, accent=color)),
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=240.0, height=180.0)
    let recorder = StyleRecorder()
    root.paint(recorder, size~)
    let normal = root.snapshot().unwrap().tree.nodes
    let layouts = root.frame_stats().layout_count
    for row in 1..<=3 {
      let point = @foundation.Point(
        x=normal[row].frame.origin.x + 4.0,
        y=normal[row].frame.origin.y + 4.0,
      )
      ignore(root.pointer_move(size~, point~))
      root.paint(recorder, size~)
      let hovered = root.snapshot().unwrap().tree.nodes[row]
      assert_true(hovered.state.hovered)
      let hover = hovered.computed_style.unwrap().background.unwrap()
      assert_true(root.pointer_down(size~, point~))
      root.paint(recorder, size~)
      let pressed = root.snapshot().unwrap().tree.nodes[row]
      assert_true(pressed.state.pressed)
      let press = pressed.computed_style.unwrap().background.unwrap()
      if index == 0 {
        assert_true(hover.r < color.r && hover.g < color.g && hover.b < color.b)
        assert_true(press.r < hover.r && press.g < hover.g && press.b < hover.b)
      } else {
        assert_true(hover.r > color.r && hover.g > color.g && hover.b > color.b)
        assert_true(press.r > hover.r && press.g > hover.g && press.b > hover.b)
      }
      assert_eq(hover.a, color.a)
      assert_eq(press.a, color.a)
      assert_true(root.pointer_cancel())
      root.paint(recorder, size~)
      assert_eq(
        root.snapshot().unwrap().tree.nodes[row].computed_style.unwrap().background,
        Some(hover),
      )
    }
    assert_eq(root.frame_stats().layout_count, layouts)
  }
}

///|
test "explicit hover pressed and disabled styles retain priority in both themes" {
  let hover = @foundation.Color::rgb(r=30, g=160, b=90)
  let press = @foundation.Color::rgb(r=150, g=40, b=180)
  let disabled_color = @foundation.Color::rgb(r=90, g=95, b=100)
  for dark in [false, true] {
    let disabled = @reactive.signal(false)
    let style = @controls.ButtonStyle()
      .hovered(@style.Appearance().background(hover))
      .pressed(@style.Appearance().background(press))
      .disabled(@style.Appearance().background(disabled_color))
    let root = @runtime.mount(
      fn() {
        @view.column([
          @controls.button("Button", style~, disabled~),
          @controls.select(
            [@controls.SelectOption(1, label="Option", disabled~)],
            style=@controls.SelectStyle().option(style),
          ),
        ])
      },
      theme=Theme(
        palette=if dark { @style.Palette::dark() } else { @style.Palette() },
      ),
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=320.0, height=400.0)
    let recorder = StyleRecorder()
    root.paint(recorder, size~)
    let button = root.snapshot().unwrap().tree.nodes[1]
    let point = @foundation.Point(
      x=button.frame.origin.x + 8.0,
      y=button.frame.origin.y + 8.0,
    )
    ignore(root.pointer_move(size~, point~))
    root.paint(recorder, size~)
    assert_eq(
      root.snapshot().unwrap().tree.nodes[1].computed_style.unwrap().background,
      Some(hover),
    )
    assert_true(root.pointer_down(size~, point~))
    root.paint(recorder, size~)
    assert_eq(
      root.snapshot().unwrap().tree.nodes[1].computed_style.unwrap().background,
      Some(press),
    )
    assert_true(root.pointer_cancel())
    assert_true(root.key_down(test_key_event(KeyTab)))
    assert_true(root.key_down(test_key_event(KeyEnter)))
    let option = select_test_nodes(root)[0]
    let point = @foundation.Point(
      x=option.frame.origin.x + 8.0,
      y=option.frame.origin.y + 8.0,
    )
    ignore(root.pointer_move(size~, point~))
    assert_eq(
      select_test_nodes(root)[0].computed_style.unwrap().background,
      Some(hover),
    )
    assert_true(root.pointer_down(size~, point~))
    assert_eq(
      select_test_nodes(root)[0].computed_style.unwrap().background,
      Some(press),
    )
    disabled.set(true)
    assert_eq(
      select_test_nodes(root)[0].computed_style.unwrap().background,
      Some(disabled_color),
    )
  }
}
