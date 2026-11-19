///|
test "select indicators use vector lines and options stop before the scrollbar" {
  let selected = @reactive.signal(Some(0))
  let root = @runtime.mount(
    fn() {
      @controls.select(
        Array::makei(20, i => i).map(fn(value) {
          @controls.SelectOption(value, label=value.to_string())
        }),
        selected~,
        style=@controls.SelectStyle()
          .surface(@style.BoxStyle().width(220.0))
          .list(@style.BoxStyle().max_height(120.0)),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  let size = @foundation.Size(width=320.0, height=400.0)
  let recorder = StyleRecorder()
  root.paint(recorder, size~)
  assert_eq(recorder.lines.length(), 4)
  assert_false(recorder.text.any(run => run.text == "▾" || run.text == "✓"))
  let nodes = root.snapshot().unwrap().tree.nodes
  let list = nodes.iter().filter(node => node.scroll is Some(_)).to_array()[0]
  let bar = list.scroll.unwrap().scrollbar.unwrap()
  assert_eq(
    bar.track.origin.x + bar.track.size.width,
    list.frame.origin.x + list.frame.size.width,
  )
  let rows = nodes
    .iter()
    .filter(node => node.component_name == "SelectOption")
    .to_array()
  for row in rows {
    assert_true(
      (row.frame.origin.x + row.frame.size.width + 4.0 - bar.track.origin.x).abs() <
      0.001,
    )
    assert_true(
      (row.clip.origin.x + row.clip.size.width - bar.track.origin.x).abs() <
      0.001,
    )
  }
  for index in 1..<rows.length() {
    assert_true(
      (rows[index].frame.origin.y -
      rows[index - 1].frame.origin.y -
      rows[index - 1].frame.size.height).abs() <
      0.001,
    )
  }
  let layouts = root.frame_stats().layout_count
  let start = @foundation.Point(
    x=bar.track.origin.x + 2.0,
    y=bar.thumb.origin.y + 4.0,
  )
  let end = @foundation.Point(x=start.x, y=start.y + 20.0)
  assert_true(root.pointer_down(size~, point=start))
  assert_true(root.pointer_up(size~, point=end))
  assert_eq(selected.peek(), Some(0))
  assert_eq(root.view().overlay_targets().length(), 1)
  root.paint(recorder, size~)
  let scroll = root.snapshot().unwrap().tree.nodes
  .iter()
  .filter(node => node.scroll is Some(_))
  .to_array()[0].scroll.unwrap()
  assert_true(scroll.offset > 0.0)
  assert_eq(root.frame_stats().layout_count, layouts)
}

///|
test "select internal list stays contiguous under global flex spacing" {
  let root = @runtime.mount(
    fn() {
      @controls.select(
        ["One", "Two", "Three"].map(fn(value) {
          @controls.SelectOption(value, label=value)
        }),
        style=@controls.SelectStyle().list(@style.BoxStyle().max_height(200.0)),
      )
    },
    theme=Theme(
      styles=@style.Styles().add(
        @view.FlexStyle().spacing(20.0).justify_content(SpaceBetween),
      ),
    ),
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  select_test_open(root)
  let rows = select_test_nodes(root)
  for index in 1..<rows.length() {
    assert_eq(
      rows[index].frame.origin.y,
      rows[index - 1].frame.origin.y + rows[index - 1].frame.size.height,
    )
  }
}
