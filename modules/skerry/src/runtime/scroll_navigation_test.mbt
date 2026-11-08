///|
fn navigation_button(
  label : String,
  width~ : Double = 100.0,
  height~ : Double = 30.0,
) -> @view.View {
  @controls.button(
    label,
    style=@controls.ButtonStyle().surface(
      @style.BoxStyle().width(width).height(height),
    ),
  )
}

///|
test "Tab and Shift Tab reveal only the required part of a vertical viewport" {
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([
          navigation_button("one"),
          navigation_button("two"),
          navigation_button("three"),
        ]),
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=50.0)
  let renderer = ScrollRecorder()
  for expected in [0.0, 10.0, 40.0] {
    assert_true(root.key_down(test_key_event(KeyTab), size~))
    assert_eq(offset.get(), expected)
    root.paint(renderer, size~)
    let snapshot = root.snapshot().unwrap()
    let focused = snapshot.tree.nodes
      .iter()
      .find_first(node => Some(node.id) == snapshot.focused_node_id)
      .unwrap()
    assert_true(
      focused.frame.origin.y >= 0.0 &&
      focused.frame.origin.y + focused.frame.size.height <= 50.0,
    )
    assert_false(root.needs_frame())
  }
  for expected in [30.0, 0.0] {
    assert_true(root.key_down(test_shift_key_event(KeyTab)))
    assert_eq(offset.get(), expected)
  }
  assert_eq(root.frame_stats().layout_count, 1)
}

///|
test "Tab before the first host size defers reveal until paint without a feedback frame" {
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([@view.fill_box(100.0), navigation_button("button")]),
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(root.frame_stats().layout_count, 0)
  assert_eq(offset.get(), 0.0)
  root.paint(ScrollRecorder(), size=Size(width=100.0, height=50.0))
  assert_eq(offset.get(), 80.0)
  assert_true(root.snapshot().unwrap().focused_node_id is Some(_))
  assert_false(root.needs_frame())
  root.paint(ScrollRecorder(), size=Size(width=100.0, height=30.0))
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(offset.get(), 100.0)
}

///|
test "nested focus reveal handles inner viewport before its offscreen outer viewport" {
  let inner = @reactive.signal(0.0)
  let outer = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([
          @view.fill_box(50.0),
          @view.scroll_view(
            @view.column([
              navigation_button("one"),
              navigation_button("two"),
              navigation_button("three"),
            ]),
            offset=inner,
            style=@style.BoxStyle().height(40.0),
          ),
          @view.fill_box(40.0),
        ]),
        offset=outer,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=60.0)
  for
    (expected_inner, expected_outer) in [
      (0.0, 20.0),
      (20.0, 30.0),
      (50.0, 30.0),
    ] {
    assert_true(root.key_down(test_key_event(KeyTab), size~))
    assert_eq(inner.get(), expected_inner)
    assert_eq(outer.get(), expected_outer)
    root.paint(ScrollRecorder(), size~)
    let snapshot = root.snapshot().unwrap()
    let node = snapshot.tree.nodes
      .iter()
      .find_first(node => Some(node.id) == snapshot.focused_node_id)
      .unwrap()
    assert_eq(node.frame.intersect(node.clip), node.frame)
  }
  assert_eq(root.frame_stats().layout_count, 1)
}

