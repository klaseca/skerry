///|
test "select keyboard focus uses background feedback without a default option outline" {
  for dark in [false, true] {
    let selected = @reactive.signal(Some(0))
    let root = @runtime.mount(
      fn() {
        @controls.select(
          [0, 1, 2].map(value => @controls.SelectOption(value, label="")),
          selected~,
          style=@controls.SelectStyle().surface(@style.BoxStyle().width(160.0)),
        )
      },
      theme=Theme(
        palette=if dark { @style.Palette::dark() } else { @style.Palette() },
      ),
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    select_test_open(root)
    let before = select_test_nodes(root)
    assert_true(before[0].state.focused)
    let layouts = root.frame_stats().layout_count
    assert_true(root.key_down(test_key_event(KeyArrowDown)))
    let rows = select_test_nodes(root)
    assert_false(rows[0].state.focused)
    assert_true(rows[1].state.focused)
    assert_eq(selected.peek(), Some(0))
    let active = rows[1].computed_style.unwrap()
    let normal = rows[2].computed_style.unwrap()
    assert_true(active.background != normal.background)
    for row in rows {
      assert_eq(row.computed_style.unwrap().stroke_color, None)
      assert_eq(row.computed_style.unwrap().stroke_width, None)
      assert_eq(row.computed_style.unwrap().outline_color, None)
      assert_eq(row.computed_style.unwrap().outline_width, None)
    }
    assert_eq(root.frame_stats().layout_count, layouts)
    let list = root.snapshot().unwrap().tree.nodes
      .iter()
      .filter(node => node.scroll is Some(_))
      .to_array()[0]
    assert_eq(list.padding.left, 4.0)
    assert_eq(list.padding.top, 4.0)
    assert_eq(list.padding.bottom, 4.0)
    assert_eq(rows[0].frame.origin.x, list.frame.origin.x + 4.0)
    assert_eq(rows[0].frame.origin.y, list.frame.origin.y + 4.0)
    assert_eq(
      rows[2].frame.origin.y + rows[2].frame.size.height,
      list.frame.origin.y + list.frame.size.height - 4.0,
    )
    let point = @foundation.Point(
      x=list.frame.origin.x + 1.0,
      y=list.frame.origin.y + 1.0,
    )
    let size = @foundation.Size(width=320.0, height=400.0)
    // The popup surface consumes presses in its padding without selecting a row.
    ignore(root.pointer_down(size~, point~))
    ignore(root.pointer_up(size~, point~))
    assert_false(root.scroll_at(size~, point~, delta=Point(x=0.0, y=20.0)))
    assert_eq(selected.peek(), Some(0))
    assert_eq(root.view().overlay_targets().length(), 1)
  }
}

///|
test "select list theme padding overrides defaults and remains reactive including zero" {
  let padding = @reactive.signal(6.0)
  let reads = Ref(0)
  let root = @runtime.mount(
    fn() {
      @controls.select(
        [0, 1].map(value => @controls.SelectOption(value, label="")),
      )
    },
    theme=Theme(
      styles=@style.Styles().add(
        @controls.SelectStyle().list(
          @style.BoxStyle::bind(
            @reactive.bind(fn() {
              reads.val += 1
              @style.BoxStyle().padding(@foundation.Insets::all(padding.get()))
            }),
          ),
        ),
      ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  let id = select_test_nodes(root)[0].id
  for value in [6.0, 0.0, 10.0] {
    padding.set(value)
    let rows = select_test_nodes(root)
    let list = root.snapshot().unwrap().tree.nodes
      .iter()
      .filter(node => node.scroll is Some(_))
      .to_array()[0]
    assert_eq(list.padding.top, value)
    assert_eq(list.padding.left, value)
    assert_eq(rows[0].frame.origin.y, list.frame.origin.y + value)
    assert_eq(rows[0].id, id)
    let count = reads.val
    ignore(root.snapshot())
    ignore(select_test_nodes(root))
    assert_eq(reads.val, count)
  }
}

///|
test "select explicit focus appearances still override default background feedback" {
  let color = @foundation.Color::rgb(r=120, g=40, b=180)
  let root = @runtime.mount(
    fn() {
      @controls.select(
        [@controls.SelectOption(1, label="")],
        style=@controls.SelectStyle().option(
          @controls.ButtonStyle().focused(
            @style.Appearance().background(color).stroke(color, width=3.0),
          ),
        ),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  let focused = select_test_nodes(root)[0]
  assert_true(focused.state.focused)
  assert_eq(focused.computed_style.unwrap().background, Some(color))
  assert_eq(focused.computed_style.unwrap().stroke_color, Some(color))
  assert_eq(focused.computed_style.unwrap().stroke_width, Some(3.0))
}
