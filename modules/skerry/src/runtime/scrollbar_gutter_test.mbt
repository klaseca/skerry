///|
test "stable scrollbar gutter reserves its styled thickness and keeps pointer capture on both axes" {
  for axis in [@foundation.Axis::Vertical, Horizontal] {
    let offset = @reactive.signal(0.0)
    let clicks = Ref(0)
    let root = @runtime.mount(
      fn() {
        let content = match axis {
          Vertical => @view.fill_box(400.0)
          Horizontal => @view.box(style=@style.BoxStyle().width(400.0))
        }
        @view.scroll_view(
          @view.interactive(content, on_click=fn() { clicks.val += 1 }),
          axis~,
          offset~,
          scrollbar_gutter=true,
          scrollbar_style=@style.ScrollbarStyle().thickness(20.0),
          style=@style.BoxStyle().padding(@foundation.Insets::all(5.0)),
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=120.0, height=100.0)
    root.paint(ScrollRecorder(), size~)
    let nodes = root.snapshot().unwrap().tree.nodes
    let bar = nodes[0].scroll.unwrap().scrollbar.unwrap()
    let child = nodes[1]
    match axis {
      Vertical => {
        assert_eq(child.frame.size.width, 90.0)
        assert_eq(
          child.frame.origin.x + child.frame.size.width + 5.0,
          bar.track.origin.x,
        )
        assert_eq(
          child.clip.origin.x + child.clip.size.width,
          bar.track.origin.x,
        )
      }
      Horizontal => {
        assert_eq(child.frame.size.height, 70.0)
        assert_eq(
          child.frame.origin.y + child.frame.size.height + 5.0,
          bar.track.origin.y,
        )
        assert_eq(
          child.clip.origin.y + child.clip.size.height,
          bar.track.origin.y,
        )
      }
    }
    let start = @foundation.Point(
      x=bar.thumb.origin.x + 2.0,
      y=bar.thumb.origin.y + 2.0,
    )
    let finish = match axis {
      Vertical => @foundation.Point(x=start.x, y=start.y + 20.0)
      Horizontal => Point(x=start.x + 20.0, y=start.y)
    }
    assert_true(root.pointer_down(size~, point=start))
    assert_true(root.pointer_up(size~, point=finish))
    assert_true(offset.peek() > 0.0)
    assert_eq(clicks.val, 0)
    root.paint(ScrollRecorder(), size~)
    assert_eq(root.frame_stats().layout_count, 1)
  }
}

///|
test "stable gutter persists when content fits and disappears when the scrollbar is disabled" {
  for scrollbar in [true, false] {
    let root = @runtime.mount(
      fn() {
        @view.scroll_view(
          @view.fill_box(200.0),
          scrollbar~,
          scrollbar_gutter=true,
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    for height in [300.0, 100.0] {
      root.paint(ScrollRecorder(), size=Size(width=100.0, height~))
      let nodes = root.snapshot().unwrap().tree.nodes
      assert_eq(nodes[1].frame.size.width, if scrollbar { 88.0 } else { 100.0 })
      assert_eq(
        nodes[0].scroll.unwrap().scrollbar is Some(_),
        scrollbar && height < 200.0,
      )
    }
    root.paint(ScrollRecorder(), size=Size(width=5.0, height=5.0))
    let node = root.snapshot().unwrap().tree.nodes[0]
    assert_true(node.content.size.width >= 0.0)
    if scrollbar {
      assert_eq(
        node.scroll.unwrap().scrollbar.unwrap().track.intersect(node.clip).size.width,
        5.0,
      )
    }
  }
}