///|
test "root keyboard scroll uses axis keys page size bounds and ignores modified keys" {
  for axis in [@foundation.Axis::Vertical, Horizontal] {
    let offset = @reactive.signal(0.0)
    let root = @runtime.mount(
      fn() {
        let content = match axis {
          Vertical => @view.fill_box(300.0)
          Horizontal =>
            @view.box(style=@style.BoxStyle().width(300.0).height(50.0))
        }
        @view.scroll_view(content, axis~, offset~)
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    let size = @foundation.Size(width=50.0, height=50.0)
    assert_false(root.key_down(test_key_event(KeyPageDown)))
    assert_eq(root.frame_stats().layout_count, 0)
    assert_true(root.key_down(test_key_event(KeyPageDown), size~))
    assert_eq(offset.get(), 50.0)
    let forward = match axis {
      Vertical => @foundation.Key::KeyArrowDown
      Horizontal => KeyArrowRight
    }
    let wrong_axis = match axis {
      Vertical => @foundation.Key::KeyArrowRight
      Horizontal => KeyArrowDown
    }
    assert_false(root.key_down(test_key_event(wrong_axis)))
    assert_true(root.key_down(KeyEvent(key=forward, repeat=true)))
    assert_eq(offset.get(), 90.0)
    assert_eq(root.dirty(), NeedsLayout) // Initial frame still pending.
    root.paint(ScrollRecorder(), size~)
    assert_true(root.key_down(test_key_event(KeyEnd)))
    assert_eq(offset.get(), 250.0)
    assert_eq(root.dirty(), NeedsPaint)
    assert_false(root.key_down(test_key_event(KeyEnd)))
    assert_true(root.key_down(test_key_event(KeyHome)))
    assert_eq(offset.get(), 0.0)
    for
      modifiers in [
        @foundation.KeyModifiers(shift=true),
        KeyModifiers(control=true),
        KeyModifiers(alt=true),
        KeyModifiers(meta=true),
      ] {
      assert_false(root.key_down(KeyEvent(key=KeyPageDown, modifiers~)))
    }
    assert_false(root.key_down(test_key_event(KeyPageUp)))
    assert_eq(root.frame_stats().layout_count, 1)
  }
}

///|
test "text input consumes caret keys before horizontal viewport fallback" {
  let offset = @reactive.signal(0.0)
  let value = @reactive.signal("abcd")
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.row([
          @controls.text_input(
            value~,
            style=@controls.TextInputStyle().surface(
              @style.BoxStyle().width(150.0).height(30.0),
            ),
          ),
          @view.box(style=@style.BoxStyle().width(150.0).height(30.0)),
        ]),
        axis=Horizontal,
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=40.0)
  assert_true(root.key_down(test_key_event(KeyTab), size~))
  assert_true(root.key_down(test_key_event(KeyEnd)))
  assert_true(root.key_down(test_key_event(KeyArrowLeft)))
  assert_true(root.key_down(test_key_event(KeyHome)))
  assert_eq(offset.get(), 0.0)
  assert_true(root.text_input("X"))
  assert_eq(value.get(), "Xabcd")
  root.paint(ScrollRecorder(), size~)
  assert_true(root.key_down(test_key_event(KeyPageDown)))
  assert_eq(offset.get(), 100.0)
  assert_eq(root.dirty(), NeedsPaint)
  assert_false(root.key_down(test_control_key_event(KeyPageDown)))
  assert_eq(offset.get(), 100.0)
}

///|
test "keyboard scroll bubbles at a boundary or past an ancestor on the other axis" {
  let inner = @reactive.signal(0.0)
  let outer = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.row([
          @view.scroll_view(
            @view.column([
              navigation_button("button", width=60.0),
              @view.fill_box(60.0),
            ]),
            offset=inner,
            style=@style.BoxStyle().width(60.0).height(40.0),
          ),
          @view.box(style=@style.BoxStyle().width(120.0).height(40.0)),
        ]),
        axis=Horizontal,
        offset=outer,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=80.0, height=50.0)
  assert_true(root.key_down(test_key_event(KeyTab), size~))
  assert_true(root.key_down(test_key_event(KeyEnd)))
  assert_eq(inner.get(), 50.0)
  assert_eq(outer.get(), 0.0)
  assert_true(root.key_down(test_key_event(KeyEnd)))
  assert_eq(outer.get(), 100.0)
  assert_true(root.key_down(test_key_event(KeyHome)))
  assert_eq(inner.get(), 0.0)
  assert_eq(outer.get(), 100.0)
  assert_true(root.key_down(test_key_event(KeyHome)))
  assert_eq(outer.get(), 0.0)
  assert_true(root.key_down(test_key_event(KeyArrowDown)))
  assert_eq(inner.get(), 40.0)
  assert_true(root.key_down(test_key_event(KeyArrowRight)))
  assert_eq(outer.get(), 40.0)
}

///|
test "oversized focus target uses nearest edge and retains an already visible region" {
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([
          @view.fill_box(10.0),
          navigation_button("large", height=120.0),
          @view.fill_box(70.0),
        ]),
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=50.0)
  assert_true(root.key_down(test_key_event(KeyTab), size~))
  assert_eq(offset.get(), 10.0)
  offset.set(40.0)
  root.paint(ScrollRecorder(), size~)
  assert_true(root.key_down(test_key_event(KeyTab)))
  assert_eq(offset.get(), 40.0)
  assert_false(root.needs_frame())
}

///|
test "focus callbacks can reorder keyed children before reveal follows the stable node ID" {
  let keys = @reactive.signal([1, 2])
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.column([
          @view.fill_box(100.0),
          @view.for_each(fn() { keys.get() }, fn(key) { key }, fn(key) {
            @controls.button(
              "\{key()}",
              style=@controls.ButtonStyle().surface(
                @style.BoxStyle().height(30.0),
              ),
              on_focus=fn() { if key() == 1 { keys.set([2, 1]) } },
            )
          }),
        ]),
        offset~,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=50.0)
  assert_true(root.key_down(test_key_event(KeyTab), size~))
  assert_eq(offset.get(), 110.0)
  root.paint(ScrollRecorder(), size~)
  let snapshot = root.snapshot().unwrap()
  let focused = snapshot.tree.nodes
    .iter()
    .find_first(node => Some(node.id) == snapshot.focused_node_id)
    .unwrap()
  assert_eq(focused.frame.origin.y, 20.0)
  keys.set([2])
  assert_true(root.key_down(test_key_event(KeyTab)))
  root.paint(ScrollRecorder(), size~)
  assert_true(root.snapshot().unwrap().focused_node_id is Some(_))
}

