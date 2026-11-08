///|
test "custom scrollbar style shares inset geometry with paint and dragging" {
  for axis in [@foundation.Axis::Vertical, Horizontal] {
    let offset = @reactive.signal(0.0)
    let track_color = @foundation.Color::rgb(r=20, g=30, b=40)
    let thumb_color = @foundation.Color::rgb(r=80, g=140, b=220)
    let scrollbar_style = @style.ScrollbarStyle()
      .thickness(24.0)
      .track_color(track_color)
      .thumb_color(thumb_color)
      .thumb_radius(5.0)
      .thumb_inset(3.0)
    let root = @runtime.mount(
      fn() {
        let content = match axis {
          Vertical => @view.fill_box(200.0)
          Horizontal =>
            @view.box(style=@style.BoxStyle().width(200.0).height(100.0))
        }
        @view.scroll_view(content, axis~, offset~, scrollbar_style~)
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let renderer = ScrollRecorder()
    let size = @foundation.Size(width=100.0, height=100.0)
    root.paint(renderer, size~)
    let snapshot = root.snapshot().unwrap()
    let bar = snapshot.tree.nodes[0].scroll.unwrap().scrollbar.unwrap()
    assert_eq(bar.style, scrollbar_style)
    let (track, thumb, start, finish) = match axis {
      Vertical =>
        (
          @foundation.Rect(x=76.0, y=0.0, width=24.0, height=100.0),
          @foundation.Rect(x=79.0, y=3.0, width=18.0, height=47.0),
          @foundation.Point(x=77.0, y=10.0), // Margin alongside thumb also grabs.
          @foundation.Point(x=77.0, y=33.5),
        )
      Horizontal =>
        (
          Rect(x=0.0, y=76.0, width=100.0, height=24.0),
          Rect(x=3.0, y=79.0, width=47.0, height=18.0),
          Point(x=10.0, y=77.0),
          Point(x=33.5, y=77.0),
        )
    }
    assert_eq(bar.track, track)
    assert_eq(bar.thumb, thumb)
    assert_eq(renderer.fills[renderer.fills.length() - 2].2, track_color)
    assert_eq(renderer.fills.last().unwrap().2, thumb_color)
    assert_true(root.pointer_down(size~, point=start))
    assert_eq(offset.get(), 0.0)
    assert_true(root.pointer_up(size~, point=finish))
    assert_eq(offset.get(), 50.0)
    root.paint(renderer, size~)
    assert_eq(root.frame_stats().layout_count, snapshot.frame.layout_count)
  }
}

///|
test "overlay scrollbar paint and snapshots share proportional translated geometry" {
  for axis in [@foundation.Axis::Vertical, Horizontal] {
    let offset = @reactive.signal(50.0)
    let root = @runtime.mount(
      fn() {
        let content = match axis {
          Vertical => @view.fill_box(200.0)
          Horizontal =>
            @view.box(style=@style.BoxStyle().width(200.0).height(100.0))
        }
        @view.scroll_view(content, axis~, offset~).translated(
          Point(x=5.0, y=7.0),
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let renderer = ScrollRecorder()
    let size = @foundation.Size(width=100.0, height=100.0)
    root.paint(renderer, size~)
    let snapshot = root.snapshot().unwrap()
    let scroll = snapshot.tree.nodes[0].scroll.unwrap()
    let bar = scroll.scrollbar.unwrap()
    let (track, thumb) = match axis {
      Vertical =>
        (
          @foundation.Rect(x=93.0, y=7.0, width=12.0, height=100.0),
          @foundation.Rect(x=95.0, y=33.0, width=8.0, height=48.0),
        )
      Horizontal =>
        (
          Rect(x=5.0, y=95.0, width=100.0, height=12.0),
          Rect(x=31.0, y=97.0, width=48.0, height=8.0),
        )
    }
    assert_eq(bar.track, track)
    assert_eq(bar.thumb, thumb)
    assert_eq(renderer.fills[renderer.fills.length() - 2].0, track)
    assert_eq(renderer.fills.last().unwrap().0, thumb)
    assert_eq(
      renderer.fills.last().unwrap().1,
      scroll.viewport.intersect(@foundation.Rect::from_size(size)),
    )
    assert_eq(renderer.clips.length(), 0)
    offset.set(100.0)
    root.paint(renderer, size~)
    assert_eq(root.frame_stats().layout_count, snapshot.frame.layout_count)
    assert_eq(snapshot.tree.nodes[0].scroll.unwrap().scrollbar.unwrap(), bar)
  }
}

///|
test "thumb dragging keeps the grab point and captures outside the viewport on both axes" {
  for axis in [@foundation.Axis::Vertical, Horizontal] {
    let offset = @reactive.signal(0.0)
    let clicks = Ref(0)
    let root = @runtime.mount(
      fn() {
        let content = match axis {
          Vertical => @view.fill_box(200.0)
          Horizontal =>
            @view.box(style=@style.BoxStyle().width(200.0).height(100.0))
        }
        @view.scroll_view(
          @view.interactive(content, on_click=fn() { clicks.val += 1 }),
          axis~,
          offset~,
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=100.0, height=100.0)
    let point = fn(position : Double, cross : Double) {
      match axis {
        Vertical => @foundation.Point(x=cross, y=position)
        Horizontal => Point(x=position, y=cross)
      }
    }
    root.paint(ScrollRecorder(), size~)
    let node_id = root.snapshot().unwrap().tree.nodes[0].id
    assert_true(root.pointer_down(size~, point=point(10.0, 95.0)))
    assert_eq(offset.get(), 0.0)
    assert_true(root.pointer_move(size~, point=point(34.0, 95.0)))
    assert_eq(offset.get(), 50.0)
    root.paint(ScrollRecorder(), size~)
    assert_eq(root.snapshot().unwrap().captured_node_id, Some(node_id))
    assert_true(root.pointer_move(size~, point=point(1000.0, -50.0)))
    assert_eq(offset.get(), 100.0)
    assert_true(root.pointer_move(size~, point=point(-100.0, -50.0)))
    assert_eq(offset.get(), 0.0)
    assert_true(root.pointer_up(size~, point=point(34.0, -50.0)))
    assert_eq(offset.get(), 50.0)
    assert_false(root.pointer_move(size~, point=point(60.0, 95.0)))
    assert_eq(clicks.val, 0)
    assert_eq(root.frame_stats().layout_count, 1)
  }
}

///|
test "track presses page once without changing focus or calling decorated content handlers" {
  let offset = @reactive.signal(0.0)
  let value = @reactive.signal("")
  let events = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.interactive(
        @view.scroll_view(
          @view.column([
            @controls.text_input(
              value~,
              style=@controls.TextInputStyle().surface(
                @style.BoxStyle().width(100.0).height(40.0),
              ),
            ),
            @view.fill_box(360.0),
          ]),
          offset~,
        ),
        on_click=fn() { events.val += 1 },
        on_pointer_down=fn(_) { events.val += 1 },
        on_pointer_move=fn(_) { events.val += 1 },
        on_pointer_up=fn(_) { events.val += 1 },
        on_pointer_cancel=fn() { events.val += 1 },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=100.0)
  assert_true(root.click_at(size~, point=Point(x=5.0, y=10.0)))
  root.paint(ScrollRecorder(), size~)
  let focus = root.snapshot().unwrap().focused_node_id
  assert_true(focus is Some(_))
  assert_true(root.pointer_down(size~, point=Point(x=95.0, y=80.0)))
  assert_eq(offset.get(), 100.0)
  assert_true(root.pointer_move(size~, point=Point(x=95.0, y=99.0)))
  assert_true(root.pointer_up(size~, point=Point(x=95.0, y=99.0)))
  assert_eq(offset.get(), 100.0)
  root.paint(ScrollRecorder(), size~)
  assert_eq(root.snapshot().unwrap().focused_node_id, focus)
  assert_true(root.click_at(size~, point=Point(x=95.0, y=5.0)))
  assert_eq(offset.get(), 0.0)
  assert_true(root.pointer_down(size~, point=Point(x=95.0, y=5.0)))
  assert_true(root.pointer_cancel())
  assert_false(root.pointer_move(size~, point=Point(x=95.0, y=50.0)))
  assert_eq(events.val, 0)
  assert_true(root.text_input("still focused"))
  assert_eq(value.get(), "still focused")
}

///|
test "scrollbar hides when content fits or explicitly disabled and keeps travel in tiny viewports" {
  for scrollbar in [true, false] {
    let clicks = Ref(0)
    let root = @runtime.mount(
      fn() {
        @view.scroll_view(
          @view.interactive(@view.fill_box(200.0), on_click=fn() {
            clicks.val += 1
          }),
          scrollbar~,
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    root.paint(ScrollRecorder(), size=Size(width=100.0, height=300.0))
    assert_true(
      root.snapshot().unwrap().tree.nodes[0].scroll.unwrap().scrollbar is None,
    )
    assert_true(
      root.click_at(
        size=Size(width=100.0, height=300.0),
        point=Point(x=95.0, y=100.0),
      ),
    )
    assert_eq(clicks.val, 1)
    root.paint(ScrollRecorder(), size=Size(width=5.0, height=5.0))
    let bar = root.snapshot().unwrap().tree.nodes[0].scroll.unwrap().scrollbar
    if scrollbar {
      let bar = bar.unwrap()
      assert_true(
        bar.thumb.size.height > 0.0 &&
        bar.thumb.size.height < bar.track.size.height,
      )
      assert_eq(bar.track.size.width, 5.0)
    } else {
      assert_true(bar is None)
    }
  }
}

///|
test "captured thumb adapts to resize and never becomes content input when the scrollbar disappears" {
  let offset = @reactive.signal(0.0)
  let callbacks = Ref(0)
  let root = @runtime.mount(
    fn() {
      @view.interactive(
        @view.scroll_view(@view.fill_box(200.0), offset~),
        on_pointer_move=fn(_) { callbacks.val += 1 },
        on_pointer_up=fn(_) { callbacks.val += 1 },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(
    root.pointer_down(
      size=Size(width=100.0, height=100.0),
      point=Point(x=95.0, y=10.0),
    ),
  )
  // New inset thumb is 109.5px; the original grab fraction is 1/6.
  assert_true(
    root.pointer_move(
      size=Size(width=100.0, height=150.0),
      point=Point(x=95.0, y=60.0),
    ),
  )
  assert_eq(offset.get(), 50.0)
  assert_true(
    root.pointer_move(
      size=Size(width=100.0, height=300.0),
      point=Point(x=95.0, y=200.0),
    ),
  )
  assert_eq(offset.get(), 50.0)
  assert_true(
    root.pointer_up(
      size=Size(width=100.0, height=300.0),
      point=Point(x=95.0, y=200.0),
    ),
  )
  assert_eq(callbacks.val, 0)
  root.paint(ScrollRecorder(), size=Size(width=100.0, height=300.0))
  assert_true(
    root.snapshot().unwrap().tree.nodes[0].scroll.unwrap().scrollbar is None,
  )
  assert_eq(root.snapshot().unwrap().captured_node_id, None)
}

///|
test "outer scrollbar overlays nested content while inner scrollbar scrolls only its own viewport" {
  let outer = @reactive.signal(0.0)
  let inner = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([
          @view.scroll_view(
            @view.fill_box(180.0),
            offset=inner,
            style=@style.BoxStyle().width(90.0).height(60.0),
          ),
          @view.fill_box(240.0),
        ]),
        offset=outer,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=100.0)
  assert_true(root.pointer_down(size~, point=Point(x=85.0, y=10.0)))
  assert_true(root.pointer_up(size~, point=Point(x=85.0, y=28.0)))
  assert_eq(inner.get(), 60.0)
  assert_eq(outer.get(), 0.0)
  assert_true(root.pointer_down(size~, point=Point(x=95.0, y=10.0)))
  assert_true(root.pointer_up(size~, point=Point(x=95.0, y=35.0)))
  assert_true(outer.get() > 0.0)
  assert_eq(inner.get(), 60.0)
}

///|
test "thumb capture is per root between instances sharing an offset signal" {
  let offset = @reactive.signal(0.0)
  let create = fn() { @view.scroll_view(@view.fill_box(200.0), offset~) }
  let first = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer first.dispose()
  let second = @runtime.mount(
    create,
    text_layout_system=test_text_layout_system(),
  )
  defer second.dispose()
  let size = @foundation.Size(width=100.0, height=100.0)
  assert_true(first.pointer_down(size~, point=Point(x=95.0, y=10.0)))
  assert_true(second.pointer_down(size~, point=Point(x=95.0, y=40.0)))
  assert_true(first.pointer_move(size~, point=Point(x=95.0, y=34.0)))
  assert_eq(offset.get(), 50.0)
  assert_true(second.pointer_cancel())
  assert_true(first.pointer_up(size~, point=Point(x=95.0, y=60.0)))
  assert_eq(offset.get(), 100.0)
}

///|
test "keyed reorder preserves thumb capture and removal or focus loss ends it" {
  let keys = @reactive.signal([1, 2])
  let first = @reactive.signal(0.0)
  let second = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.for_each(fn() { keys.get() }, fn(key) { key }, fn(key) {
          @view.scroll_view(
            @view.fill_box(200.0),
            offset=if key() == 1 { first } else { second },
            style=@style.BoxStyle().height(100.0),
          )
        }),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=220.0)
  assert_true(root.pointer_down(size~, point=Point(x=95.0, y=10.0)))
  keys.set([2, 1])
  assert_true(root.pointer_move(size~, point=Point(x=95.0, y=134.0)))
  assert_eq(first.get(), 50.0)
  assert_eq(second.get(), 0.0)
  keys.set([2])
  assert_false(root.pointer_move(size~, point=Point(x=95.0, y=160.0)))
  assert_false(root.pointer_up(size~, point=Point(x=95.0, y=160.0)))
  assert_eq(first.get(), 50.0)
  assert_true(root.pointer_down(size~, point=Point(x=95.0, y=10.0)))
  root.focus_lost()
  assert_false(root.pointer_move(size~, point=Point(x=95.0, y=50.0)))
  assert_eq(second.get(), 0.0)
}

///|
test "cancellation during a track signal update never delivers scrollbar release to content" {
  let offset = @reactive.signal(0.0)
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let releases = Ref(0)
  let root = @runtime.mount(
    fn() {
      @reactive.effect(fn() {
        if offset.get() > 0.0 && root_ref.val is Some(root) {
          ignore(root.pointer_cancel())
        }
      })
      |> ignore
      @view.interactive(
        @view.scroll_view(@view.fill_box(400.0), offset~),
        on_pointer_up=fn(_) { releases.val += 1 },
        on_pointer_cancel=fn() { releases.val += 1 },
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root_ref.val = Some(root)
  let size = @foundation.Size(width=100.0, height=100.0)
  assert_true(root.click_at(size~, point=Point(x=95.0, y=80.0)))
  assert_eq(offset.get(), 100.0)
  assert_eq(releases.val, 0)
  offset.set(0.0)
  assert_true(root.pointer_down(size~, point=Point(x=95.0, y=80.0)))
  assert_false(root.pointer_up(size~, point=Point(x=95.0, y=80.0)))
  assert_eq(releases.val, 0)
}
