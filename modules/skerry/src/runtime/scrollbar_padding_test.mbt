///|
test "scrollbar stays at the padded viewport edge for paint wheel and captured dragging" {
  for axis in [@foundation.Vertical, Horizontal] {
    for gutter in [false, true] {
      let offset = @reactive.signal(0.0)
      let clicks = Ref(0)
      let padding : @foundation.Insets = {
        top: 7.0,
        right: 9.0,
        bottom: 11.0,
        left: 5.0,
      }
      let root = @runtime.mount(
        fn() {
          let content = match axis {
            Vertical => @view.fill_box(400.0)
            Horizontal => @view.box(style=@style.BoxStyle().width(400.0))
          }
          @view.column(
            [
              @view.scroll_view(
                @view.interactive(content, on_click=fn() { clicks.val += 1 }),
                axis~,
                offset~,
                scrollbar_gutter=gutter,
                scrollbar_style=@style.ScrollbarStyle().thickness(20.0),
                style=@style.BoxStyle()
                  .width(120.0)
                  .height(100.0)
                  .padding(padding),
              ).translated(Point(x=6.0, y=8.0)),
            ],
            style=@view.FlexStyle().align_items(Start),
          )
        },
        text_layout_system=test_text_layout_system(),
      )
      defer root.dispose()
      let size = @foundation.Size(width=160.0, height=140.0)
      let recorder = ScrollRecorder()
      root.paint(recorder, size~)
      let nodes = root.snapshot().unwrap().tree.nodes
      let viewport = nodes[1]
      let scroll = viewport.scroll.unwrap()
      let bar = scroll.scrollbar.unwrap()
      match axis {
        Vertical => {
          assert_eq(
            bar.track.origin.x + bar.track.size.width,
            viewport.frame.origin.x + viewport.frame.size.width,
          )
          assert_eq(bar.track.origin.y, viewport.frame.origin.y + padding.top)
          assert_eq(
            bar.track.size.height,
            viewport.frame.size.height - padding.top - padding.bottom,
          )
          if gutter {
            assert_eq(
              nodes[2].frame.origin.x +
              nodes[2].frame.size.width +
              padding.right,
              bar.track.origin.x,
            )
          }
        }
        Horizontal => {
          assert_eq(
            bar.track.origin.y + bar.track.size.height,
            viewport.frame.origin.y + viewport.frame.size.height,
          )
          assert_eq(bar.track.origin.x, viewport.frame.origin.x + padding.left)
          assert_eq(
            bar.track.size.width,
            viewport.frame.size.width - padding.left - padding.right,
          )
          if gutter {
            assert_eq(
              nodes[2].frame.origin.y +
              nodes[2].frame.size.height +
              padding.bottom,
              bar.track.origin.y,
            )
          }
        }
      }
      assert_eq(recorder.fills[recorder.fills.length() - 2].0, bar.track)
      assert_eq(recorder.fills.last().unwrap().0, bar.thumb)
      let point = match axis {
        Vertical =>
          @foundation.Point(
            x=bar.track.origin.x + bar.track.size.width - 1.0,
            y=bar.thumb.origin.y + 4.0,
          )
        Horizontal =>
          Point(
            x=bar.thumb.origin.x + 4.0,
            y=bar.track.origin.y + bar.track.size.height - 1.0,
          )
      }
      // This strip is outside the padded content viewport but is painted track.
      assert_false(scroll.viewport.contains(point))
      assert_true(recorder.fills[recorder.fills.length() - 2].1.contains(point))
      let delta = match axis {
        Vertical => @foundation.Point(x=0.0, y=40.0)
        Horizontal => Point(x=40.0, y=0.0)
      }
      assert_true(root.scroll_at(size~, point~, delta~))
      assert_eq(offset.peek(), 40.0)
      root.paint(recorder, size~)
      let bar = root.snapshot().unwrap().tree.nodes[1].scroll.unwrap().scrollbar.unwrap()
      let start = match axis {
        Vertical => @foundation.Point(x=point.x, y=bar.thumb.origin.y + 4.0)
        Horizontal => Point(x=bar.thumb.origin.x + 4.0, y=point.y)
      }
      let finish = match axis {
        Vertical => @foundation.Point(x=start.x, y=1000.0)
        Horizontal => Point(x=1000.0, y=start.y)
      }
      assert_true(root.pointer_down(size~, point=start))
      assert_true(root.pointer_up(size~, point=finish))
      assert_eq(offset.peek(), scroll.max_offset)
      assert_eq(clicks.val, 0)
      root.paint(recorder, size~)
      assert_eq(root.frame_stats().layout_count, 1)
    }
  }
}