///|
test "focus loss or disposal in an inner scroll callback cancels remaining reveal updates" {
  for dispose in [false, true] {
    let inner = @reactive.signal(0.0)
    let outer = @reactive.signal(0.0)
    let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
    let root = @runtime.mount(
      fn() {
        @reactive.effect(fn() {
          if inner.get() > 0.0 && root_ref.val is Some(root) {
            if dispose {
              root.dispose()
            } else {
              root.focus_lost()
            }
          }
        })
        |> ignore
        @view.scroll_view(
          @view.column([
            @view.fill_box(100.0),
            @view.scroll_view(
              @view.column([@view.fill_box(60.0), navigation_button("button")]),
              offset=inner,
              style=@style.BoxStyle().height(40.0),
            ),
            @view.fill_box(40.0),
          ]),
          offset=outer,
        )
      },
      text_layout_system=test_text_layout_system(),
    )
    defer root.dispose()
    root_ref.val = Some(root)
    assert_true(
      root.key_down(test_key_event(KeyTab), size=Size(width=100.0, height=50.0)),
    )
    assert_eq(inner.get(), 50.0)
    assert_eq(outer.get(), 0.0)
    assert_eq(root.is_disposed(), dispose)
  }
}

///|
test "focus reveal respects static ancestor clips inside a viewport" {
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.column([
        @view.fill_box(10.0),
        @view.row(
          [
            @view.scroll_view(
              @view.column([
                @view.fill_box(60.0),
                navigation_button("button"),
                @view.fill_box(110.0),
              ]),
              offset~,
              style=@style.BoxStyle().width(100.0).height(100.0),
            ),
          ],
          style=@view.FlexStyle().surface(@style.BoxStyle().height(40.0)),
        ).clip(),
      ])
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  let size = @foundation.Size(width=100.0, height=150.0)
  assert_true(root.key_down(test_key_event(KeyTab), size~))
  assert_eq(offset.get(), 50.0)
  root.paint(ScrollRecorder(), size~)
  let snapshot = root.snapshot().unwrap()
  let focused = snapshot.tree.nodes
    .iter()
    .find_first(node => Some(node.id) == snapshot.focused_node_id)
    .unwrap()
  assert_eq(focused.frame.intersect(focused.clip), focused.frame)
}

///|
test "horizontal focus reveal includes viewport padding" {
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() {
      @view.scroll_view(
        @view.row([
          navigation_button("one", width=50.0),
          navigation_button("two", width=50.0),
          navigation_button("three", width=50.0),
        ]),
        axis=Horizontal,
        offset~,
        style=@style.BoxStyle().padding(@foundation.Insets::all(5.0)),
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  for expected in [0.0, 10.0, 60.0] {
    assert_true(
      root.key_down(test_key_event(KeyTab), size=Size(width=100.0, height=40.0)),
    )
    assert_eq(offset.get(), expected)
  }
}

///|
test "explicit keyboard host size handles resize and zero dimensions without stale page length" {
  let offset = @reactive.signal(0.0)
  let root = @runtime.mount(
    fn() { @view.scroll_view(@view.fill_box(200.0), offset~) },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  assert_true(
    root.key_down(
      test_key_event(KeyPageDown),
      size=Size(width=100.0, height=50.0),
    ),
  )
  assert_eq(offset.get(), 50.0)
  assert_true(
    root.key_down(
      test_key_event(KeyPageDown),
      size=Size(width=100.0, height=25.0),
    ),
  )
  assert_eq(offset.get(), 75.0)
  assert_false(
    root.key_down(test_key_event(KeyEnd), size=Size(width=100.0, height=0.0)),
  )
  assert_eq(offset.get(), 75.0)
  root.paint(ScrollRecorder(), size=Size(width=100.0, height=50.0))
  assert_true(root.key_down(test_key_event(KeyArrowDown)))
  assert_eq(offset.get(), 115.0)
}

///|
test "host resize during reveal cancels old-size updates and prepares the remaining focus reveal" {
  let inner = @reactive.signal(0.0)
  let outer = @reactive.signal(0.0)
  let root_ref : Ref[@runtime.UiRoot?] = Ref(None)
  let resized = Ref(false)
  let root = @runtime.mount(
    fn() {
      @reactive.effect(fn() {
        if inner.get() > 0.0 && !resized.val && root_ref.val is Some(root) {
          resized.val = true
          root.paint(ScrollRecorder(), size=Size(width=100.0, height=30.0))
        }
      })
      |> ignore
      @view.scroll_view(
        @view.column([
          @view.fill_box(100.0),
          @view.scroll_view(
            @view.column([@view.fill_box(60.0), navigation_button("button")]),
            offset=inner,
            style=@style.BoxStyle().height(40.0),
          ),
          @view.fill_box(40.0),
        ]),
        offset=outer,
      )
    },
    text_layout_system=test_text_layout_system(),
  )
  defer root.dispose()
  root_ref.val = Some(root)
  assert_true(
    root.key_down(test_key_event(KeyTab), size=Size(width=100.0, height=50.0)),
  )
  assert_eq(inner.get(), 50.0)
  assert_eq(outer.get(), 0.0)
  assert_true(root.needs_frame())
  root.paint(ScrollRecorder(), size=Size(width=100.0, height=30.0))
  assert_eq(outer.get(), 110.0)
  assert_false(root.needs_frame())
}
